# AGENTS.md

Conventions for human and AI contributors working in this repo. Read these
before changing anything; CI enforces several of them.

## What this repo is

`mac-setup` provisions a **fresh macOS install** from scratch to a working
personal workstation, idempotently. The current laptop's state is out of
scope for the install flow; the goal is new-laptop setup and the ability
to rerun as new tools are added over time.

`mac-setup.sh` is a thin router that dispatches to a matching script
under `bin/`:

- `install-software` (default) performs the fresh-Mac install flow.
- `migrate-laptop` and `migrate-claude-code` are backup / restore helpers
  for the state the install flow cannot regenerate (SSH / GPG keys,
  shell history, dotfile overlays, `~/.claude`). They never run as part
  of install; the user invokes them on demand.

## Non-negotiables

- **No company references** in tracked files. The repo is public and
  personal-first. Company-only tools live in `Brewfile.local`
  (gitignored) and work-only git config in a separate overlay.
- **`~/.claude/` is out of scope for `install-software`.** The install
  flow must not read, write, or template that directory. Backup and
  restore of Claude Code configuration, memory, and history is handled
  by `bin/migrate-claude-code.sh` (reachable as
  `./mac-setup.sh migrate-claude-code`), which the user runs on demand.
- **Everything idempotent.** Running `./mac-setup.sh install-software`
  (the default when no subcommand is passed) on an already-provisioned
  machine must be a safe no-op or a controlled update, never a
  destructive reinstall.

## Package manager priority

**mise > brew > mas.**

- **Runtimes** (languages, build tools, project-scoped versions):
  `dot_config/mise/config.toml`. Not Brewfile.
- **System tools, CLIs, GUI apps**: `Brewfile` (formulae + casks).
- **Mac App Store only**: `mas` entries in Brewfile, reserved for apps
  that are genuinely MAS-exclusive (e.g. Amphetamine).

When a tool exists in multiple tiers, migrate up: mas → brew cask when a
cask exists; brew formula → mise when a mise plugin exists.

## MDM / preinstalled apps

The Brewfile stays a complete personal-first list. `bin/brew-bundle.sh`
inspects `/Applications/` at install time and skips any cask whose
`.app` is already present but not brew-managed (typically an MDM push
on a corporate Mac). No per-machine conditionals in the Brewfile.

Limitation: casks that deliver a `.pkg` installer (e.g. `aws-vpn-client`)
aren't filtered — their install path isn't inferable from cask metadata.
This is acceptable because those apps are rarely MDM-preinstalled.

## Pre/post-install notes

Any step a user must do before or after an app installs
(profile restore, SSO sign-in, interactive first-launch) belongs in
`config/notes.yaml`. `bin/notes.sh` renders them with severity-based
coloring. Schema is documented at the top of `config/notes.yaml`.

Rule of thumb: if a package needs something the installer can't
automate, add a note rather than silently assuming the user remembers.

## Shell scripting

- `#!/usr/bin/env bash` with `set -euo pipefail`.
- Target **macOS bash 3.2** (the system `/bin/bash`). No `declare -A`,
  no `mapfile` / `readarray`, no `${var,,}` lowercasing. Use tempfile +
  awk lookups and `while read` with process substitution instead.
- **shellcheck clean.** CI runs shellcheck on every `.sh`. Use
  inline `# shellcheck disable=SCNNNN # reason` only with a reason
  comment.

## Chezmoi conventions

- Source tree uses chezmoi's filename convention: `dot_X` → `~/.X`,
  `dot_config/foo/bar` → `~/.config/foo/bar`.
- `run_once_before_*.sh` scripts run once per content hash, before
  files are applied. Used here to bootstrap Oh My Zsh prior to placing
  `.zshrc`.
- `.chezmoiignore` whitelists the dotfile sources; everything else in
  this repo (Brewfile, bin/, docs, CI) is ignored by chezmoi.

## Commits

Conventional Commits: `type(scope): subject`. CI enforces this via
commitlint. See `.commitlintrc.json` for allowed `type-enum` and
`scope-enum` — add new scopes there when needed, not ad-hoc.

## Local overlays (gitignored)

- `Brewfile.local` — company tools, machine-specific extras.
  Merged by `bin/brew-bundle.sh` at install time.
- `.idea/`, `.vscode/`, `.DS_Store` — editor and OS cruft.

## Bootstrap flow

`mac-setup.sh` is a thin router. When invoked as a single-file download
with the repo not yet present, it fetches the full repo as a tarball
(no git required), re-execs, and dispatches to the chosen subcommand.
The default subcommand is `install-software`, which later converts the
extracted dir to a real git clone after `brew bundle` installs git.
Reruns are then plain `git pull && ./mac-setup.sh`.

## Subcommand dispatch

`mac-setup.sh` recognises `install-software`, `migrate-laptop`, and
`migrate-claude-code` as subcommands and `exec`s the matching
`bin/<cmd>.sh`. No arguments defaults to `install-software`, preserving
the pre-router UX.

Every subcommand script is invokable directly from `bin/`
(`./bin/<cmd>.sh …`); the router adds the subcommand UX, it does not
gate access. `migrate-laptop.sh` and `migrate-claude-code.sh` are
additionally self-contained enough for one-shot copies to a target
machine (they verify their own SHA256 and GPG dependencies at run
time). `install-software.sh` is not self-contained: it reads
`$SCRIPT_DIR/bin/notes.sh`, `$SCRIPT_DIR/bin/brew-bundle.sh`, and the
chezmoi source dir, so it only runs correctly from within a cloned
(or tarball-bootstrapped) copy of this repo.
