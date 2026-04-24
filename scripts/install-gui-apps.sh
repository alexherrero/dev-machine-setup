#!/usr/bin/env bash
# install-gui-apps.sh — browser-assisted installer for the GUI apps this repo
# expects. None of the three vendors publishes a direct-download URL that
# survives curl (Claude's DMG redirect is behind a Cloudflare JS challenge;
# Antigravity + Gemini Desktop have no discoverable direct URL at all). So
# this script opens each vendor's download page in the default browser and
# waits for the user to drag the .app into /Applications, then strips the
# Gatekeeper quarantine xattr so first launch doesn't require right-click.
#
# Skip-if-exists per app: if /Applications/<App>.app already exists, no
# browser page is opened and no user interaction is needed. That's the
# idempotent path on an already-configured machine and the path exercised
# in verification on this dev Mac (all three apps are already installed).
#
# Non-interactive contexts (CI, --skip-apps) should bypass this stage
# entirely via setup.sh flags — this script itself requires a TTY.

set -euo pipefail

# --- URL table (edit here when vendors move their download pages) -----------
#
# Parallel arrays keep bash 3.2 compatibility (no associative arrays on the
# system bash shipped with macOS). Indexes line up across all three.

APPS=(Antigravity Gemini Claude)
APP_BUNDLES=(Antigravity.app Gemini.app Claude.app)
APP_URLS=(
  "https://antigravity.google"
  "https://gemini.google.com/app"
  "https://claude.com/download"
)

# --- helpers ----------------------------------------------------------------

strip_quarantine() {
  local app_path="$1"
  # -r recurses into the bundle; -c clears all xattrs (quarantine is the one
  # that matters but other leftover xattrs from DMG copy are safe to drop).
  # Hide "No such xattr" noise — absence is the desired state.
  xattr -rc "$app_path" 2>/dev/null || true
}

require_tty() {
  if [[ ! -t 0 ]]; then
    echo "==> FAIL: install-gui-apps.sh needs an interactive terminal." >&2
    echo "    In CI or headless runs, invoke setup.sh with --skip-apps." >&2
    exit 1
  fi
}

# --- per-app flow -----------------------------------------------------------

install_one() {
  local name="$1" bundle="$2" url="$3"
  local dest="/Applications/$bundle"

  if [[ -d "$dest" ]]; then
    printf '    %-14s already at %s\n' "$name" "$dest"
    strip_quarantine "$dest"
    return 0
  fi

  require_tty
  echo ""
  echo "--- $name ---------------------------------------------------------"
  echo "    $name.app not found in /Applications."
  echo "    Opening the download page in your browser:"
  echo "      $url"
  open "$url" >/dev/null 2>&1 || true
  echo ""
  echo "    Download the DMG, then drag $bundle into /Applications."
  echo "    (Eject the DMG when done.)"
  echo ""

  # Poll for the bundle — lets the user take as long as they need without
  # losing their place in the script. Ctrl-C aborts the whole stage.
  while [[ ! -d "$dest" ]]; do
    read -r -p "    Press Enter once $bundle is in /Applications (or Ctrl-C to abort)... " _
    if [[ ! -d "$dest" ]]; then
      echo "    Still not seeing $dest — try again."
    fi
  done

  strip_quarantine "$dest"
  echo "    OK: $name installed and dequarantined."
}

# --- main -------------------------------------------------------------------

echo "==> GUI apps"

for i in "${!APPS[@]}"; do
  install_one "${APPS[$i]}" "${APP_BUNDLES[$i]}" "${APP_URLS[$i]}"
done

# --- post-check -------------------------------------------------------------

echo ""
echo "==> verifying"
missing=()
for bundle in "${APP_BUNDLES[@]}"; do
  dest="/Applications/$bundle"
  if [[ -d "$dest" ]]; then
    printf '    %-20s present\n' "$bundle"
  else
    printf '    %-20s MISSING\n' "$bundle"
    missing+=("$bundle")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "==> FAIL: GUI apps missing: ${missing[*]}" >&2
  exit 1
fi

echo "==> gui-apps stage complete"
