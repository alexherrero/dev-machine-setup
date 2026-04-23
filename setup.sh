#!/usr/bin/env bash
# setup.sh — one-shot bootstrap for a fresh Mac dev environment.
#
# Runs the install stages in order: Homebrew formulae, Claude Code CLI,
# GUI apps (Antigravity / Gemini / Claude Desktop), config linking, and
# the post-setup auth checklist.
#
# Individual stage scripts live in scripts/; captured config files live
# in configs/. See README.md for the full layout.
#
# This file is currently a stub. Flag handling (--dry-run, --skip-apps,
# --only <stage>) and stage dispatch land in PLAN.md task 7. Today it
# prints usage and exits.

set -euo pipefail

readonly STAGES=(
  "brew           Install Homebrew + formulae (node, gh, jq, ripgrep, shellcheck, shfmt, gemini-cli)"
  "claude-cli     Install Claude Code CLI via Anthropic's curl installer"
  "gui-apps       Download + install Antigravity, Gemini Desktop, Claude Desktop"
  "link-configs   Place captured configs from configs/ into their OS locations"
  "auth-checklist Print the manual auth steps (claude login, gh auth login, etc.)"
)

usage() {
  cat <<EOF
Usage: ./setup.sh [--help]

Bootstrap a fresh Mac dev environment by running each install stage in order.

Stages:
EOF
  for stage in "${STAGES[@]}"; do
    printf '  %s\n' "$stage"
  done
  cat <<'EOF'

Flags (future — not yet implemented, see PLAN.md task 7):
  --dry-run      Print the ordered stage list and exit
  --skip-apps    Skip the gui-apps stage (useful for headless runs)
  --only <name>  Run only the named stage

This script is Mac-first. Windows users: see setup.ps1 (stubbed — PLAN.md task 9).
EOF
}

case "${1:-}" in
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown argument: $1" >&2
    echo "Run './setup.sh --help' for usage." >&2
    exit 1
    ;;
esac
