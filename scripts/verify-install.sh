#!/usr/bin/env bash
# verify-install.sh — post-setup health check.
#
# Warn-only by design: prints PASS / WARN / SKIP per check and exits 0
# regardless. Surfaces what's missing without halting an in-progress
# bootstrap. Two tiers:
#
#   global    — runs always. Tooling on PATH, captured configs at their
#               OS locations, rc-file PATH marker, CLI smoke-tests
#               (claude / gemini / codex-if-WITH_CODEX), global Claude
#               sub-agents/skills directories. On Mac also checks
#               /Applications/*.app + the Mac-only Claude Desktop config;
#               on Debian those skip with one [SKIP] line each.
#
#   harness   — runs only when the current working dir contains .harness/
#               (i.e. you're sitting inside an agentic-harness project).
#               Checks the project-level Claude Code wiring: sub-agents,
#               skills, slash commands, PostToolUse hook → .harness/verify.sh,
#               and the Co-Authored-By kill-switch (includeCoAuthoredBy:false).
#
# Manual auth steps (claude login, gh auth login, etc.) cannot be verified
# from a script and stay in auth-checklist.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/os.sh
. "$REPO_ROOT/scripts/lib/os.sh"

# Codex install is opt-in via WITH_CODEX (matches install-clis.sh's gate).
# Default off — when off, the codex PATH + version checks are SKIPped, not
# WARNed, since the user never asked for codex to be installed.
WITH_CODEX="${WITH_CODEX:-0}"

PASS=0
WARN=0

ok()   { printf '    [ OK ] %s\n' "$*"; PASS=$((PASS + 1)); }
warn() { printf '    [WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
skip() { printf '    [SKIP] %s\n' "$*"; }

check_bin() {
  local bin="$1" desc="${2:-$1}"
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$desc on PATH ($(command -v "$bin"))"
  else
    warn "$desc not on PATH ($bin)"
  fi
}

check_app() {
  local app="$1"
  if [[ -d "/Applications/$app" ]]; then
    ok "/Applications/$app present"
  else
    warn "/Applications/$app not installed"
  fi
}

check_json() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    warn "missing: $path"
    return
  fi
  if jq empty "$path" >/dev/null 2>&1; then
    ok "valid JSON: $path"
  else
    warn "invalid JSON: $path"
  fi
}

check_jsonc() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    warn "missing: $path"
    return
  fi
  if sed 's|//.*||' "$path" | jq empty >/dev/null 2>&1; then
    ok "valid JSONC: $path"
  else
    warn "invalid JSONC: $path"
  fi
}

check_symlink_into_repo() {
  local path="$1" expected_suffix="$2"
  if [[ ! -L "$path" ]]; then
    warn "$path is not a symlink (expected -> */$expected_suffix)"
    return
  fi
  local target
  target="$(readlink "$path")"
  if [[ "$target" == *"$expected_suffix" && -f "$target" ]]; then
    ok "symlink: $path -> $target"
  else
    warn "symlink target unexpected: $path -> $target"
  fi
}

check_rc_marker() {
  # Use the same rc_file() helper that link-configs.sh uses for writing,
  # so the check matches the file we actually wrote. ~/.zshrc on Mac and
  # Debian-with-zsh; ~/.bashrc on Debian-with-bash.
  local rc
  rc="$(rc_file)"
  local marker='# dev-machine-setup PATH additions (link-configs.sh)'
  if [[ ! -f "$rc" ]]; then
    warn "$rc missing"
    return
  fi
  if grep -Fq "$marker" "$rc"; then
    ok "$rc has dev-machine-setup PATH marker"
  else
    warn "$rc missing dev-machine-setup PATH marker"
  fi
}

check_cli_version() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    skip "$bin not on PATH; version check skipped"
    return
  fi
  if "$bin" --version >/dev/null 2>&1; then
    ok "$bin --version exits 0"
  else
    warn "$bin --version failed"
  fi
}

check_dir_nonempty() {
  local dir="$1" desc="$2"
  if [[ ! -d "$dir" ]]; then
    warn "$desc dir missing: $dir"
    return
  fi
  local count
  count="$(find "$dir" -maxdepth 1 -mindepth 1 | wc -l | tr -d '[:space:]')"
  if ((count > 0)); then
    ok "$desc: $count entries in $dir"
  else
    warn "$desc dir empty: $dir"
  fi
}

check_co_authored_by() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    skip "no $path; Co-Authored-By kill-switch check skipped"
    return
  fi
  if ! jq empty "$path" >/dev/null 2>&1; then
    warn "$path not valid JSON; cannot inspect includeCoAuthoredBy"
    return
  fi
  # `// empty` would mis-handle the literal boolean false (jq treats it as
  # falsy and falls through), so check key presence with `has(...)` first
  # then read the value separately.
  if ! jq -e 'has("includeCoAuthoredBy")' "$path" >/dev/null 2>&1; then
    warn "includeCoAuthoredBy not set in $path (default lets Claude trailer through)"
    return
  fi
  local val
  val="$(jq -r '.includeCoAuthoredBy' "$path")"
  if [[ "$val" == "false" ]]; then
    ok "includeCoAuthoredBy:false in $path"
  else
    warn "includeCoAuthoredBy=$val in $path (expected false)"
  fi
}

# --- global tier ------------------------------------------------------------

echo "==> verify-install (global tier — OS=$OS)"

# PATH binaries. The package-manager binary is platform-specific (brew on
# Mac, apt is always present on Debian and uninteresting to check). Codex
# is opt-in — only checked when WITH_CODEX=1.
bins=()
if [[ "$OS" == "macos" ]]; then
  bins+=("brew|Homebrew")
