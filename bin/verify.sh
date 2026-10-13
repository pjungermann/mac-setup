#!/usr/bin/env bash
# verify.sh — smoke-test a freshly provisioned Mac.
#
# Checks that the key binaries are on PATH after running mac-setup.sh.
# Does not exercise functionality — just presence. Prints a per-tool
# OK/MISSING line and exits non-zero if anything is missing.

set -uo pipefail

tools=(
    # Core
    brew
    git
    gh
    chezmoi
    mise
    # Containers / infra
    docker
    kubectl
    helm
    aws
    # Dev tooling
    go
    node
    python
    java
    jq
    yq
    # Security
    trivy
    grype
    sops
    gnupg
    # Shell quality
    shellcheck
    yamllint
    # Agent CLI
    claude
)

missing=0
ok=0

for t in "${tools[@]}"; do
    # gnupg installs as `gpg`; aws cli as `aws`; node binaries vary.
    case "$t" in
        gnupg) bin=gpg ;;
        *)     bin="$t" ;;
    esac

    if command -v "$bin" >/dev/null 2>&1; then
        printf "  OK      %s\n" "$t"
        ok=$((ok + 1))
    else
        printf "  MISSING %s\n" "$t"
        missing=$((missing + 1))
    fi
done

echo
echo "verify: $ok ok, $missing missing"

(( missing == 0 ))
