# examples/

Starter templates for personal overlays that aren't tracked by this repo.

- **`Brewfile.local`** — copy to the repo root as `Brewfile.local`
  (gitignored). Merged by `bin/brew-bundle.sh` on top of the public
  `Brewfile`. Use for company tools, machine-specific extras, or any
  entry you don't want in the public list.

- **`gitconfig-work-include`** — if you need a work-specific git
  identity (different email, signing key, or includes), create an
  overlay file outside this repo and reference it from `~/.gitconfig`
  via a `[includeIf "gitdir:~/workspaces/work/"]` block. Example
  snippet included.

Nothing in this directory is applied automatically.
