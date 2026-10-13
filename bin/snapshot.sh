#!/usr/bin/env bash
# snapshot.sh — show the drift between what's installed and what the
# Brewfile tracks. Useful when a new tool was installed ad-hoc and
# should be promoted to the Brewfile for the next fresh install.
#
# Prints a unified diff: generated-dump vs. current Brewfile. Lines
# prefixed `+` are installed-but-not-tracked (promote candidates);
# lines prefixed `-` are tracked-but-not-installed (uninstalled or
# never got around to installing).
#
# Pass --dump to just print the generated dump without diffing.
#
# Note: `brew bundle dump` lists every installed formula, including
# dependencies that mise or a cask pulled in transitively. Review
# `brew leaves` separately for the true top-level set.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BREWFILE="${REPO_ROOT}/Brewfile"

mode="diff"
if [[ "${1:-}" == "--dump" ]]; then
    mode="dump"
fi

tmp=$(mktemp -t brew-snapshot.XXXXXX)
trap 'rm -f "$tmp"' EXIT

brew bundle dump --file="$tmp" --force --no-vscode

if [[ "$mode" == "dump" ]]; then
    cat "$tmp"
    exit 0
fi

if [[ ! -f "$BREWFILE" ]]; then
    echo "snapshot: no Brewfile at $BREWFILE; printing dump instead" >&2
    cat "$tmp"
    exit 0
fi

diff -u "$BREWFILE" "$tmp" || true
