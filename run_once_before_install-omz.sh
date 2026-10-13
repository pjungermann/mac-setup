#!/usr/bin/env bash
# Install Oh My Zsh unattended, before chezmoi places dot_zshrc.
#
# chezmoi runs run_once_before_* scripts once per content hash, prior to
# applying files. Required because .zshrc sources $ZSH/oh-my-zsh.sh — if
# OMZ isn't installed when the shell starts, every new terminal errors.
#
# Flags:
#   RUNZSH=no       installer won't spawn a nested interactive zsh
#   CHSH=no         mac-setup.sh handles the login-shell switch (step 6)
#   KEEP_ZSHRC=yes  don't back up or replace .zshrc — chezmoi places ours
set -euo pipefail

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    exit 0
fi

RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
