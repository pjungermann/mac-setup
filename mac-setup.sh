#!/usr/bin/env bash
# mac-setup — personal-first fresh-Mac setup.
# See AGENTS.md for conventions. Idempotent; safe to rerun.
#
# Usage: ./mac-setup.sh
#
# Prereqs: a fresh macOS install with Xcode Command Line Tools installable
# (xcode-select --install). Everything else bootstraps from here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

section() {
    echo
    echo "=== $1 ==="
}

# 0. Self-bootstrap when invoked as a single-file download (curl -o ... && ./mac-setup.sh).
# Fetches the full repo as a tarball (no git required yet) and re-execs from there.
# Later, after `brew bundle` installs git, we convert the dest into a real git clone
# so subsequent runs can `git pull`.
if [[ ! -d "$SCRIPT_DIR/bin" ]]; then
    dest="${MAC_SETUP_DIR:-$HOME/mac-setup}"
    section "Bootstrapping full repo to $dest"
    mkdir -p "$dest"
    curl -fsSL "https://github.com/pjungermann/mac-setup/archive/refs/heads/main.tar.gz" \
        | tar xz --strip-components=1 -C "$dest"
    exec "$dest/mac-setup.sh" "$@"
fi

# 1. Xcode Command Line Tools
section "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    echo "already installed"
else
    xcode-select --install
    until xcode-select -p >/dev/null 2>&1; do
        read -rsn1 -p "Press any key once the Xcode CLT install completes. "
        echo
    done
fi

# 2. Homebrew
section "Homebrew"
if command -v brew >/dev/null 2>&1; then
    brew update
else
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # shellcheck disable=SC2016 # intentional: literal written to .zprofile
    brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
    if ! grep -qF "$brew_shellenv" "$HOME/.zprofile" 2>/dev/null; then
        echo "$brew_shellenv" >> "$HOME/.zprofile"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 3. Pre-install notes — flag anything the user needs to prepare before packages install.
section "Pre-install notes"
if [[ -x "$SCRIPT_DIR/bin/notes.sh" ]]; then
    "$SCRIPT_DIR/bin/notes.sh" --phase prereq || true
fi

# 4. Homebrew packages (via wrapper that skips MDM-preinstalled .app casks).
section "Homebrew packages"
"$SCRIPT_DIR/bin/brew-bundle.sh"

# 4b. If we bootstrapped from a tarball, convert the dir to a git clone now that
# git exists (installed by step 4). Reruns can then `cd $SCRIPT_DIR && git pull`.
if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
    section "Converting bootstrapped dir to git clone"
    (
        cd "$SCRIPT_DIR"
        git init -q -b main
        git remote add origin https://github.com/pjungermann/mac-setup.git
        git fetch origin main -q
        git reset --hard origin/main -q
        git branch --set-upstream-to=origin/main main >/dev/null
    )
fi

# 5. chezmoi — apply dotfiles from this repo as the chezmoi source.
# chezmoi's run_once_before_ scripts install Oh My Zsh before placing .zshrc.
section "chezmoi dotfiles"
chezmoi init --apply --source="$SCRIPT_DIR"

# 6. Default shell → zsh (macOS default since Catalina; no-op most of the time).
if [[ "$SHELL" != "/bin/zsh" ]]; then
    section "Default shell"
    chsh -s /bin/zsh
fi

# 7. mise runtimes — reads ~/.config/mise/config.toml placed by chezmoi.
section "mise runtimes"
mise install

# 8. Yarn via Corepack (Node ships with Corepack; per-project pinning via packageManager).
section "Yarn via Corepack"
corepack enable
corepack install -g yarn@stable

# 9. Claude Code CLI — not in Homebrew; installed via Anthropic's official script.
section "Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
    echo "already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 10. Post-install notes — surfaces per-app post-steps (profile imports, SSO sign-ins, etc.).
section "Post-install notes"
if [[ -x "$SCRIPT_DIR/bin/notes.sh" ]]; then
    "$SCRIPT_DIR/bin/notes.sh" --phase post --summary || true
fi

echo
echo "Setup complete. Open a new terminal to pick up shell changes."
