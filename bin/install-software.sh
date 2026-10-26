#!/usr/bin/env bash
# install-software — personal-first fresh-Mac installer. Invoked by
# mac-setup.sh (usually as `./mac-setup.sh install-software`, which is also
# the default subcommand). Idempotent; safe to rerun.
#
# See AGENTS.md for conventions.
#
# Prereqs: a fresh macOS install with Xcode Command Line Tools installable
# (xcode-select --install). Everything else bootstraps from here.

set -euo pipefail

# bin/install-software.sh lives one level below the repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

section() {
    echo
    echo "=== $1 ==="
}

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
# Rerun from a shell that hasn't sourced ~/.zprofile yet (common right
# after a fresh install) sees no `brew` on PATH, so a plain `command -v`
# gate would send us back through the installer. Check the known install
# roots and source shellenv from there so a rerun recognises an existing
# Homebrew. `/opt/homebrew` is Apple Silicon's default, `/usr/local` is
# Intel's.
section "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # shellcheck disable=SC2016 # intentional: literal written to .zprofile
        brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
        if ! grep -qF "$brew_shellenv" "$HOME/.zprofile" 2>/dev/null; then
            echo "$brew_shellenv" >> "$HOME/.zprofile"
        fi
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
brew update

# Disable Homebrew analytics on every run. Idempotent; brew writes the
# flag to its own config and reruns are no-ops. Re-asserted every time
# so a drift (someone running `brew analytics on` later) stays corrected.
# Guarded in case brew is somehow still off PATH; `|| true` keeps the
# strict-mode script from exiting on a missing-brew edge case.
if command -v brew >/dev/null 2>&1; then
    brew analytics off >/dev/null || true
    echo "Homebrew analytics disabled."
fi

# 3. Pre-install notes. notes.sh needs yq and jq to parse config/notes.yaml.
# On a fresh Mac neither tool exists yet: both live in dot_config/mise/
# config.toml, not the Brewfile, so they only land in step 7 (`mise install`)
# which runs after the bundle. Eager-install any missing one via Homebrew
# just long enough to render the notes, then uninstall what this run put
# down so brew bundle (step 4) is the authoritative installer. If the
# Brewfile declares yq or jq, the bundle reinstalls it; mise owns the
# lasting install on step 7 otherwise. The `(( ))` guard around the
# cleanup loop sidesteps Bash 3.2's "unbound array" under set -u.
section "Pre-install notes"
notes_bootstrap_installed=()
if [[ -x "$SCRIPT_DIR/bin/notes.sh" ]]; then
    for tool in yq jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "Bootstrapping $tool via Homebrew to render pre-install notes." >&2
            brew install "$tool"
            notes_bootstrap_installed+=("$tool")
        fi
    done
    "$SCRIPT_DIR/bin/notes.sh" --phase prereq || true
    if (( ${#notes_bootstrap_installed[@]} )); then
        for tool in "${notes_bootstrap_installed[@]}"; do
            echo "Removing bootstrap-installed $tool so brew bundle is authoritative." >&2
            brew uninstall "$tool" || echo "  (uninstall failed; $tool left in place)" >&2
        done
    fi
fi

# 3b. Pause for optional Brewfile.local prep. The installer runs end-to-end
# with no natural stopping point before packages install. Users with
# private/work-specific brew/cask/tap entries land them in Brewfile.local;
# on a fresh laptop that's the first chance to add one, and entries that
# reference SSH-authenticated repos also need SSH keys in place (via a
# prior migrate-laptop restore). Prompt the user to prepare both before
# the bundle runs. MAC_SETUP_SKIP_LOCAL_PROMPT=1 bypasses the pause for
# scripted installs; a non-interactive stdin (no TTY) is also skipped.
if [[ ! -f "$SCRIPT_DIR/Brewfile.local" ]] \
   && [[ "${MAC_SETUP_SKIP_LOCAL_PROMPT:-0}" != "1" ]] \
   && [[ -t 0 ]]; then
    section "Prepare Brewfile.local (optional)"
    cat <<EOF
No Brewfile.local found at ${SCRIPT_DIR}/Brewfile.local.

If you have private or work-specific brew / cask / tap entries to add,
create that file now (in another terminal), then press Enter to continue.

Entries that reference SSH-authenticated private taps also need your SSH
keys in place; if you have a laptop-migration tarball, restore it in
another terminal first:

    ./mac-setup.sh migrate-laptop install <tarball>

Press Enter to continue (no overlay, or with the Brewfile.local you just
created). Press Ctrl-C to abort. Set MAC_SETUP_SKIP_LOCAL_PROMPT=1 to
skip this prompt on reruns.
EOF
    read -r _ || true
fi

# 4. Homebrew packages (via wrapper that skips MDM-preinstalled .app casks).
section "Homebrew packages"
"$SCRIPT_DIR/bin/brew-bundle.sh"

# 4a. Safety net for a $SCRIPT_DIR that is not a git clone: the normal
# bootstrap in mac-setup.sh clones directly, so this only fires if the
# repo was manually extracted (zip, tarball, etc). Converts the dir to
# a real clone so reruns can `cd $SCRIPT_DIR && git pull`.
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

# 5. chezmoi. Apply dotfiles from this repo as the chezmoi source.
# chezmoi's run_once_before_ scripts install Oh My Zsh before placing .zshrc.
section "chezmoi dotfiles"
chezmoi init --apply --source="$SCRIPT_DIR"

# 6. Default shell is zsh (macOS default since Catalina; no-op most of the time).
if [[ "$SHELL" != "/bin/zsh" ]]; then
    section "Default shell"
    chsh -s /bin/zsh
fi

# 7. mise runtimes. Reads ~/.config/mise/config.toml placed by chezmoi.
section "mise runtimes"
mise install

# 8. Yarn via Corepack (Node ships with Corepack; per-project pinning via
# packageManager).
section "Yarn via Corepack"
corepack enable
corepack install -g yarn@stable

# 9. Claude Code CLI. Not in Homebrew; installed via Anthropic's official
# script.
section "Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
    echo "already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 10. Post-install notes. Surfaces per-app post-steps (profile imports, SSO
# sign-ins, etc.).
section "Post-install notes"
if [[ -x "$SCRIPT_DIR/bin/notes.sh" ]]; then
    "$SCRIPT_DIR/bin/notes.sh" --phase post --summary || true
fi

echo
echo "Setup complete. Open a new terminal to pick up shell changes."
