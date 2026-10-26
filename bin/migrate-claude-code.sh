#!/usr/bin/env bash
# Back up and restore personal Claude Code state.
#
# Use cases:
#   - Recurring backups of your Claude Code setup
#   - Rolling back after a bad config change
#   - Migrating between laptops
#
# Usage:
#   ./mac-setup.sh migrate-claude-code wizard                               # interactive end-to-end (recommended)
#   ./mac-setup.sh migrate-claude-code backup  [--yes] [--encrypt] [outfile]  # bundle state
#   ./mac-setup.sh migrate-claude-code restore [--dry-run] <tarball>          # extract into ~/.claude
#   ./mac-setup.sh migrate-claude-code verify  [--root <path>]                # check installed state
#   ./mac-setup.sh migrate-claude-code list                                   # project memory dirs
#   ./mac-setup.sh migrate-claude-code --help
#
# `wizard` picks backup vs restore based on whether a backup tarball sits
# nearby, and walks the flow interactively. The other subcommands are the
# atomic building blocks it calls into, and stay usable on their own.
#
# Direct invocation as `bin/migrate-claude-code.sh <command> ...` works too;
# the router form above is the one the README documents.
#
# `export` and `install` are kept as aliases for `backup` and `restore` for
# backwards compatibility.
#
# Encryption (recommended):
#   `backup --encrypt` streams the tar through `gpg -c` (AES-256 symmetric) and
#   writes a <tarball>.gpg instead of a plain tarball. The plaintext tar never
#   touches disk. GPG prompts for a passphrase twice. `restore` auto-detects
#   the `.gpg` suffix and prompts for the passphrase on decryption. Requires
#   `gpg` on PATH (macOS: `brew install gnupg`). If you lose the passphrase,
#   the tarball is unrecoverable; save it in a password manager first.
#
# End-to-end workflow:
#
#   1. Bundle current state. Writes two files:
#        ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz
#        ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.sha256
#      Or with encryption (recommended, session transcripts can hold secrets):
#        ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.gpg
#        ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.gpg.sha256
#      ./mac-setup.sh migrate-claude-code backup            # plain
#      ./mac-setup.sh migrate-claude-code backup --encrypt  # encrypted (prompts for passphrase)
#
#   2. For migration, copy BOTH files (tarball + .sha256) to the target. Example:
#      scp ~/claude-code-backup-*.tar.gz*       newlaptop:~/   # plain
#      scp ~/claude-code-backup-*.tar.gz.gpg*   newlaptop:~/   # encrypted
#
#   3. On the target, make sure the mac-setup clone is in place (run
#      the fresh-Mac bootstrap first if this is a new laptop). Then
#      dry-run against the clone:
#      ./mac-setup.sh migrate-claude-code restore --dry-run claude-code-backup-*.tar.gz
#
#   4. If dry-run output looks right, restore for real. Any existing
#      ~/.claude/ is first copied to ~/.claude.backup-YYYYMMDD-HHMMSS/.
#      ./mac-setup.sh migrate-claude-code restore claude-code-backup-*.tar.gz
#
# SHA256 is written by `backup` and verified by `restore` before any extraction.
#
# What travels:
#   ~/.claude/CLAUDE.md
#   ~/.claude/guidance/
#   ~/.claude/history.jsonl              (global prompt history for /resume)
#   ~/.claude/hooks/
#   ~/.claude/plugins/blocklist.json     (plugin block list)
#   ~/.claude/plugins/data/              (per-plugin user state)
#   ~/.claude/projects/                  (full tree: memory, MEMORY.md,
#                                         *.jsonl session transcripts,
#                                         and UUID session detail folders)
#   ~/.claude/sessions/                  (global session index/state)
#   ~/.claude/settings.json              (declares enabledPlugins +
#                                         extraKnownMarketplaces; Claude Code
#                                         re-syncs plugins on first launch)
#   ~/.claude/skills/
#
# What stays behind (machine-local, auth-bound, or regenerable):
#   plugins/{marketplaces,cache,store,synced,installed_plugins.json,
#            known_marketplaces.json,plugin-catalog-cache.json}
#      -> re-fetched on first `claude` launch from settings.json
#   daemon.*, cache, paste-cache, file-history, backups, shell-snapshots,
#   security, telemetry, remote-settings.json, .env, session-env, tasks,
#   jobs, debug, downloads, stats-cache.json
#
# Export checks ~/.claude/ for entries not in either list (drift detection) and
# asks before continuing. Pass --yes to skip the prompt.
#
# After restore on a fresh laptop:
#   1. Run `claude` once so plugins resync from marketplaces (~1 min, needs net).
#   2. Re-authenticate any MCP integrations (listed by `verify`) when first used.
#   3. Confirm with `/plugin` that all enabled plugins show installed.
#
# Note: session transcripts can contain anything you or Claude saw during a
# session, including pasted secrets, internal URLs, or sensitive content.
# Treat the resulting tarball accordingly.

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
PROJECTS_DIR="${CLAUDE_DIR}/projects"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"

