#!/usr/bin/env bash
# verify.sh — per-project verification hook.
# Called by the Claude Code PostToolUse hook after every Write|Edit with the
# path of the file that was just written or edited as $1.
#
# dev-machine-setup is a shell-and-config repo, so we lint the file types we
# actually edit: shell, PowerShell, and JSON. Each check is single-file and
# fast. Optional linters (shellcheck, pwsh) are used when present and
# silently skipped when not — verify.sh must not fail just because a dev
# hasn't installed the optional tool yet.
#
# RULES:
# - This runs on EVERY Write/Edit. Keep it FAST (<2s total).
# - Prefer single-file operations.
# - Exit 0 on success (silent), non-zero on failure.

set -uo pipefail

FILE="${1:-}"
[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

case "$FILE" in
  *.sh)
    bash -n "$FILE" || exit 1
    if command -v shellcheck >/dev/null 2>&1; then
      shellcheck -x "$FILE" || exit 1
    fi
    ;;

  *.ps1)
    if command -v pwsh >/dev/null 2>&1; then
      pwsh -NoProfile -Command "
        \$null = [System.Management.Automation.Language.Parser]::ParseFile(
          '$FILE', [ref]\$null, [ref]\$errors)
        if (\$errors) { \$errors | ForEach-Object { Write-Error \$_ }; exit 1 }
      " || exit 1
    fi
    ;;

  *.json)
    jq empty "$FILE" || exit 1
    ;;
esac

exit 0
