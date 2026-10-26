# mac-setup

Personal-first, idempotent fresh-Mac setup. One command on a brand-new
macOS install produces a working workstation; reruns pick up new tools
as the lists evolve.

## Install

On a fresh Mac, download the bootstrap script and run it:

```sh
curl -fsSL https://raw.githubusercontent.com/pjungermann/mac-setup/main/mac-setup.sh -o mac-setup.sh
chmod +x mac-setup.sh
./mac-setup.sh
```

The script triggers the Xcode Command Line Tools install (git ships
with CLT), then git-clones the repo to `~/mac-setup/` and re-execs
from there. Reruns of the bootstrap pull the existing clone with
`git pull --ff-only`. The explicit form is:

```sh
cd ~/mac-setup && git pull && ./mac-setup.sh
```

## Subcommands

`mac-setup.sh` is a thin router that dispatches to a matching script
under `bin/`. The default (no subcommand) is `install-software`, so the
fresh-Mac flow above is unchanged.

```sh
./mac-setup.sh                              # defaults to install-software
./mac-setup.sh install-software             # bin/install-software.sh
./mac-setup.sh migrate-laptop <args>        # bin/migrate-laptop.sh
./mac-setup.sh migrate-claude-code <args>   # bin/migrate-claude-code.sh
./mac-setup.sh --help
```

Each subcommand script is also directly invokable from `bin/`.

## install-software

Provisions a fresh macOS install from scratch to a working personal
workstation. Idempotent; reruns pick up anything you have added to the
Brewfile, dotfile templates, or `config/notes.yaml` since the last run.
In order:

1. Xcode Command Line Tools, installed via `xcode-select --install` if missing.
2. Homebrew, via the official installer, with `shellenv` wired into `~/.zprofile`.
3. **Pre-install notes.** `bin/notes.sh --phase prereq` surfaces anything you must prepare up front (keys, profiles, SSO).
4. Homebrew packages. `bin/brew-bundle.sh` runs `brew bundle` on the tracked `Brewfile` plus optional `Brewfile.local`, skipping any cask whose `.app` is already present but not brew-managed (handles MDM-pushed apps transparently).
5. Repo-as-clone. The normal bootstrap already produces a git clone; this step is a safety net for anyone running `install-software` from a manually-extracted tarball (no `.git/`) and makes that directory into one.
6. chezmoi applies dotfiles (`dot_zshrc.tmpl`, `dot_gitconfig.tmpl`, `dot_config/mise/config.toml`) from this repo as the chezmoi source. A `run_once_before_` script installs Oh My Zsh first.
7. Default shell. `chsh -s /bin/zsh` runs if your login shell isn't already zsh.
8. mise runtimes. `mise install` picks up `~/.config/mise/config.toml`.
9. Yarn, enabled via Corepack; per-project versions pinned via each project's `packageManager` field.
10. Claude Code CLI, installed from Anthropic's official script.
11. **Post-install notes.** `bin/notes.sh --phase post` prints per-app follow-ups (profile restores, SSO sign-ins, interactive first launches).

## migrate-laptop

Bundles the irreplaceable bits a fresh `install-software` run cannot
regenerate, carries them across a laptop switch, and surveys the source
machine beforehand so you know what will travel. Deliberately does not
carry auth tokens or cloud configs: `aws sso login`, `gh auth login`,
`docker login <registry>`, `op signin`, `cargo login`, and package
registry CLIs each regenerate theirs on first use, and travelling them
widens the attack surface for no real time saving.

Commands:

1. `scan`. Read-only report of what would travel. Homebrew leaves and casks, mas apps, SSH and GPG keys, workspace repos (with highlights for anything with uncommitted or unpushed work), cloud / CLI auth that will need re-logging on the new laptop, and a Brewfile delta against the Brewfile in the mac-setup clone this script runs from.
2. `export [--dry-run] [--yes] [--encrypt] [outfile]`. Writes a tar.gz plus `.sha256` sidecar with SSH keys and config, GPG keyring exports (public and secret keys plus ownertrust), shell history, `*.local` dotfile overlays, and the scan reports. The bundle carries real secrets; `--encrypt` streams the tar through `gpg -c` (AES-256 symmetric) so the plaintext tar never touches disk.
3. `install [--dry-run] <tarball>`. On the new laptop. Verifies the SHA256 fail-closed and extracts into `$HOME`. Any pre-existing collision (for example `~/.ssh`) is moved to a timestamped `.backup-<stamp>/` sibling before the bundled copy is placed, so first-boot `known_hosts` entries you accumulated between fresh-OS and restore are preserved in the backup rather than merged.
4. `verify [--root <path>]`. Lists what the restore placed and what is still missing.

## migrate-claude-code

Backs up and restores `~/.claude` state (CLAUDE.md, guidance, skills,
hooks, plugin data, session transcripts, prompt history). Never invoked
by `install-software`; the user runs it on demand, for recurring
backups, rollback after a bad config change, or carrying Claude Code
state to a new machine. Session transcripts can hold anything you or
Claude handled during a session, so treat the resulting tarball as
sensitive (use `--encrypt`, do not leave it on shared storage, delete
after restore).

Commands:

1. `backup [--yes] [--encrypt] [outfile]`. Writes a tar.gz plus `.sha256` sidecar. Drift-detects entries under `~/.claude/` that are not in the include or exclude catalog and prompts before continuing (`--yes` skips the prompt). `--encrypt` streams the tar through `gpg -c` (AES-256 symmetric).
2. `restore [--dry-run] <tarball>`. Verifies the SHA256 fail-closed and extracts over `~/.claude/`. Any existing directory is first copied to `~/.claude.backup-<stamp>/` so a bad restore is reversible. Machine-local state outside the include catalog (caches, daemon logs, downloads) is left alone.
3. `verify [--root <path>]`. Checks the extracted state and lists plugin counts plus MCP integrations found in enabled plugins. MCP tokens are not transferred; re-authenticate via the plugin's own flow on first use.
4. `list`. Lists project-memory directories under `~/.claude/projects/`.

`export` and `install` remain as back-compat aliases for `backup` and
`restore`.

## Conventions

See [AGENTS.md](./AGENTS.md). Highlights:

- Package manager priority: **mise > brew > mas**.
- Public repo, personal-first; no company references in tracked files.
- `~/.claude/` is not touched by the `install-software` flow; use `./mac-setup.sh migrate-claude-code` (or `bin/migrate-claude-code.sh`) to back it up or restore it.
- All shell scripts target macOS bash 3.2 and must pass shellcheck.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/); CI runs commitlint on PR commits.

## Forking

The repo is personal-first but structured for forks:

- Edit `Brewfile`, `dot_*` templates, and `config/notes.yaml` to match your own setup.
- Keep private or work-only entries in `Brewfile.local` (gitignored); see `examples/Brewfile.local`.
- Work-specific git identity goes in a separate overlay included from `~/.gitconfig`; see `examples/gitconfig-work-include`.

## License

[MIT](./LICENSE)
