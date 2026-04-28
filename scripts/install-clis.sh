#!/usr/bin/env bash
# install-clis.sh — install the CLI agents we use:
#   - Claude Code CLI  (Anthropic's curl installer  → ~/.local/bin/claude)
#   - Gemini CLI       (npm global, @google/gemini-cli)
#   - Codex CLI        (npm global, @openai/codex) — OPT-IN via WITH_CODEX=1
#
# Cross-platform. Requires node + npm on PATH from install-brew.sh (Mac)
# or install-apt.sh (Debian). Idempotent: re-running pulls each tool's
# latest stable (no-op if already current).
#
# Codex is opt-in. By default this script installs Claude + Gemini only.
# Pass --with-codex to setup.sh (which exports WITH_CODEX=1), or set the
# env var directly: `WITH_CODEX=1 ./scripts/install-clis.sh`. The reasoning
# is that not every user wants the extra dependency / login flow; making
# it explicit keeps the default install minimal.
#
# PATH handling per platform:
#   macOS  : ~/.local/bin marker appended to ~/.zshrc (captured shell).
#            npm globals install under brew's user-writable prefix; no
#            extra PATH entry needed.
#   Debian : ~/.local/bin AND ~/.npm-global/bin markers. We configure a
#            user-local npm prefix at ~/.npm-global so `npm install -g`
#            works without sudo. RC file picked from $SHELL: ~/.zshrc
#            if zsh, else ~/.bashrc.
#
# Node version: hard-fails if node < 20 on Debian (Gemini CLI requires
# >= 20). Mac brew node is current enough that we don't probe.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/os.sh
. "$REPO_ROOT/scripts/lib/os.sh"

readonly CLAUDE_INSTALLER_URL="https://claude.ai/install.sh"
readonly GEMINI_NPM_PACKAGE="@google/gemini-cli"
readonly CODEX_NPM_PACKAGE="@openai/codex"

# --- helpers ----------------------------------------------------------------

# Pick the rc file to append PATH markers to. Mac is captured zsh; Debian
# follows whatever $SHELL points at.
rc_file() {
  if [[ "$OS" == "debian" ]]; then
    case "${SHELL:-}" in
      */zsh) echo "$HOME/.zshrc" ;;
      *)     echo "$HOME/.bashrc" ;;
    esac
  else
    echo "$HOME/.zshrc"
  fi
}

# Append a single-line PATH export to $rc, guarded by a marker comment
# so re-runs are a no-op.
append_path_marker() {
  local rc="$1" marker="$2" line="$3"
  if ! grep -Fq "$marker" "$rc" 2>/dev/null; then
    {
      echo ""
      echo "$marker"
      # shellcheck disable=SC2016
      echo "$line"
    } >> "$rc"
    echo "    appended PATH export to $rc"
  fi
}

# Debian: configure a user-local npm prefix so `npm install -g` doesn't
# need sudo. Also resolves the chicken-and-egg of Gemini/Codex install
# locations on systems where the system npm prefix is /usr.
configure_npm_prefix_debian() {
  local prefix="$HOME/.npm-global"
  local current_prefix
  current_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ "$current_prefix" != "$prefix" ]]; then
    npm config set prefix "$prefix"
    echo "    npm prefix -> $prefix"
  fi
  mkdir -p "$prefix/bin"
  local rc
  rc="$(rc_file)"
  touch "$rc"
  # Single-quoted on purpose: we want $HOME written literally into the rc
  # file so it expands at shell startup, not at write time.
  # shellcheck disable=SC2016
  append_path_marker \
    "$rc" \
    '# ~/.npm-global/bin (dev-machine-setup — npm globals)' \
    'export PATH="$HOME/.npm-global/bin:$PATH"'
  # Make resolvable in this shell for the post-check.
  export PATH="$prefix/bin:$PATH"
}

# Hard-fail if node is too old for Gemini CLI. Only probed on Debian
# (NodeSource pins 22 LTS so this should pass; the check exists to fail
# fast with a clear pointer if a user manually installed an older node).
check_node_version_debian() {
  if ! command -v node >/dev/null 2>&1; then
    echo "    FAIL: node not found. Run scripts/install-apt.sh first." >&2
    exit 1
  fi
  local major
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if ((major < 20)); then
    echo "    FAIL: Node $(node --version) is too old. Gemini CLI requires >= 20." >&2
    echo "          Run scripts/install-apt.sh to install NodeSource node 22 LTS." >&2
    exit 1
  fi
}

# --- 1. Claude Code CLI -----------------------------------------------------

echo "==> Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  echo "    currently: $(claude --version 2>&1 | head -1)"
fi
# Default target is "stable" — installer is re-entrant; running it again
# either upgrades to latest stable or no-ops if already current.
curl -fsSL "$CLAUDE_INSTALLER_URL" | bash -s stable

# Ensure ~/.local/bin is on PATH for future shells.
RC_FILE="$(rc_file)"
touch "$RC_FILE"
# Single-quoted on purpose: we want $HOME written literally into the rc
# file so it expands at shell startup, not at write time.
# shellcheck disable=SC2016
append_path_marker \
  "$RC_FILE" \
  '# ~/.local/bin (dev-machine-setup — Claude Code CLI)' \
  'export PATH="$HOME/.local/bin:$PATH"'
# Resolve in this shell too, for the post-check.
export PATH="$HOME/.local/bin:$PATH"

# --- 2. npm prerequisite checks --------------------------------------------

echo "==> npm prerequisites"
if ! command -v npm >/dev/null 2>&1; then
  if [[ "$OS" == "macos" ]]; then
    echo "    FAIL: npm not found. Run scripts/install-brew.sh first." >&2
  else
    echo "    FAIL: npm not found. Run scripts/install-apt.sh first." >&2
  fi
  exit 1
fi
if [[ "$OS" == "debian" ]]; then
  check_node_version_debian
  configure_npm_prefix_debian
fi

# --- 3. Gemini CLI ----------------------------------------------------------

echo "==> Gemini CLI ($GEMINI_NPM_PACKAGE)"
if command -v gemini >/dev/null 2>&1; then
  echo "    currently: $(gemini --version 2>&1 | head -1)"
fi
# npm install -g is idempotent: reports "changed N packages" on upgrade,
# "up to date" when already latest.
npm install -g "$GEMINI_NPM_PACKAGE"

# --- 4. Codex CLI (opt-in via WITH_CODEX=1) ---------------------------------

WITH_CODEX="${WITH_CODEX:-0}"
if [[ "$WITH_CODEX" == "1" ]]; then
  echo "==> Codex CLI ($CODEX_NPM_PACKAGE)"
  if command -v codex >/dev/null 2>&1; then
    echo "    currently: $(codex --version 2>&1 | head -1)"
  fi
  npm install -g "$CODEX_NPM_PACKAGE"
else
  echo "==> Codex CLI: skipped (pass --with-codex to setup.sh to include)"
fi

# --- 5. Post-check ----------------------------------------------------------

echo "==> verifying"
# Build the expected-binaries list dynamically so we don't fail-mark `codex`
# missing when it was never asked to be installed.
expected=(claude gemini)
[[ "$WITH_CODEX" == "1" ]] && expected+=(codex)

missing=()
for bin in "${expected[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    version=$("$bin" --version 2>&1 | head -1)
    printf '    %-8s %-40s %s\n' "$bin" "$(command -v "$bin")" "$version"
  else
    printf '    %-8s MISSING\n' "$bin"
    missing+=("$bin")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "==> FAIL: CLIs not on PATH: ${missing[*]}" >&2
  exit 1
fi

echo "==> clis stage complete"