# --- Known entries (for drift detection) --------------------------------------
KNOWN_INCLUDE_CLAUDE=(
  "CLAUDE.md" "guidance" "settings.json" "skills" "hooks"
  "plugins" "projects" "sessions" "history.jsonl"
)
KNOWN_EXCLUDE_CLAUDE=(
  ".env" ".last-cleanup" ".last-update-result.json"
  "backups" "cache" "daemon" "daemon-auth-cooldown" "daemon-auth-status.json"
  "daemon.lock" "daemon.log" "daemon.status.json"
  "debug" "downloads" "file-history" "jobs" "paste-cache"
  "policy-limits.json" "policy-limits.json.stamp.json"
  "remote-settings.json" "security" "session-env" "shell-snapshots"
  "stats-cache.json" "tasks" "telemetry"
)
KNOWN_INCLUDE_PLUGINS=( "data" "blocklist.json" )
KNOWN_EXCLUDE_PLUGINS=(
  ".last_inuse_sweep"
  "marketplaces" "cache" "store" "synced"
  "installed_plugins.json" "known_marketplaces.json" "plugin-catalog-cache.json"
)
KNOWN_EXCLUDE_PREFIXES=( "security_warnings_state_" )

# --- SHA256 helpers -----------------------------------------------------------
sha256_tool() {
  if command -v shasum >/dev/null 2>&1; then
    echo "shasum"
  elif command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
  else
    return 1
  fi
}

compute_sha256() {
  local file="$1" tool
  tool="$(sha256_tool)" || { echo "error: neither shasum nor sha256sum is available" >&2; return 1; }
  (cd "$(dirname "${file}")" && "${tool}" ${tool:+-a 256} "$(basename "${file}")" 2>/dev/null \
    || "${tool}" "$(basename "${file}")")
}

# Compute checksum file. shasum/sha256sum have slightly different flag shapes;
# the simplest portable approach is a conditional per tool.
write_sha256() {
  local file="$1"
  local sumfile="${file}.sha256"
  (cd "$(dirname "${file}")" && {
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$(basename "${file}")"
    else
      sha256sum "$(basename "${file}")"
    fi
  }) > "${sumfile}"
  echo "${sumfile}"
}

verify_sha256() {
  local file="$1"
  local sumfile="${file}.sha256"
  if [ ! -f "${sumfile}" ]; then
    echo "error: no $(basename "${sumfile}") alongside tarball; refusing to restore" >&2
    echo "  restore is fail-closed on integrity. Regenerate the sidecar with:" >&2
    echo "    shasum -a 256 \"$(basename "${file}")\" > \"$(basename "${sumfile}")\"" >&2
    echo "  (only safe if you trust the tarball — the whole point of the check)" >&2
    return 1
  fi
  echo "Verifying integrity against $(basename "${sumfile}")..."
  if (cd "$(dirname "${file}")" && {
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 -c "$(basename "${sumfile}")"
    else
      sha256sum -c "$(basename "${sumfile}")"
    fi
  }) ; then
    return 0
  else
    return 1
  fi
}

