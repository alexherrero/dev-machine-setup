#!/usr/bin/env bash
# init.sh — boot the dev environment for dev-machine-setup.
#
# This repo is a collection of configs and scripts for provisioning a dev
# machine, so there's nothing to "run" — init instead verifies the tools
# we rely on during /work and /review are available. Fails fast on missing
# required tools; warns on missing optional ones.

set -euo pipefail

REQUIRED=(git gh jq bash)
OPTIONAL=(shellcheck shfmt brew)

missing_required=()

echo "==> checking required tools"
for tool in "${REQUIRED[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '    %-12s %s\n' "$tool" "$("$tool" --version 2>&1 | head -1)"
  else
    printf '    %-12s MISSING\n' "$tool"
    missing_required+=("$tool")
  fi
done

echo "==> checking optional tools"
for tool in "${OPTIONAL[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '    %-12s %s\n' "$tool" "$("$tool" --version 2>&1 | head -1)"
  else
    printf '    %-12s not installed (optional)\n' "$tool"
  fi
done

if ((${#missing_required[@]} > 0)); then
  echo "==> FAIL: missing required tools: ${missing_required[*]}" >&2
  exit 1
fi

echo "==> ready"
