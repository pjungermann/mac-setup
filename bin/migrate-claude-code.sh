#!/usr/bin/env bash
# Back up and restore personal Claude Code state.
#
# Use cases:
#   - Recurring backups of your Claude Code setup
#   - Rolling back after a bad config change
#   - Migrating between laptops
#
# Usage:
#   ./mac-setup.sh migrate-claude-code backup  [--yes] [--encrypt] [outfile]  # bundle state
#   ./mac-setup.sh migrate-claude-code restore [--dry-run] <tarball>          # extract into ~/.claude
#   ./mac-setup.sh migrate-claude-code verify  [--root <path>]                # check installed state
#   ./mac-setup.sh migrate-claude-code list                                   # project memory dirs
#   ./mac-setup.sh migrate-claude-code --help
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
#   # 1. Bundle current state. Writes two files:
#   #      ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz
#   #      ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.sha256
#   #    Or with encryption (recommended, session transcripts can hold secrets):
#   #      ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.gpg
#   #      ~/claude-code-backup-YYYYMMDD-HHMMSS.tar.gz.gpg.sha256
#   ./mac-setup.sh migrate-claude-code backup            # plain
#   ./mac-setup.sh migrate-claude-code backup --encrypt  # encrypted (prompts for passphrase)
#
#   # 2. For migration, copy BOTH files (tarball + .sha256) to the target. Example:
#   scp ~/claude-code-backup-*.tar.gz*       newlaptop:~/   # plain
#   scp ~/claude-code-backup-*.tar.gz.gpg*   newlaptop:~/   # encrypted
#
#   # 3. On a fresh target, pull the migrate script out of the tarball.
#   #    Steps 3-5 use the direct `./bin/migrate-claude-code.sh` form because
#   #    the tarball ships only this one script, not the full repo clone;
#   #    use the `./mac-setup.sh migrate-claude-code ...` router form once
#   #    the clone is in place. The tarball member key is the path the
#   #    source machine invoked the script from (for a repo clone, likely
#   #    `bin/migrate-claude-code.sh`). List the tarball first to confirm,
#   #    then extract using that exact path:
#   #      tar -tzf claude-code-backup-*.tar.gz                   | grep migrate-claude-code   # plain
#   #      gpg --decrypt claude-code-backup-*.tar.gz.gpg | tar -tzf - | grep migrate-claude-code   # encrypted
#   tar -xzf claude-code-backup-*.tar.gz bin/migrate-claude-code.sh                # plain
#   gpg --decrypt claude-code-backup-*.tar.gz.gpg \
#     | tar -xzf - bin/migrate-claude-code.sh                                      # encrypted
#
#   # 4. Dry-run verifies the SHA256, extracts to a temp dir, runs checks.
#   #    Your real ~/.claude/ is untouched.
#   ./bin/migrate-claude-code.sh restore --dry-run claude-code-backup-*.tar.gz
#
#   # 5. If dry-run output looks right, restore for real. Any existing
#   #    ~/.claude/ is first copied to ~/.claude.backup-YYYYMMDD-HHMMSS/.
#   ./bin/migrate-claude-code.sh restore claude-code-backup-*.tar.gz
#
# The tarball contains this script itself (step 3 above), so one copied file is
# enough to carry the whole restore. SHA256 is written by `backup` and
# verified by `restore` before any extraction.
#
# What travels:
#   ~/.claude/CLAUDE.md
#   ~/.claude/guidance/
#   ~/.claude/settings.json              (declares enabledPlugins +
#                                         extraKnownMarketplaces; Claude Code
#                                         re-syncs plugins on first launch)
#   ~/.claude/skills/
#   ~/.claude/hooks/
#   ~/.claude/plugins/data/              (per-plugin user state)
#   ~/.claude/plugins/blocklist.json     (plugin block list)
#   ~/.claude/projects/                  (full tree: memory, MEMORY.md,
#                                         *.jsonl session transcripts,
#                                         and UUID session detail folders)
#   ~/.claude/sessions/                  (global session index/state)
#   ~/.claude/history.jsonl              (global prompt history for /resume)
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

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
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

  # Pure-bash $HOME-prefix strip. Avoids `realpath --relative-to` (GNU only)
  # and python3 (would trigger the Xcode Command Line Tools install dialog
  # on a bare macOS laptop that has not yet had `xcode-select --install`).
  local self_rel=""
  case "${SCRIPT_PATH}" in
    "${HOME}/"*) self_rel="${SCRIPT_PATH#"${HOME}/"}" ;;
  esac
  if [ -n "${self_rel}" ] && [ -e "${self_rel}" ]; then
    printf '%s\n' "${self_rel}"
  fi

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
  echo "Copy both files to the new laptop (same directory), then run:"
  echo "  ./migrate-claude-code.sh restore \"$(basename "${outfile}")\""
  echo
  echo "Optional: dry-run first to confirm the bundle before touching ~/.claude/:"
  echo "  ./migrate-claude-code.sh restore --dry-run \"$(basename "${outfile}")\""
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

case "${1:-}" in
  backup|export)    shift; cmd_backup "$@" ;;
  restore|install)  shift; cmd_restore "$@" ;;
  verify)           shift; cmd_verify "$@" ;;
  list)             shift; cmd_list "$@" ;;
  -h|--help|help|"") usage 0 ;;
  *)                echo "unknown command: $1" >&2; usage 1 ;;
esac