# --- Encryption helpers -------------------------------------------------------
# Encrypted tarballs end in .gpg. Decryption streams through gpg; the plaintext
# tar is never written to disk.
is_encrypted_tarball() {
  case "$1" in
    *.gpg) return 0 ;;
    *)     return 1 ;;
  esac
}

require_gpg() {
  if ! command -v gpg >/dev/null 2>&1; then
    echo "error: this operation needs 'gpg' on PATH (macOS: 'brew install gnupg')" >&2
    return 1
  fi
  # pinentry needs to know the controlling TTY to prompt for a passphrase.
  # Without GPG_TTY, the gpg child inside `tar | gpg -c > outfile` sees a
  # pipe on its own stdin and fails with "Inappropriate ioctl for device"
  # ("gpg: problem with the agent"). Capture the current TTY now, before
  # any pipeline, so the child inherits it. Noop in a non-interactive run
  # (no TTY, nothing to set; gpg will still error, but at the right place).
  if [ -z "${GPG_TTY:-}" ]; then
    local t
    if t="$(tty 2>/dev/null)" && [ -n "${t}" ]; then
      export GPG_TTY="${t}"
    fi
  fi
}

# extract_tarball <tarball> <dest-dir>
# Transparently handles plain and .gpg tarballs. For .gpg, gpg prompts for the
# passphrase on the controlling TTY.
extract_tarball() {
  local tarball="$1" dest="$2"
  if is_encrypted_tarball "${tarball}"; then
    require_gpg || return 1
    gpg --decrypt --quiet --output - "${tarball}" | tar -xzf - -C "${dest}"
  else
    tar -xzf "${tarball}" -C "${dest}"
  fi
}

# --- Helpers ------------------------------------------------------------------
usage() {
  awk 'NR==1 { next } /^set / { exit } { sub(/^# ?/, ""); print }' "$0"
  exit "${1:-0}"
}

require_claude_dir() {
  if [ ! -d "${CLAUDE_DIR}" ]; then
    echo "error: ${CLAUDE_DIR} does not exist" >&2
    exit 1
  fi
}

contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [ "${item}" = "${needle}" ] && return 0
  done
  return 1
}

has_known_prefix() {
  local name="$1" prefix
  for prefix in "${KNOWN_EXCLUDE_PREFIXES[@]}"; do
    case "${name}" in
      "${prefix}"*) return 0 ;;
    esac
  done
  return 1
}

