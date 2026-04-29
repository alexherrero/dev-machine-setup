#!/usr/bin/env bash
# link-configs.sh — place captured configs at their real OS locations.
#
# Cross-platform. Mac places the full set; Debian skips the Mac-only
# Claude Desktop config path (Claude Desktop isn't installed on Linux
# in our CLI-only scope) and routes the shell-fragment append to either
# ~/.zshrc or ~/.bashrc per $SHELL.
#
# Strategy per-file, based on who writes the file in steady state:
#
#   symlink              : user-authored, tools don't rewrite.
#                          Edits on either side sync.
#     - ~/.claude/CLAUDE.md
#
#   copy-if-absent       : app-owned JSON — the owning tool rewrites in
#                          place (reorders keys, mutates permissions arrays,
#                          inserts auto-channel keys, etc.). Symlinking would
#                          cause constant repo churn. Fresh-machine seed only;
#                          drift is managed by re-running scripts/capture.sh.
#     - ~/.claude/settings.json               (Claude Code rewrites regularly)
#     - ~/Library/.../claude_desktop_config.json (Mac only — Claude Desktop)
#     - ~/.gemini/settings.json               (Gemini CLI writes back preferences)
#     - ~/.antigravity/argv.json              (Electron/VS Code derivative;
#                                              seeded on both platforms in
#                                              case Antigravity-CLI parity
#                                              lands later)
#
#   append-idempotent    : shell fragment, not a file replacement.
#                          Guarded by a marker comment; each PATH line is
#                          only appended if not already present verbatim.
#                          Target rc file picked from $OS + $SHELL via
#                          scripts/lib/os.sh::rc_file().
#     - configs/zsh/.zshrc-additions → appended to ~/.zshrc or ~/.bashrc
#
#   git-config merge     : use `git config --global` so existing includes,
#                          credential helpers, and signing config survive.
#     - configs/git/.gitconfig → ~/.gitconfig (user.name, user.email)
#
# Any pre-existing non-matching file at a destination is moved to
# ~/.dev-machine-setup-backup/<utc-timestamp>/ before being replaced.
# Backup dir is lazy-created so a fully-idempotent re-run leaves no trace.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/os.sh
. "$REPO_ROOT/scripts/lib/os.sh"
BACKUP_ROOT="$HOME/.dev-machine-setup-backup"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
BACKED_UP=0

# --- helpers ----------------------------------------------------------------

backup_if_needed() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  # Already the correct symlink into our repo? No backup needed.
  if [[ -L "$path" ]]; then
    local target; target="$(readlink "$path")"
    [[ "$target" == "$REPO_ROOT/"* ]] && return 0
  fi
  if ((BACKED_UP == 0)); then
    mkdir -p "$BACKUP_DIR"
    BACKED_UP=1
  fi
  # Preserve a legible path under the backup dir. $HOME-relative when we can,
  # otherwise flatten the absolute path.
  local rel
  if [[ "$path" == "$HOME/"* ]]; then
    rel="${path#"$HOME"/}"
  else
    rel="${path#/}"
  fi
  local bdest="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$bdest")"
  mv "$path" "$bdest"
  printf '    backed up: %s -> %s\n' "$path" "$bdest"
}

link_symlink() {
  local src_rel="$1" dest="$2"
  local src="$REPO_ROOT/$src_rel"
  [[ -f "$src" ]] || { echo "    FAIL: missing source $src" >&2; return 1; }
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    printf '    symlink   %-55s (already correct)\n' "$dest"
    return 0
  fi
  backup_if_needed "$dest"
  ln -s "$src" "$dest"
  printf '    symlink   %-55s -> %s\n' "$dest" "$src"
}

link_copy_if_absent() {
  local src_rel="$1" dest="$2"
  local src="$REPO_ROOT/$src_rel"
  [[ -f "$src" ]] || { echo "    FAIL: missing source $src" >&2; return 1; }
  if [[ -e "$dest" ]]; then
    printf '    preserve  %-55s (exists; managed by owning tool)\n' "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  printf '    seeded    %-55s (copy of %s)\n' "$dest" "$src_rel"
}

append_shell_additions() {
  local src="$REPO_ROOT/configs/zsh/.zshrc-additions"
  local dest
  dest="$(rc_file)"
  local marker='# dev-machine-setup PATH additions (link-configs.sh)'
  [[ -f "$src" ]] || return 0
  touch "$dest"
  if grep -Fq "$marker" "$dest"; then
    printf '    append    %-55s (marker present)\n' "$dest"
    return 0
  fi
  # Snapshot dest before appending so the "already present?" check reads a
  # stable file and the shell can't be confused about read+write ordering.
  local existing
  existing="$(cat "$dest")"
  local appended=0
  local new_block="" line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! printf '%s\n' "$existing" | grep -Fq -- "$line"; then
      new_block+="$line"$'\n'
      appended=1
    fi
  done < "$src"
  {
    echo ""
    echo "$marker"
    [[ -n "$new_block" ]] && printf '%s' "$new_block"
  } >> "$dest"
  if ((appended == 1)); then
    printf '    append    %-55s (marker + new PATH lines)\n' "$dest"
  else
    printf '    append    %-55s (marker only; all PATH lines already present)\n' "$dest"
  fi
}

