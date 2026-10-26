#!/usr/bin/env bash
# mac-setup — personal-first fresh-Mac setup, with migration and backup
# helpers alongside. This file is a thin router that dispatches to the
# matching script under bin/. See AGENTS.md for conventions.
#
# Usage:
#   ./mac-setup.sh                              # defaults to install-software
#   ./mac-setup.sh install-software             # bin/install-software.sh
#   ./mac-setup.sh migrate-laptop <args>        # bin/migrate-laptop.sh
#   ./mac-setup.sh migrate-claude-code <args>   # bin/migrate-claude-code.sh
#   ./mac-setup.sh --help
#
# Fresh-Mac bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/main/mac-setup.sh -o mac-setup.sh
#   chmod +x mac-setup.sh
#   ./mac-setup.sh
# triggers the Xcode Command Line Tools install (git ships with CLT),
# then git-clones the repo and re-execs from the clone. Reruns from
# inside the clone also `git pull --ff-only` so a direct
# `./mac-setup.sh …` picks up upstream fixes without re-downloading
# the bootstrap. MAC_SETUP_SKIP_PULL=1 bypasses the clone-side pull for
# local-dev iteration against unpushed edits.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

print_usage() {
    cat <<'EOF'
Usage: ./mac-setup.sh [subcommand] [args...]

Subcommands:
  install-software       (default) Install Homebrew packages, chezmoi
                         dotfiles, mise runtimes, Claude Code CLI, and
                         friends. Idempotent.
  migrate-laptop         Bundle or restore the state that install-software
                         cannot regenerate: SSH keys, GPG keys, shell
                         history, dotfile overlays. See
                         `./mac-setup.sh migrate-laptop --help`.
  migrate-claude-code    Back up or restore ~/.claude state. See
                         `./mac-setup.sh migrate-claude-code --help`.
  --help, -h, help       This message.

Fresh-Mac bootstrap:
  curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/main/mac-setup.sh -o mac-setup.sh
  chmod +x mac-setup.sh
  ./mac-setup.sh
EOF
}

# 0. Self-bootstrap when invoked as a single-file download. Clones the
# repo (fresh install) or pulls an existing clone (rerun), then re-execs
# from the clone so the dispatcher below sees a sibling bin/ dir.
#
# git ships with Xcode Command Line Tools, which aren't installed on a
# bare Mac. `xcode-select --install` triggers the dialog and we wait on
# it before `git clone`. install-software step 1 still has its own CLT
# gate for direct `bin/install-software.sh` invocations and as a cheap
# safeguard.
if [[ ! -d "$SCRIPT_DIR/bin" ]]; then
    dest="${MAC_SETUP_DIR:-$HOME/mac-setup}"
    echo
    echo "=== Bootstrapping full repo to $dest ==="

    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Xcode Command Line Tools are needed for 'git clone'."
        echo "Triggering the install dialog."
        xcode-select --install 2>/dev/null || true
        # The until loop reads from the TTY; the documented bootstrap
        # pipes through a saved file, not `curl | bash`, so stdin is a
        # terminal here. Keep it that way.
        until xcode-select -p >/dev/null 2>&1; do
            read -rsn1 -p "Press any key once the Xcode CLT install completes. "
            echo
        done
    fi

    # Belt-and-suspenders: xcode-select -p can succeed even when the
    # pointer dangles at a deleted Xcode.app, in which case `git` is
    # still missing. Fail loudly with a clear message instead of a
    # cryptic "command not found" from `git clone`.
    if ! command -v git >/dev/null 2>&1; then
        echo "error: git not on PATH after CLT check" >&2
        echo "       run 'xcode-select -p' to see where it points, and" >&2
        echo "       'sudo xcode-select -r' to reset if the path dangles" >&2
        exit 1
    fi

    if [[ -d "$dest/.git" ]]; then
        echo "Updating existing clone at $dest"
        if ! git -C "$dest" pull --ff-only; then
            echo "error: 'git pull --ff-only' failed in $dest" >&2
            echo "       you likely have local changes, uncommitted files, or" >&2
            echo "       a non-ff history. resolve in $dest and re-run." >&2
            exit 1
        fi
    elif [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
        echo "error: $dest exists and is not empty, but is not a git clone" >&2
        echo "       move or remove it, then re-run this bootstrap" >&2
        exit 1
    else
        # `git clone <url> <path>` accepts an existing empty directory.
        git clone https://github.com/pjungermann/mac-setup.git "$dest"
    fi

    exec "$dest/mac-setup.sh" "$@"
fi

# Default subcommand when none supplied, preserving the pre-router UX of
# `./mac-setup.sh` running the installer.
if [[ $# -eq 0 ]]; then
    set -- install-software
fi

cmd="$1"
shift

# 0b. Keep the clone fresh on rerun. The self-bootstrap above only pulls
# when invoked as the downloaded single file (no sibling bin/); reruns
# from inside the clone used to be stale, so a bug fix landing in main
# did not reach the user until they re-downloaded the bootstrap. Pull
# here so `./mac-setup.sh …` inside the clone also picks it up. Re-exec
# only when the pull actually advanced HEAD, to avoid a loop and to
# guarantee any change to mac-setup.sh itself takes effect this run.
# Skip when dispatching to --help (nothing to update for a usage print)
# and when MAC_SETUP_SKIP_PULL=1 for local-dev iteration against
# unpushed edits.
if [[ -d "$SCRIPT_DIR/.git" ]] \
   && [[ "${MAC_SETUP_SKIP_PULL:-0}" != "1" ]] \
   && [[ "$cmd" != "-h" ]] && [[ "$cmd" != "--help" ]] && [[ "$cmd" != "help" ]]; then
    pre_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
    echo
    echo "=== Updating mac-setup clone at $SCRIPT_DIR ==="
    if ! git -C "$SCRIPT_DIR" pull --ff-only; then
        echo "error: 'git pull --ff-only' failed in $SCRIPT_DIR" >&2
        echo "       you likely have local changes, uncommitted files, or" >&2
        echo "       a non-ff history. resolve in $SCRIPT_DIR and re-run," >&2
        echo "       or set MAC_SETUP_SKIP_PULL=1 to skip this check." >&2
        exit 1
    fi
    post_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
    if [[ "$pre_sha" != "$post_sha" ]]; then
        echo "Clone advanced ${pre_sha:0:7} -> ${post_sha:0:7}; re-executing with latest scripts."
        exec "$SCRIPT_DIR/mac-setup.sh" "$cmd" "$@"
    fi
fi

case "$cmd" in
    install-software|migrate-laptop|migrate-claude-code)
        script="$SCRIPT_DIR/bin/$cmd.sh"
        if [[ ! -x "$script" ]]; then
            echo "error: $script is missing or not executable" >&2
            exit 1
        fi
        exec "$script" "$@"
        ;;
    -h|--help|help)
        print_usage
        ;;
    *)
        echo "error: unknown subcommand: $cmd" >&2
        echo >&2
        print_usage >&2
        exit 1
        ;;
esac