check_drift() {
  local drift=()
  local entry name

  if [ -d "${CLAUDE_DIR}" ]; then
    for entry in "${CLAUDE_DIR}"/* "${CLAUDE_DIR}"/.[!.]*; do
      [ -e "${entry}" ] || continue
      name="$(basename "${entry}")"
      if contains "${name}" "${KNOWN_INCLUDE_CLAUDE[@]}"; then continue; fi
      if contains "${name}" "${KNOWN_EXCLUDE_CLAUDE[@]}"; then continue; fi
      if has_known_prefix "${name}"; then continue; fi
      # shellcheck disable=SC2088 # literal "~/..." for display, no expansion wanted
      drift+=( "~/.claude/${name}" )
    done
  fi

  if [ -d "${PLUGINS_DIR}" ]; then
    for entry in "${PLUGINS_DIR}"/* "${PLUGINS_DIR}"/.[!.]*; do
      [ -e "${entry}" ] || continue
      name="$(basename "${entry}")"
      if contains "${name}" "${KNOWN_INCLUDE_PLUGINS[@]}"; then continue; fi
      if contains "${name}" "${KNOWN_EXCLUDE_PLUGINS[@]}"; then continue; fi
      # shellcheck disable=SC2088 # literal "~/..." for display, no expansion wanted
      drift+=( "~/.claude/plugins/${name}" )
    done
  fi

  if [ "${#drift[@]}" -eq 0 ]; then
    return 0
  fi

  echo
  echo "Drift detected — these entries exist under ~/.claude/ but are not in the"
  echo "script's include or exclude catalog. Claude Code may have added new state"
  echo "the script doesn't know how to classify:"
  local item
  for item in "${drift[@]}"; do
    printf '  - %s\n' "${item}"
  done
  echo
  echo "Review and extend KNOWN_INCLUDE_* / KNOWN_EXCLUDE_* at the top of this"
  echo "script before backup if any of these should travel."
  return 1
}

build_file_list() {
  cd "${HOME}"

  for entry in \
    ".claude/CLAUDE.md" \
    ".claude/guidance" \
    ".claude/settings.json" \
    ".claude/skills" \
    ".claude/hooks" \
    ".claude/plugins/data" \
    ".claude/plugins/blocklist.json" \
    ".claude/projects" \
    ".claude/sessions" \
    ".claude/history.jsonl"
  do
    if [ -e "${entry}" ]; then
      printf '%s\n' "${entry}"
    fi
  done
}

# --- Commands -----------------------------------------------------------------
cmd_backup() {
  require_claude_dir

  local assume_yes=0
  local encrypt=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y)   assume_yes=1; shift ;;
      --encrypt)  encrypt=1; shift ;;
      --)         shift; break ;;
      -*)         echo "unknown flag: $1" >&2; exit 1 ;;
      *)          break ;;
    esac
  done

  if [ "${encrypt}" -eq 1 ]; then
    require_gpg || exit 1
  fi

  if ! check_drift; then
    if [ "${assume_yes}" -eq 1 ]; then
      echo "Proceeding anyway (--yes)."
    else
      printf 'Proceed with backup anyway? [y/N] '
      local answer=""
      if ! read -r answer; then answer=""; fi
      case "${answer}" in
        y|Y|yes|YES) echo "Proceeding." ;;
        *) echo "Aborted."; exit 1 ;;
      esac
    fi
  fi

  local base_outfile="${1:-${HOME}/claude-code-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
  local outfile="${base_outfile}"
  if [ "${encrypt}" -eq 1 ]; then
    outfile="${base_outfile}.gpg"
  fi

  local listfile
  listfile="$(mktemp)"
  # Expand ${listfile} at trap-setup time, not at trap-fire time: the local
  # falls out of scope before the top-level EXIT trap fires, which would
  # otherwise print 'unbound variable' under `set -u`.
  # shellcheck disable=SC2064 # intentional setup-time expansion
  trap "rm -f '${listfile}'" EXIT

  build_file_list > "${listfile}"

  if [ ! -s "${listfile}" ]; then
    echo "error: nothing to back up" >&2
    exit 1
  fi

  echo "Bundling the following paths (relative to \$HOME):"
  sed 's/^/  /' "${listfile}"
  echo

  if [ "${encrypt}" -eq 1 ]; then
    echo "Encrypting with GPG symmetric (AES-256). You will be prompted for a"
    echo "passphrase twice. Store it in a password manager — if lost, the tarball"
    echo "is unrecoverable."
    echo
    tar -czf - -C "${HOME}" -T "${listfile}" \
      | gpg --symmetric --cipher-algo AES256 --output "${outfile}"
  else
    tar -czf "${outfile}" -C "${HOME}" -T "${listfile}"
  fi

  local sumfile
  sumfile="$(write_sha256 "${outfile}")"

  local size
  size="$(du -h "${outfile}" | awk '{print $1}')"
  echo "Wrote ${outfile} (${size})."
  echo "Wrote ${sumfile}"
  echo
  echo "Copy both files to the target machine. On a fresh laptop, run the"
  echo "mac-setup bootstrap first. Then, from inside the clone:"
  echo "  ./mac-setup.sh migrate-claude-code restore \"$(basename "${outfile}")\""
  echo
  echo "Optional: dry-run first to confirm the bundle before touching ~/.claude/:"
  echo "  ./mac-setup.sh migrate-claude-code restore --dry-run \"$(basename "${outfile}")\""
}

cmd_restore() {
  local dry_run=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --)        shift; break ;;
      -*)        echo "unknown flag: $1" >&2; exit 1 ;;
      *)         break ;;
    esac
  done

  local tarball="${1:-}"
  if [ -z "${tarball}" ] || [ ! -f "${tarball}" ]; then
    echo "error: pass a tarball produced by 'backup'" >&2
    exit 1
  fi

  if ! verify_sha256 "${tarball}"; then
    echo "error: integrity check failed — refusing to extract" >&2
    exit 1
  fi

  if is_encrypted_tarball "${tarball}"; then
    require_gpg || exit 1
    echo "Tarball is encrypted. GPG will prompt for the passphrase."
  fi

  if [ "${dry_run}" -eq 1 ]; then
    local tmp
    tmp="$(mktemp -d -t claude-migrate-XXXXXX)"
    # shellcheck disable=SC2064 # intentional setup-time expansion; see cmd_backup
    trap "rm -rf '${tmp}'" EXIT
    echo
    echo "Dry-run: extracting to ${tmp} (your real ~/.claude/ is untouched)"
    extract_tarball "${tarball}" "${tmp}"
    echo
    cmd_verify --root "${tmp}"
    echo
    echo "Dry-run complete. Nothing under ${HOME}/.claude was modified."
    echo "If the output above looks right, re-run without --dry-run to restore."
    return 0
  fi

  if [ -d "${CLAUDE_DIR}" ]; then
    local backup
    backup="${CLAUDE_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing ${CLAUDE_DIR} -> ${backup}"
    cp -a "${CLAUDE_DIR}" "${backup}"
  else
    mkdir -p "${CLAUDE_DIR}"
  fi

  echo "Extracting ${tarball} into ${HOME}"
  extract_tarball "${tarball}" "${HOME}"
  echo

  cmd_verify

  cat <<'EOF'

Next steps on this laptop:
  1. Run `claude` once — plugins resync from marketplaces (needs network).
  2. Re-authenticate MCP integrations when first used.
  3. Confirm with `/plugin` that all enabled plugins show installed.
EOF
}

print_mcp_integrations() {
  local plugins_dir="$1" settings_path="$2"
  # command -v guard: bare macOS has a `python3` stub that triggers the Xcode
  # Command Line Tools install dialog on invocation. We'd rather print a hint.
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  (install Python 3 to list MCP integrations)"
    return 0
  fi
  python3 - "${settings_path}" "${plugins_dir}" <<'PY' 2>/dev/null || echo "  (unable to parse settings.json / plugin cache)"
import json, os, sys, glob

settings_path, plugins_dir = sys.argv[1], sys.argv[2]
try:
    settings = json.load(open(settings_path))
except Exception:
    print("  (unable to read settings.json)")
    sys.exit(0)

enabled = [k for k, v in settings.get("enabledPlugins", {}).items() if v]

def mcp_candidates(plugin_key):
    name, _, marketplace = plugin_key.partition("@")
    patterns = [
        f"{plugins_dir}/marketplaces/{marketplace}/plugins/{name}/.mcp.json",
        f"{plugins_dir}/marketplaces/{marketplace}/external_plugins/{name}/.mcp.json",
        f"{plugins_dir}/cache/{marketplace}/{name}/*/.mcp.json",
    ]
    for pat in patterns:
        for path in sorted(glob.glob(pat)):
            yield path

