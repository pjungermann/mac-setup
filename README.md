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

The script fetches the full repo as a tarball (no git required yet),
re-execs from `~/mac-setup/`, then after Homebrew installs git it
converts that directory into a real clone so later reruns are just:

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

## What `install-software` does

In order:

1. Xcode Command Line Tools — installed via `xcode-select --install` if missing.
2. Homebrew — official installer, with `shellenv` wired into `~/.zprofile`.
3. **Pre-install notes** — `bin/notes.sh --phase prereq` surfaces anything you must prepare up front (keys, profiles, SSO).
4. Homebrew packages — `bin/brew-bundle.sh` runs `brew bundle` on the tracked `Brewfile` plus optional `Brewfile.local`, skipping any cask whose `.app` is already present but not brew-managed (handles MDM-pushed apps transparently).
5. Repo-as-clone — the bootstrapped `~/mac-setup/` becomes a real git clone of this repo now that git exists.
6. chezmoi — applies dotfiles (`dot_zshrc.tmpl`, `dot_gitconfig.tmpl`, `dot_config/mise/config.toml`) from this repo as the chezmoi source. A `run_once_before_` script installs Oh My Zsh first.
7. Default shell — switches login shell to `/bin/zsh` if it isn't already.
8. mise runtimes — `mise install` picks up `~/.config/mise/config.toml`.
9. Yarn — enabled via Corepack; per-project versions pinned via each project's `packageManager` field.
10. Claude Code CLI — installed from Anthropic's official script.
11. **Post-install notes** — `bin/notes.sh --phase post` prints per-app follow-ups (profile restores, SSO sign-ins, interactive first launches).

## Layout

```text
mac-setup.sh              # router entry point; self-bootstraps when curl'd
Brewfile                  # tracked formulae, casks, mas entries
Brewfile.local            # (gitignored) personal/work extras merged by the wrapper
bin/
  brew-bundle.sh          # Brewfile wrapper; filters MDM-preinstalled casks
  install-software.sh     # the installer flow dispatched by `mac-setup.sh install-software`
  migrate-claude-code.sh  # back up / restore ~/.claude state (encrypted or plain)
  migrate-laptop.sh       # bundle SSH, GPG, shell history and reports for a laptop switch
  notes.sh                # renders config/notes.yaml
  snapshot.sh             # diffs installed state vs. Brewfile (drift detection)
  verify.sh               # smoke-test: are the key binaries on PATH?
config/
  notes.yaml              # declarative pre/post-step registry
dot_zshrc.tmpl            # chezmoi source for ~/.zshrc
dot_gitconfig.tmpl        # chezmoi source for ~/.gitconfig
dot_config/mise/config.toml  # chezmoi source for ~/.config/mise/config.toml
run_once_before_install-omz.sh  # chezmoi hook: install OMZ before .zshrc
examples/                 # starter templates for local overlays
```

## Conventions

See [AGENTS.md](./AGENTS.md). Highlights:

- Package manager priority: **mise > brew > mas**.
- Public repo, personal-first — no company references in tracked files.
- `~/.claude/` is not touched by the `install-software` flow; use `./mac-setup.sh migrate-claude-code` (or `bin/migrate-claude-code.sh`) to back it up or restore it.
- All shell scripts target macOS bash 3.2 and must pass shellcheck.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/); CI runs commitlint on PR commits.

## Migration and backup

Two helpers cover state that `install-software` does not reinstall. Each is reachable both through the router and directly from `bin/`:

- `./mac-setup.sh migrate-claude-code` (`bin/migrate-claude-code.sh`): `backup` / `restore` of `~/.claude` (CLAUDE.md, guidance, skills, hooks, plugin data, session transcripts, prompt history). Supports GPG symmetric encryption; SHA256 verified before extraction. Useful for recurring backups, rollback after a bad config change, or carrying your Claude Code state to a new machine.
- `./mac-setup.sh migrate-laptop` (`bin/migrate-laptop.sh`): bundles the irreplaceable bits a fresh `install-software` run cannot regenerate: SSH keys and config, GPG keys, shell history, dotfile overlays, plus reports (Brewfile delta, workspace inventory, at-risk repos with uncommitted or unpushed work). Does not carry auth tokens or cloud configs; those are expected to be re-generated by the respective CLI (`aws sso login`, `gh auth login`, etc.) on the new laptop. On install, any pre-existing `~/.ssh` is moved to `~/.ssh.backup-<timestamp>/` before the bundled one is placed, so first-boot `known_hosts` entries you accumulated between fresh-OS and restore are preserved in the backup rather than merged.

Both scripts can also be copied standalone to a target machine (they verify an SHA256 sidecar before any extraction).

## Forking

The repo is personal-first but structured for forks:

- Edit `Brewfile`, `dot_*` templates, and `config/notes.yaml` to match your own setup.
- Keep private or work-only entries in `Brewfile.local` (gitignored) — see `examples/Brewfile.local`.
- Work-specific git identity goes in a separate overlay included from `~/.gitconfig` — see `examples/gitconfig-work-include`.

## License

[MIT](./LICENSE).
