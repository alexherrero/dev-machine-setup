#!/usr/bin/env bash
# setup.sh — one-shot bootstrap for a fresh dev environment.
#
# Detects OS (macos | debian) via scripts/lib/os.sh, then runs the platform's
# install stages in order. Each stage's banner is printed by the sub-script
# (`==> <name>`); this orchestrator adds an outer `====> stage: <name>` so
# the boundary is obvious in long logs.
#
# Stage lists differ by OS:
#   macos   : brew → clis → gui-apps → link-configs → verify-install → auth-checklist
#   debian  : apt  → clis → link-configs → verify-install → auth-checklist
# (no gui-apps on Debian — CLI-only scope; Antigravity is GUI-only by design)
#
# Individual stage scripts live in scripts/; captured configs live in
# configs/. See README.md for the full layout.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source OS detection. Sets $OS to macos|debian, exits 2 on unsupported.
# shellcheck source=scripts/lib/os.sh
. "$REPO_ROOT/scripts/lib/os.sh"

# Parallel arrays — bash 3.2 compat (no associative arrays on macOS's
# system bash). Indexes line up across the three. Built per-OS below.

if [[ "$OS" == "macos" ]]; then
  STAGE_NAMES=(brew clis gui-apps link-configs verify-install auth-checklist)
  STAGE_SCRIPTS=(
    "$REPO_ROOT/scripts/install-brew.sh"
    "$REPO_ROOT/scripts/install-clis.sh"
    "$REPO_ROOT/scripts/install-gui-apps.sh"
    "$REPO_ROOT/scripts/link-configs.sh"
    "$REPO_ROOT/scripts/verify-install.sh"
    "$REPO_ROOT/scripts/auth-checklist.sh"
  )
  STAGE_DESCS=(
    "Install Homebrew + formulae (node, gh, jq, ripgrep, shellcheck, shfmt)"
    "Install Claude Code CLI (curl) + Gemini CLI + Codex CLI (npm globals)"
    "Install Antigravity, Gemini Desktop, Claude Desktop (browser-assisted)"
    "Place captured configs from configs/ into their OS locations"
    "Health-check the install (warn-only — tools, configs, agents, skills)"
    "Print the manual auth steps (claude login, gh auth login, etc.)"
  )
else # debian
  STAGE_NAMES=(apt clis link-configs verify-install auth-checklist)
  STAGE_SCRIPTS=(
    "$REPO_ROOT/scripts/install-apt.sh"
    "$REPO_ROOT/scripts/install-clis.sh"
    "$REPO_ROOT/scripts/link-configs.sh"
    "$REPO_ROOT/scripts/verify-install.sh"
    "$REPO_ROOT/scripts/auth-checklist.sh"
  )
  STAGE_DESCS=(
    "Install apt formulae (NodeSource node 22, gh, jq, ripgrep, shellcheck, shfmt)"
    "Install Claude Code CLI (curl) + Gemini CLI + Codex CLI (npm globals)"
    "Place captured configs from configs/ into their OS locations"
    "Health-check the install (warn-only — tools, configs, agents, skills)"
    "Print the manual auth steps (claude login, gh auth login, etc.)"
  )
fi

usage() {
  cat <<EOF
Usage: ./setup.sh [OPTIONS]

Bootstrap a fresh dev environment by running each install stage in order.
Detected OS: $OS

Stages ($OS):
EOF
  local i
  for i in "${!STAGE_NAMES[@]}"; do
    printf '  %-15s %s\n' "${STAGE_NAMES[$i]}" "${STAGE_DESCS[$i]}"
  done
  cat <<'EOF'

Options:
  --dry-run           Print the ordered stage list and exit (no scripts run)
  --skip-apps         Skip the gui-apps stage (no-op on Debian — no GUI stage)
  --only <stage>      Run only the named stage
  --with-codex        Also install Codex CLI (@openai/codex). Off by default.
                      (Sets WITH_CODEX=1 for the install-clis stage.)
  -h, --help          Show this help

Supported: macOS (Darwin), Debian/Ubuntu (Linux). Windows: see setup.ps1
(stubbed). Force the Debian path on a Mac for testing with `OS=debian`.
EOF
}

# --- arg parsing ------------------------------------------------------------

DRY_RUN=0
SKIP_APPS=0
ONLY=""
# Per-CLI opt-in flags. Exported as env vars to the install-clis stage so
# its own logic stays simple (no flag-parsing duplicated downstream).
WITH_CODEX="${WITH_CODEX:-0}"

while (($# > 0)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-apps) SKIP_APPS=1 ;;
    --with-codex) WITH_CODEX=1 ;;
    --only)
      [[ $# -lt 2 ]] && { echo "Error: --only requires a stage name" >&2; exit 2; }
      ONLY="$2"
      shift
      ;;
    --only=*) ONLY="${1#--only=}" ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo "Run './setup.sh --help' for usage." >&2
      exit 2
      ;;
  esac
  shift
done

export WITH_CODEX

# --- validate --only target -------------------------------------------------

if [[ -n "$ONLY" ]]; then
  found=0
  for name in "${STAGE_NAMES[@]}"; do
    [[ "$name" == "$ONLY" ]] && { found=1; break; }
  done
  if ((found == 0)); then
    echo "Error: unknown stage: $ONLY" >&2
    echo "Valid stages: ${STAGE_NAMES[*]}" >&2
    exit 2
  fi
fi

# --- build the run plan -----------------------------------------------------

PLAN_IDX=()
for i in "${!STAGE_NAMES[@]}"; do
  name="${STAGE_NAMES[$i]}"
  if [[ -n "$ONLY" && "$name" != "$ONLY" ]]; then
    continue
  fi
  if ((SKIP_APPS == 1)) && [[ "$name" == "gui-apps" ]]; then
    continue
  fi
  PLAN_IDX+=("$i")
done

# --- dry-run ----------------------------------------------------------------

if ((DRY_RUN == 1)); then
  echo "==> planned stages:"
  if ((${#PLAN_IDX[@]} == 0)); then
    echo "    (none)"
  else
    for i in "${PLAN_IDX[@]}"; do
      printf '    %-15s (%s)\n' "${STAGE_NAMES[$i]}" "${STAGE_SCRIPTS[$i]}"
    done
  fi
  exit 0
fi

# --- run --------------------------------------------------------------------

if ((${#PLAN_IDX[@]} == 0)); then
  echo "==> nothing to do (all stages filtered out)"
  exit 0
fi

for i in "${PLAN_IDX[@]}"; do
  name="${STAGE_NAMES[$i]}"
  script="${STAGE_SCRIPTS[$i]}"
  echo ""
  echo "====> stage: $name"
  if [[ ! -f "$script" ]]; then
    # Missing stage script = feature not yet implemented (see PLAN.md tasks).
    # Warn and continue rather than halting — lets partial pipelines still
    # run the stages that do exist. set -e is still active, so a script
    # that exists and fails still halts us.
    echo "  warning: $script does not exist — skipping (see PLAN.md)" >&2
    continue
  fi
  [[ -x "$script" ]] || chmod +x "$script"
  "$script"
done

echo ""
echo "====> setup.sh complete"