seen = set()
hits = []
for key in sorted(enabled):
    for mcp_path in mcp_candidates(key):
        try:
            data = json.load(open(mcp_path))
        except Exception:
            continue
        servers = data.get("mcpServers", {}) or {}
        for server_name, cfg in servers.items():
            sig = (key, server_name)
            if sig in seen:
                continue
            seen.add(sig)
            url = cfg.get("url") or cfg.get("command") or ""
            if url:
                hits.append(f"  - {server_name:<22s} ({key})  {url}")
            else:
                hits.append(f"  - {server_name:<22s} ({key})")
        break

if hits:
    print("\n".join(hits))
else:
    print("  (no MCP manifests found for enabled plugins)")
PY
}

cmd_verify() {
  local root="${HOME}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) root="$2"; shift 2 ;;
      --)     shift; break ;;
      -*)     echo "unknown flag: $1" >&2; return 1 ;;
      *)      break ;;
    esac
  done

  local claude_dir="${root}/.claude"
  local projects_dir="${claude_dir}/projects"
  local plugins_dir="${claude_dir}/plugins"
  local settings_path="${claude_dir}/settings.json"

  local ok=0 fail=0

  check() {
    local label="$1" path="$2"
    if [ -e "${path}" ]; then
      printf '  [ok]   %s\n' "${label}"
      ok=$((ok + 1))
    else
      printf '  [MISS] %s  (expected %s)\n' "${label}" "${path}"
      fail=$((fail + 1))
    fi
  }

  echo "Checking installed state in ${claude_dir}:"
  check "global CLAUDE.md"       "${claude_dir}/CLAUDE.md"
  check "guidance/"              "${claude_dir}/guidance"
  check "settings.json"          "${settings_path}"
  check "hooks/"                 "${claude_dir}/hooks"
  check "skills/"                "${claude_dir}/skills"
  check "projects/"              "${projects_dir}"
  check "sessions/"              "${claude_dir}/sessions"
  check "history.jsonl"          "${claude_dir}/history.jsonl"
  check "plugins/data/"          "${plugins_dir}/data"
  check "plugins/blocklist.json" "${plugins_dir}/blocklist.json"

  echo
  if [ -f "${settings_path}" ]; then
    local plugin_count project_count memory_count
    if command -v python3 >/dev/null 2>&1; then
      plugin_count="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(sum(1 for v in d.get('enabledPlugins',{}).values() if v))" "${settings_path}" 2>/dev/null || echo "?")"
    else
      plugin_count="?"
    fi
    project_count="$(ls -1 "${projects_dir}" 2>/dev/null | wc -l | tr -d ' ')"
    memory_count=0
    if [ -d "${projects_dir}" ]; then
      for p in "${projects_dir}"/*/; do
        [ -d "${p}memory" ] || continue
        local n
        n="$(ls -1 "${p}memory" 2>/dev/null | wc -l | tr -d ' ')"
        memory_count=$((memory_count + n))
      done
    fi
    echo "Summary:"
    echo "  enabled plugins declared in settings.json : ${plugin_count}"
    echo "  project dirs under ${projects_dir}         : ${project_count}"
    echo "  total memory files across projects         : ${memory_count}"
    echo
    echo "MCP integrations found in enabled plugins (tokens were not transferred;"
    echo "re-auth on first use via the plugin's own authenticate flow):"
    print_mcp_integrations "${plugins_dir}" "${settings_path}"
  fi

  echo
  if [ "${fail}" -eq 0 ]; then
    echo "Verification: ${ok} checks passed."
  else
    echo "Verification: ${ok} ok, ${fail} missing. Review the [MISS] lines above." >&2
    return 1
  fi
}

cmd_list() {
  require_claude_dir
  if [ ! -d "${PROJECTS_DIR}" ]; then
    echo "no projects dir at ${PROJECTS_DIR}"
    exit 0
  fi

  printf '%-6s  %-6s  %s\n' "FILES" "SIZE" "PROJECT DIR"
  for project in "${PROJECTS_DIR}"/*/; do
    [ -d "${project}memory" ] || continue
    local count size
    count="$(ls -1 "${project}memory" 2>/dev/null | wc -l | tr -d ' ')"
    size="$(du -sh "${project}memory" 2>/dev/null | awk '{print $1}')"
    printf '%-6s  %-6s  %s\n' "${count}" "${size}" "$(basename "${project%/}")"
  done
}

