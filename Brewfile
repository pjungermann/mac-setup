# mac-setup Brewfile — personal-first.
# See AGENTS.md for conventions. Runtimes belong in mise, not here.
# Work-only extras live in Brewfile.local (gitignored).

# AWS
brew "aws-iam-authenticator"
brew "aws-sam-cli"
brew "awscli"

# Containers / orchestration
brew "docker"
brew "docker-clean"
brew "docker-compose"
brew "docker-credential-helper"
brew "dive"
brew "k9s"
brew "kubectx"
brew "oras"
brew "qemu"
brew "skopeo"

# Databases
brew "mysql-client"
brew "postgresql"

# Dev / build
brew "bfg"
brew "cfn-lint"
brew "corepack"
brew "gcc"
brew "gh"
brew "git"
brew "git-delta"
brew "git-filter-repo"
brew "git-lfs"
brew "git-quick-stats"
brew "go-jsonnet"
brew "golangci-lint"
brew "goreleaser"
brew "hcl2json"
brew "pipx"
brew "python-setuptools"
brew "shellcheck"
brew "swagger-codegen"
brew "tenv"
brew "yamllint"

# Media / graphics
brew "ffmpeg"
brew "ghostscript"
brew "imagemagick"
brew "jpeg"
brew "librsvg"
brew "poppler"

# Security
brew "betterleaks"
brew "cosign"
brew "gnupg"
brew "grype"
brew "kics"
brew "sops"
brew "syft"
brew "trivy"
brew "trufflehog"

# System / shell utilities
brew "adr-tools"
brew "akamai"
brew "bat"
brew "chezmoi"
brew "coreutils"
brew "direnv"
brew "eza"
brew "fd"
brew "findutils"
brew "fzf"
brew "gnu-tar"
brew "htop"
brew "hyperfine"
brew "jqfmt"
brew "mas"
brew "mise"
brew "nmap"
brew "pandoc"
brew "parallel"
brew "ripgrep"
brew "speedtest-cli"
brew "tmux"
brew "vale"
brew "watch"
brew "wget"
brew "wifi-password"

# Personal tap
brew "pjungermann/tap/help-cmd"

# Casks — personal, always install
cask "android-file-transfer"
cask "aws-vpn-client"
cask "bitwarden"
cask "discord"
cask "dropbox"
cask "jetbrains-toolbox"
cask "mitmproxy"
cask "pgadmin4"
cask "rancher"
cask "session-manager-plugin"
cask "spotify"
cask "yubico-authenticator"
cask "zoom"

# Casks — want privately AND MDM may preinstall on company Macs.
# bin/brew-bundle.sh filters any entry whose .app already exists in /Applications/.
cask "1password"
cask "claude"
cask "google-chrome"
cask "slack"

# Mac App Store — only MAS-exclusive apps belong here.
mas "Amphetamine", id: 937984704
mas "AusweisApp", id: 948660805
