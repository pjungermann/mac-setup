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
# Fresh-Mac bootstrap (no git required yet):
#   curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/main/mac-setup.sh -o mac-setup.sh
#   chmod +x mac-setup.sh
#   ./mac-setup.sh
# fetches the full repo as a tarball and re-execs from there.

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

# 0. Self-bootstrap when invoked as a single-file download. Fetches the
# full repo as a tarball (no git required yet) and re-execs from there.
# Later, after `brew bundle` installs git, install-software converts the
# dest into a real git clone so subsequent runs can `git pull`.
if [[ ! -d "$SCRIPT_DIR/bin" ]]; then
    dest="${MAC_SETUP_DIR:-$HOME/mac-setup}"
    echo
    echo "=== Bootstrapping full repo to $dest ==="
    mkdir -p "$dest"
    curl -fsSL "https://github.com/pjungermann/mac-setup/archive/refs/heads/main.tar.gz" \
        | tar xz --strip-components=1 -C "$dest"
    exec "$dest/mac-setup.sh" "$@"
fi

# Default subcommand when none supplied, preserving the pre-router UX of
# `./mac-setup.sh` running the installer.
if [[ $# -eq 0 ]]; then
    set -- install-software
fi

cmd="$1"
shift

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