# --- Interactive wizard -------------------------------------------------------
# Mirrors the shape of bin/migrate-laptop.sh's wizard: a single `wizard`
# subcommand that picks "backup" vs "restore" from whether a Claude Code
# backup tarball sits in $HOME or $PWD, prompts for the few choices the
# user actually makes (encrypt / confirm the dry-run / etc), and drives
# the atomic cmd_backup / cmd_restore / cmd_verify calls underneath.
#
# Unattended mode: MIGRATE_WIZARD_YES=1 collapses y/n prompts to their
# declared default. When no tarball is nearby and no side can be inferred,
# MIGRATE_WIZARD_MODE=backup|restore picks explicitly; otherwise the
# wizard errors out rather than hanging on a tty read.

prompt_yes_no() {
  local msg="$1" default="${2:-y}" ans hint="[Y/n]"
  [ "${default}" = "n" ] && hint="[y/N]"
  if [ "${MIGRATE_WIZARD_YES:-0}" = "1" ]; then
    [ "${default}" = "y" ]; return
  fi
  while :; do
    printf '%s %s ' "${msg}" "${hint}"
    if ! IFS= read -r ans; then
      # EOF: fall through to the declared default (safer than returning
      # 1, which would conflate EOF with "no" for default-y security
      # prompts like "Encrypt the bundle?").
      [ "${default}" = "y" ]; return
    fi
    [ -z "${ans}" ] && ans="${default}"
    case "${ans}" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo])     return 1 ;;
    esac
  done
}