fi
bins+=(
  "node|Node"
  "gh|GitHub CLI"
  "jq|jq"
  "rg|ripgrep"
  "shellcheck|shellcheck"
  "shfmt|shfmt"
  "claude|Claude Code CLI"
  "gemini|Gemini CLI"
)
if [[ "$WITH_CODEX" == "1" ]]; then
  bins+=("codex|Codex CLI")
fi
for entry in "${bins[@]}"; do
  bin="${entry%%|*}"
  desc="${entry##*|}"
  check_bin "$bin" "$desc"
done
if [[ "$WITH_CODEX" != "1" ]]; then
  skip "codex on PATH (set WITH_CODEX=1 to include Codex CLI)"
fi

# GUI apps + Claude Desktop config — Mac-only. CLI-only Debian scope means
# Antigravity / Gemini Desktop / Claude Desktop aren't installed; the
# claude_desktop_config.json path is also never written by link-configs.sh.
if [[ "$OS" == "macos" ]]; then
  check_app "Antigravity.app"
  check_app "Gemini.app"
  check_app "Claude.app"
  check_json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
else
  skip "/Applications/*.app + Claude Desktop config (Linux: CLI-only scope)"
fi

# Captured configs placed by link-configs.sh (cross-platform paths).
check_symlink_into_repo "$HOME/.claude/CLAUDE.md" "configs/claude/CLAUDE.md"
check_json  "$HOME/.claude/settings.json"
check_json  "$HOME/.gemini/settings.json"
check_jsonc "$HOME/.antigravity/argv.json"

# Co-Authored-By kill-switch in global Claude Code settings.
check_co_authored_by "$HOME/.claude/settings.json"

# rc-file PATH marker. Picks ~/.zshrc on Mac and Debian-with-zsh,
# ~/.bashrc on Debian-with-bash — the same file link-configs.sh wrote to.
check_rc_marker

# CLI smoke tests — confirm the binary actually runs, not just lives on PATH.
check_cli_version claude
check_cli_version gemini
if [[ "$WITH_CODEX" == "1" ]]; then
  check_cli_version codex
else
  skip "codex --version (set WITH_CODEX=1 to include Codex CLI)"
fi

# Global Claude Code agents/skills dirs. These are user-discretionary —
# absence is expected when the user hasn't installed any. Report informationally.
if [[ -d "$HOME/.claude/agents" ]]; then
  check_dir_nonempty "$HOME/.claude/agents" "global Claude sub-agents"
else
  skip "no ~/.claude/agents (no global sub-agents installed)"
fi
if [[ -d "$HOME/.claude/skills" ]]; then
  check_dir_nonempty "$HOME/.claude/skills" "global Claude skills"
else
  skip "no ~/.claude/skills (no global skills installed)"
fi

# --- harness tier -----------------------------------------------------------

if [[ -d "$PWD/.harness" ]]; then
  echo ""
  echo "==> verify-install (harness project tier: $PWD)"

  # harness layout
  if [[ -f "$PWD/.harness/PLAN.md" ]]; then
    ok ".harness/PLAN.md present"
  else
    warn "missing .harness/PLAN.md"
  fi
  if [[ -f "$PWD/.harness/progress.md" ]]; then
    ok ".harness/progress.md present"
  else
    warn "missing .harness/progress.md"
  fi
  if [[ -f "$PWD/.harness/features.json" ]]; then
    if jq empty "$PWD/.harness/features.json" >/dev/null 2>&1; then
      ok ".harness/features.json valid JSON"
    else
      warn ".harness/features.json invalid JSON"
    fi
  else
    warn "missing .harness/features.json"
  fi
  if [[ -x "$PWD/.harness/verify.sh" ]]; then
    ok ".harness/verify.sh present and executable"
  elif [[ -f "$PWD/.harness/verify.sh" ]]; then
    warn ".harness/verify.sh exists but is not executable"
  else
    warn "missing .harness/verify.sh"
  fi

  # project-level Claude Code wiring
  if [[ -d "$PWD/.claude/agents" ]]; then
    check_dir_nonempty "$PWD/.claude/agents" "project sub-agents"
  else
    skip "no .claude/agents (project has no local sub-agents)"
  fi
  if [[ -d "$PWD/.claude/skills" ]]; then
    check_dir_nonempty "$PWD/.claude/skills" "project skills"
  else
    skip "no .claude/skills (project has no local skills)"
  fi
  if [[ -d "$PWD/.claude/commands" ]]; then
    check_dir_nonempty "$PWD/.claude/commands" "project slash commands"
  else
    skip "no .claude/commands (project has no slash commands)"
  fi

  # PostToolUse hook references .harness/verify.sh? Stringify the array and
  # substring-match — robust to schema variations across harness versions.
  if [[ -f "$PWD/.claude/settings.json" ]]; then
    if jq empty "$PWD/.claude/settings.json" >/dev/null 2>&1; then
      if jq -e '.hooks.PostToolUse | tostring | test("verify\\.sh")' "$PWD/.claude/settings.json" >/dev/null 2>&1; then
        ok "PostToolUse hook references .harness/verify.sh"
      else
        warn "PostToolUse hook missing or does not reference verify.sh"
      fi
    else
      warn ".claude/settings.json invalid JSON"
    fi
    # Project-level Co-Authored-By kill-switch.
    check_co_authored_by "$PWD/.claude/settings.json"
  else
    skip "no .claude/settings.json (project hook + kill-switch checks skipped)"
  fi
else
  echo ""
  printf '    [SKIP] no .harness/ in %s — harness project tier skipped\n' "$PWD"
fi

# --- summary ----------------------------------------------------------------

echo ""
printf '==> verify-install summary: %d ok, %d warn\n' "$PASS" "$WARN"
echo "    Warn-only — setup continues regardless. Review WARN lines above."
exit 0
