#!/usr/bin/env bash
# brew-bundle wrapper.
#
# Reads Brewfile (plus Brewfile.local if present), filters out cask and mas
# entries whose target .app is already in /Applications/ but not managed by
# brew or mas (typically MDM-preinstalled on a managed Mac). Passes any
# remaining args to `brew bundle`.
#
# Why: `brew install --cask slack` on top of an MDM-provisioned Slack.app
# either errors or clobbers the IT-managed install. The wrapper lets the
# Brewfile stay a complete personal-first list without needing per-machine
# conditionals.
#
# Limitation: only `app` artifacts in casks are matched. Casks that deliver
# a `pkg` installer (e.g. aws-vpn-client) are not filtered — they install
# to arbitrary paths that aren't trivially inferable from the cask metadata.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="${REPO_ROOT}/Brewfile"
BREWFILE_LOCAL="${REPO_ROOT}/Brewfile.local"

if [[ ! -f "$BREWFILE" ]]; then
    echo "brew-bundle: no Brewfile at $BREWFILE" >&2
    exit 1
fi

combined=$(mktemp -t brew-bundle-combined.XXXXXX)
filtered=$(mktemp -t brew-bundle-filtered.XXXXXX)
cask_map=$(mktemp -t brew-bundle-cask-map.XXXXXX)
trap 'rm -f "$combined" "$filtered" "$cask_map"' EXIT

cat "$BREWFILE" > "$combined"
if [[ -f "$BREWFILE_LOCAL" ]]; then
    {
        echo ""
        echo "# --- merged from Brewfile.local ---"
        cat "$BREWFILE_LOCAL"
    } >> "$combined"
fi

# Collect all casks referenced in the combined file for a single lookup.
# `|| true` on the grep so pipefail doesn't abort the script when the
# Brewfile declares no casks (grep exit 1 would propagate otherwise).
all_casks=$({ grep -oE '^[[:space:]]*cask[[:space:]]+"[^"]+"' "$combined" || true; } \
    | sed -E 's/^[[:space:]]*cask[[:space:]]+"//; s/"$//' \
    | sort -u)

# Build cask_token<TAB>app_bundle_name map via one brew-info call.
# macOS bash 3.2 lacks associative arrays, so we use a tempfile + awk lookup.
if [[ -n "$all_casks" ]]; then
    # shellcheck disable=SC2086
    brew info --cask --json=v2 $all_casks 2>/dev/null \
        | jq -r '.casks[]? | [.token, (.artifacts[]? | select(.app?) | .app[0])] | @tsv' \
        > "$cask_map"
fi

lookup_app_name() {
    awk -F'\t' -v t="$1" '$1 == t { print $2; exit }' "$cask_map"
}

brew_installed_casks=$(brew list --cask 2>/dev/null || true)
mas_installed=$(mas list 2>/dev/null | awk '{$1=""; sub(/ \(.*\)$/, ""); sub(/^ /, ""); print}' || true)

skipped=0
while IFS= read -r line; do
    skip_reason=""

    if [[ "$line" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
        token="${BASH_REMATCH[1]}"
        if ! grep -qx "$token" <<<"$brew_installed_casks"; then
            app=$(lookup_app_name "$token")
            if [[ -n "$app" && -d "/Applications/$app" ]]; then
                skip_reason="/Applications/$app present, not brew-managed"
            fi
        fi
    elif [[ "$line" =~ ^[[:space:]]*mas[[:space:]]+\"([^\"]+)\" ]]; then
        name="${BASH_REMATCH[1]}"
        if ! grep -qx "$name" <<<"$mas_installed"; then
            if [[ -d "/Applications/$name.app" ]]; then
                skip_reason="/Applications/$name.app present, not mas-managed"
            fi
        fi
    fi

    if [[ -n "$skip_reason" ]]; then
        echo "brew-bundle: skipping $line  ($skip_reason)" >&2
        echo "# [brew-bundle: skipped — $skip_reason] $line" >> "$filtered"
        skipped=$((skipped + 1))
    else
        echo "$line" >> "$filtered"
    fi
done < "$combined"

if (( skipped > 0 )); then
    echo "brew-bundle: filtered $skipped line(s); invoking brew bundle" >&2
fi

# Pre-trust any third-party taps declared in the Brewfile(s). Recent
# Homebrew (4.6+) prompts for trust on first install from a non-core
# tap; `brew bundle` has no interactive hook for that prompt and stalls
# on "Installing <tap>/<formula>". Install step 2 runs `brew update` on
# every invocation, so by the time this wrapper runs we're always on a
# brew that ships `brew trust` and no version gating is needed.
# `brew trust` is itself idempotent and prints nothing on success, so
# we echo per tap to make the privilege change visible in the output.
# `|| true` on the grep so pipefail doesn't abort when there are no
# tap lines. Only double-quoted `tap "..."` is matched; single-quoted
# Ruby syntax is not the convention in Brewfiles.
taps=$({ grep -oE '^[[:space:]]*tap[[:space:]]+"[^"]+"' "$combined" || true; } \
    | sed -E 's/^[[:space:]]*tap[[:space:]]+"//; s/"$//' \
    | sort -u)
if [[ -n "$taps" ]]; then
    while IFS= read -r tap; do
        [[ -z "$tap" ]] && continue
        echo "brew-bundle: trusting tap $tap" >&2
        brew trust "$tap"
    done <<<"$taps"
fi

exec brew bundle --file="$filtered" "$@"