prompt_enter() {
  local msg="$1" _junk
  if [ "${MIGRATE_WIZARD_YES:-0}" = "1" ]; then
    return 0
  fi
  printf '%s ' "${msg}"
  IFS= read -r _junk || true
}

find_tarballs() {
  local pattern="$1" dir f
  for dir in "${HOME}" "${PWD}"; do
    for f in "${dir}"/${pattern}; do
      case "${f}" in
        *.sha256)        continue ;;
        *"/${pattern}")  continue ;;  # literal glob, no match
      esac
      [ -f "${f}" ] && printf '%s\n' "${f}"
    done
  done | sort -u
}

cmd_wizard() {
  local mode="" line
  local -a tarballs=()
  while IFS= read -r line; do
    [ -n "${line}" ] && tarballs+=("${line}")
  done < <(find_tarballs 'claude-code-backup-*.tar.gz*')

  if [ "${#tarballs[@]}" -gt 0 ]; then
    echo "Found a Claude Code backup nearby:"
    printf '  %s\n' "${tarballs[@]}"
    echo
    if prompt_yes_no "Restore from this tarball?" y; then
      mode="restore"
    else
      mode="backup"
    fi
  elif [ "${MIGRATE_WIZARD_YES:-0}" = "1" ]; then
    case "${MIGRATE_WIZARD_MODE:-}" in
      backup|restore) mode="${MIGRATE_WIZARD_MODE}" ;;
      *) echo "error: no Claude Code backup found nearby; set MIGRATE_WIZARD_MODE=backup|restore for unattended runs" >&2
         return 1 ;;
    esac
  else
    echo "Claude Code migration wizard."
    echo "  1) Backup — bundle ~/.claude state from this machine"
    echo "  2) Restore — extract a backup into ~/.claude on this machine"
    local ans
    while :; do
      printf 'Pick 1 or 2: '
      IFS= read -r ans || return 1
      case "${ans}" in
        1) mode="backup";  break ;;
        2) mode="restore"; break ;;
      esac
    done
  fi

  if [ "${mode}" = "backup" ]; then
    wizard_backup
  elif [ "${#tarballs[@]}" -gt 0 ]; then
    wizard_restore "${tarballs[@]}"
  else
    wizard_restore
  fi
}

wizard_backup() {
  echo
  echo "=== Step 1/2: Backup (THIS laptop) ==="
  echo "Bundles ~/.claude state (CLAUDE.md, guidance, skills, hooks, plugin"
  echo "data, projects, sessions, prompt history) into a tar.gz + .sha256."
  local encrypt=0
  if prompt_yes_no "Encrypt the bundle? Recommended; transcripts can hold secrets." y; then
    encrypt=1
  fi
  if [ "${encrypt}" -eq 1 ]; then
    prompt_enter "Press Enter to run the backup (gpg will prompt for a passphrase)."
    cmd_backup --encrypt
  else
    prompt_enter "Press Enter to run the backup."
    cmd_backup
  fi
  echo

  echo
  echo "=== Step 2/2: Transfer (optional) ==="
  echo "If this is for a laptop switch, copy BOTH files (tarball + .sha256)"
  echo "to the new machine, then on that machine:"
  echo "  1. Make sure the mac-setup clone is in place (run the fresh-Mac"
  echo "     bootstrap first if it is a new laptop)."
  echo "  2. From the clone:"
  echo "       ./mac-setup.sh migrate-claude-code wizard"
  echo "     The wizard there will detect the tarball and pick restore."
  echo
  echo "For a local backup you can stop here; the files are in \$HOME."
  echo "This source-side wizard is done."
}

