#!/usr/bin/env bash
# notes.sh — print per-app pre/post-install notes from config/notes.yaml.
#
# Usage:
#   bin/notes.sh --phase prereq
#   bin/notes.sh --phase post [--summary]
#
# Requires: yq (Go-based, Mike Farah's — installed via mise or brew). If yq
# is not yet available (e.g. called from the pre-install phase before brew
# bundle has run), the script prints an advisory and exits 0 so the caller
# can continue.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
NOTES_YAML="${REPO_ROOT}/config/notes.yaml"

phase=""
summary=0

while (( $# )); do
    case "$1" in
        --phase)
            phase="${2:-}"
            shift 2
            ;;
        --summary)
            summary=1
            shift
            ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "notes.sh: unknown argument: $1" >&2
            echo "usage: notes.sh --phase {prereq|post} [--summary]" >&2
            exit 2
            ;;
    esac
done

if [[ "$phase" != "prereq" && "$phase" != "post" ]]; then
    echo "notes.sh: --phase must be 'prereq' or 'post'" >&2
    exit 2
fi

if [[ ! -f "$NOTES_YAML" ]]; then
    exit 0
fi

if ! command -v yq >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "notes.sh: yq/jq not available yet; skipping $phase notes" >&2
    exit 0
fi

if [[ -t 1 ]]; then
    RED=$'\033[31m'
    YELLOW=$'\033[33m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED="" YELLOW="" BOLD="" RESET=""
fi

# Build the set of installer-declared identifiers so a note with a
# `requires:` list only prints when every id in that list is actually
# declared somewhere we install from. Covers Brewfile + Brewfile.local
# brew/cask/mas lines (the mas id lives after the comma; the name in
# quotes is what matches). Entries without `requires` are always shown
# (OS-provided tools like ssh, tool extensions like gh-copilot, etc.).
installed_json='[]'
if command -v grep >/dev/null 2>&1; then
    installed_lines=$(
        {
            grep -hE '^[[:space:]]*(brew|cask|mas)[[:space:]]+"' \
                "$REPO_ROOT/Brewfile" "$REPO_ROOT/Brewfile.local" 2>/dev/null \
                || true
        } | sed -E 's/^[[:space:]]*(brew|cask|mas)[[:space:]]+"([^"]+)".*/\2/'
    )
    if [[ -n "$installed_lines" ]]; then
        installed_json=$(printf '%s\n' "$installed_lines" | jq -R . | jq -sc .)
    fi
fi

# Phase filter -> requires filter -> sort by severity rank then app.
# Rank: required (0) above interactive (1) above optional (2); unknown
# severities drop to the bottom.
entries=$(
    yq -o=json "[.notes[] | select(.phase == \"$phase\")]" "$NOTES_YAML" \
        | jq --argjson installed "$installed_json" '
            def rank(s):
                if s == "required" then 0
                elif s == "interactive" then 1
                elif s == "optional" then 2
                else 3
                end;
            map(
                select(
                    (.requires // null) == null
                    or (.requires | all(. as $r | $installed | index($r) != null))
                )
            )
            | sort_by(rank(.severity), .app)
        '
)
count=$(jq 'length' <<<"$entries")

if (( summary )); then
    printf "%s%d note(s) for phase=%s%s\n\n" "$BOLD" "$count" "$phase" "$RESET"
fi

while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    app=$(jq -r '.app' <<<"$entry")
    severity=$(jq -r '.severity' <<<"$entry")
    message=$(jq -r '.message' <<<"$entry")

    case "$severity" in
        required) color="$RED" ;;
        optional|interactive) color="$YELLOW" ;;
        *) color="" ;;
    esac

    printf "%s%s[%s] %s%s\n" "$color" "$BOLD" "$severity" "$app" "$RESET"
    printf "%s\n\n" "$message"
done < <(jq -c '.[]' <<<"$entries")