merge_gitconfig() {
  local src="$REPO_ROOT/configs/git/.gitconfig"
  [[ -f "$src" ]] || return 0
  local name email
  name="$(git config --file "$src" user.name 2>/dev/null || true)"
  email="$(git config --file "$src" user.email 2>/dev/null || true)"
  if [[ -z "$name" || -z "$email" ]]; then
    echo "    gitconfig: no user.name/email in $src — skipping"
    return 0
  fi
  local live_name live_email
  live_name="$(git config --global user.name 2>/dev/null || true)"
  live_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ "$name" == "$live_name" && "$email" == "$live_email" ]]; then
    printf '    gitconfig %-55s (user.name/email already match)\n' "$HOME/.gitconfig"
    return 0
  fi
  git config --global user.name "$name"
  git config --global user.email "$email"
  printf '    gitconfig %-55s (set user.name=%s, user.email=%s)\n' "$HOME/.gitconfig" "$name" "$email"
}

# Ensure the Co-Authored-By kill-switch is set in ~/.claude/settings.json
# even when link_copy_if_absent preserved an existing file. Claude Code
# (or its first-run init via `claude --version`) creates a default
# settings.json before link-configs runs on a fresh machine, so the
# copy-if-absent strategy alone doesn't get our captured kill-switch in.
# This step merges `includeCoAuthoredBy: false` into whatever is on disk.
# Idempotent: if the value is already false, no write.
ensure_claude_co_authored_by_disabled() {
  local f="$HOME/.claude/settings.json"
  [[ -f "$f" ]] || return 0
  if ! jq empty "$f" >/dev/null 2>&1; then
    echo "    WARN: $f is invalid JSON — skipping kill-switch merge" >&2
    return 0
  fi
  if jq -e 'has("includeCoAuthoredBy") and .includeCoAuthoredBy == false' "$f" >/dev/null 2>&1; then
    printf '    co-author %-55s (kill-switch already set)\n' "$f"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  jq '.includeCoAuthoredBy = false' "$f" > "$tmp" && mv "$tmp" "$f"
  printf '    co-author %-55s (merged includeCoAuthoredBy=false)\n' "$f"
}

# --- main -------------------------------------------------------------------

echo "==> linking configs"

link_symlink       configs/claude/CLAUDE.md                       "$HOME/.claude/CLAUDE.md"
link_copy_if_absent configs/claude/settings.json                  "$HOME/.claude/settings.json"
# Claude Desktop is Mac-only in our scope (no GUI apps on Linux).
if [[ "$OS" == "macos" ]]; then
  link_copy_if_absent configs/claude-desktop/claude_desktop_config.json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
else
  printf '    skip      %-55s (Mac-only — Claude Desktop)\n' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
fi
link_copy_if_absent configs/gemini/settings.json                  "$HOME/.gemini/settings.json"
link_copy_if_absent configs/antigravity/argv.json                 "$HOME/.antigravity/argv.json"
append_shell_additions
merge_gitconfig
ensure_claude_co_authored_by_disabled

# --- post-check -------------------------------------------------------------

echo "==> verifying"
# Strict JSON files. The Claude Desktop path only enters the validation
# loop on Mac — on Linux the path was never written, so a stale check
# would just skip via the `-e` guard anyway, but excluding it keeps
# the post-check output honest about what we placed.
strict_jsons=(
  "$HOME/.claude/settings.json"
  "$HOME/.gemini/settings.json"
)
if [[ "$OS" == "macos" ]]; then
  strict_jsons+=("$HOME/Library/Application Support/Claude/claude_desktop_config.json")
fi
for json in "${strict_jsons[@]}"; do
  if [[ -e "$json" ]]; then
    if jq empty "$json" >/dev/null 2>&1; then
      printf '    jq-ok     %s\n' "$json"
    else
      echo "    FAIL: invalid JSON at $json" >&2
      exit 1
    fi
  fi
done
# argv.json is JSONC (Electron / VS Code convention). Strip // line comments
# before validating, matching what scripts/capture.sh does on the way in.
argv="$HOME/.antigravity/argv.json"
if [[ -e "$argv" ]]; then
  if sed 's|//.*||' "$argv" | jq empty >/dev/null 2>&1; then
    printf '    jq-ok     %s (jsonc)\n' "$argv"
  else
    echo "    FAIL: invalid JSONC at $argv" >&2
    exit 1
  fi
fi

if [[ -L "$HOME/.claude/CLAUDE.md" ]]; then
  printf '    readlink  ~/.claude/CLAUDE.md -> %s\n' "$(readlink "$HOME/.claude/CLAUDE.md")"
fi

if ((BACKED_UP == 1)); then
  echo "    backups:  $BACKUP_DIR"
fi

echo "==> link-configs stage complete"