wizard_restore() {
  local tarball=""

  if [ "$#" -eq 1 ]; then
    tarball="$1"
    echo "Using tarball: ${tarball}"
    if ! prompt_yes_no "Use this one?" y; then
      tarball=""
    fi
  elif [ "$#" -gt 1 ]; then
    local -a opts=("$@")
    echo "Multiple candidate tarballs:"
    local i=1 c
    for c in "${opts[@]}"; do
      printf '  %d) %s\n' "${i}" "${c}"
      i=$((i+1))
    done
    if [ "${MIGRATE_WIZARD_YES:-0}" = "1" ]; then
      tarball="${opts[0]}"
      echo "unattended mode: auto-picking the first candidate (${tarball})"
    else
      local n
      while :; do
        printf 'Pick [1-%d]: ' "${#opts[@]}"
        IFS= read -r n || return 1
        case "${n}" in
          ''|*[!0-9]*) continue ;;
        esac
        if [ "${n}" -ge 1 ] && [ "${n}" -le "${#opts[@]}" ]; then
          tarball="${opts[$((n-1))]}"
          break
        fi
      done
    fi
  fi

  while [ -z "${tarball}" ] || [ ! -f "${tarball}" ]; do
    if [ "${MIGRATE_WIZARD_YES:-0}" = "1" ]; then
      echo "error: no backup tarball found and MIGRATE_WIZARD_YES is set; pass the path interactively or place the tarball under \$HOME" >&2
      return 1
    fi
    printf 'Path to the backup tarball: '
    IFS= read -r tarball || return 1
    # Keep the tilde quoted so it stays literal in the case pattern (we
    # want to match a user-typed ~, not do tilde expansion in the pattern).
    # shellcheck disable=SC2088
    case "${tarball}" in
      "~/"*) tarball="${HOME}/${tarball#~/}" ;;
    esac
  done

  echo
  echo "=== Step 1/3: Restore dry-run ==="
  echo "Verifies the SHA256 and extracts to a temp dir. ~/.claude is untouched."
  prompt_enter "Press Enter to run the dry-run."
  cmd_restore --dry-run "${tarball}"
  echo
  if ! prompt_yes_no "Dry-run looks right? Continue to the real restore?" y; then
    echo "Aborted. Rerun 'migrate-claude-code wizard' any time."
    return 0
  fi

  echo
  echo "=== Step 2/3: Restore ==="
  echo "Any existing ~/.claude/ is first copied to ~/.claude.backup-YYYYMMDD-HHMMSS/."
  prompt_enter "Press Enter to restore for real."
  cmd_restore "${tarball}"
  echo

  echo
  echo "=== Step 3/3: Post-restore ==="
  echo "The tarball is in place. One or two things left:"
  echo "  - Run \`claude\` once so plugins resync from marketplaces (needs net)."
  echo "  - Re-authenticate any MCP integrations when first used (listed by"
  echo "    'migrate-claude-code verify')."
  echo "  - Confirm with /plugin inside Claude Code that all enabled plugins"
  echo "    show installed."
}

case "${1:-}" in
  wizard)           shift; cmd_wizard "$@" ;;
  backup|export)    shift; cmd_backup "$@" ;;
  restore|install)  shift; cmd_restore "$@" ;;
  verify)           shift; cmd_verify "$@" ;;
  list)             shift; cmd_list "$@" ;;
  -h|--help|help|"") usage 0 ;;
  *)                echo "unknown command: $1" >&2; usage 1 ;;
esac
