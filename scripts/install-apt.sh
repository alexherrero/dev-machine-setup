#!/usr/bin/env bash
# install-apt.sh — Debian/Ubuntu equivalent of install-brew.sh.
#
# Adds two third-party apt repos with explicit keyring files (NodeSource
# for Node.js 22 LTS — Debian's default `nodejs` is too old for Gemini
# CLI; GitHub CLI's official repo for `gh`), then apt-installs the same
# six packages the Mac path gets via brew: node (`nodejs`), gh, jq,
# ripgrep, shellcheck, shfmt.
#
# `shfmt` is in apt on Debian 12+ / Ubuntu 24.04+ but missing on older
# releases. We probe `apt-cache show shfmt` and fall back to fetching
# the GitHub release binary into /usr/local/bin/shfmt if absent.
#
# Idempotent: re-running is a no-op (apt skips installed packages,
# keyring/sources.list writes are guarded). Requires sudo for /etc/apt/
# writes and apt install. URLs and package list are pinned at the top
# of the file for one-line updates.
#
# Mirrors install-brew.sh's contract: prints `==> <name>` banners, ends
# with a post-check that confirms every expected binary resolves on PATH.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/os.sh
. "$REPO_ROOT/scripts/lib/os.sh"

# Defensive guard: this script writes to /etc/apt and assumes apt/dpkg.
# Anyone who runs it directly on a non-Debian host hits this before any
# sudo prompt or apt invocation.
if [[ "$OS" != "debian" ]]; then
  echo "error: install-apt.sh requires a Debian/Ubuntu host (OS=$OS)" >&2
  exit 2
fi

# --- pinned URLs / package list ---------------------------------------------

# NodeSource. `nodistro` decouples the package from the host's distro codename
# (works on Debian 11/12/13, Ubuntu 20.04/22.04/24.04+). Bump to node_24.x for
# current; 22 is LTS through 2027.
readonly NODESOURCE_KEY_URL='https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key'
readonly NODESOURCE_REPO_LINE='deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main'

# GitHub CLI's official repo. `arch=` resolves at runtime so the same line
# works on amd64 and arm64 hosts.
readonly GH_KEY_URL='https://cli.github.com/packages/githubcli-archive-keyring.gpg'

# apt-installed packages (note: the apt package for Node is `nodejs`, which
# bundles `npm`). `shfmt` may be missing on older releases — handled below.
readonly APT_PACKAGES=(nodejs gh jq ripgrep shellcheck)

# Expected binaries on PATH after a successful run. `node` and `npm` from
# nodejs; `rg` from ripgrep; the rest match their package names.
readonly EXPECTED_BINS=(node npm gh jq rg shellcheck shfmt)

# --- helpers ----------------------------------------------------------------

# `sudo` is required throughout; surface a clear error up front rather than
# letting the first apt call die mid-run.
require_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=''
    return
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    echo "error: sudo not found and not running as root" >&2
    exit 1
  fi
  SUDO='sudo'
}

ensure_keyrings_dir() {
  $SUDO install -d -m 0755 /etc/apt/keyrings
}

# Idempotently install a GPG keyring. Skips re-download if the file already
# exists; the apt-repo verification chain catches any tampering anyway.
install_keyring() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    printf '    %-30s already present\n' "$(basename "$dest")"
    return 0
  fi
  printf '    %-30s downloading\n' "$(basename "$dest")"
  curl -fsSL "$url" | $SUDO tee "$dest" >/dev/null
  $SUDO chmod 0644 "$dest"
}

# Idempotently write a sources.list.d line. The fixed-string match avoids
# regex churn if the upstream URL ever gains query params.
install_sources_line() {
  local line="$1" dest="$2"
  if [[ -f "$dest" ]] && grep -Fxq "$line" "$dest" 2>/dev/null; then
    printf '    %-30s already configured\n' "$(basename "$dest")"
    return 0
  fi
  printf '    %-30s writing\n' "$(basename "$dest")"
  echo "$line" | $SUDO tee "$dest" >/dev/null
}

# Resolve the GitHub-release shfmt URL via the /releases/latest redirect.
# Avoids depending on jq (which we may be installing in the same run).
shfmt_fallback() {
  local arch tag url
  arch="$(dpkg --print-architecture)"
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    https://github.com/mvdan/sh/releases/latest)"
  tag="${tag##*/}"
  if [[ -z "$tag" || "$tag" == "latest" ]]; then
    echo "    FAIL: could not resolve latest shfmt release tag" >&2
    return 1
  fi
  url="https://github.com/mvdan/sh/releases/download/${tag}/shfmt_${tag}_linux_${arch}"
  echo "    fetching $url"
  $SUDO curl -fsSL -o /usr/local/bin/shfmt "$url"
  $SUDO chmod +x /usr/local/bin/shfmt
  printf '    shfmt %s installed at /usr/local/bin/shfmt\n' "$tag"
}

# --- 1. preflight ------------------------------------------------------------

echo "==> apt prerequisites"
require_sudo
ensure_keyrings_dir

# --- 2. NodeSource (Node.js 22 LTS) -----------------------------------------

echo "==> NodeSource (node 22 LTS)"
install_keyring "$NODESOURCE_KEY_URL" /etc/apt/keyrings/nodesource.gpg
install_sources_line "$NODESOURCE_REPO_LINE" /etc/apt/sources.list.d/nodesource.list

# --- 3. GitHub CLI ----------------------------------------------------------

echo "==> GitHub CLI apt repo"
install_keyring "$GH_KEY_URL" /etc/apt/keyrings/githubcli-archive-keyring.gpg
gh_arch="$(dpkg --print-architecture)"
gh_repo_line="deb [arch=${gh_arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
install_sources_line "$gh_repo_line" /etc/apt/sources.list.d/github-cli.list

# --- 4. apt update + install ------------------------------------------------

echo "==> apt update"
$SUDO apt-get update -y

echo "==> apt install"
# Try to install shfmt from apt; if its package isn't available on this
# distro release, we fall back to the GitHub release binary below.
shfmt_in_apt=0
if apt-cache show shfmt >/dev/null 2>&1; then
  shfmt_in_apt=1
  $SUDO apt-get install -y "${APT_PACKAGES[@]}" shfmt
else
  echo "    shfmt not in apt on this release — installing rest, falling back for shfmt"
  $SUDO apt-get install -y "${APT_PACKAGES[@]}"
fi

# --- 5. shfmt fallback ------------------------------------------------------

if ((shfmt_in_apt == 0)); then
  if command -v shfmt >/dev/null 2>&1; then
    printf '    shfmt already on PATH (%s) — skipping fallback\n' "$(command -v shfmt)"
  else
    echo "==> shfmt (GitHub release fallback)"
    shfmt_fallback
  fi
fi

# --- 6. post-check ----------------------------------------------------------

echo "==> verifying binaries on PATH"
missing=()
for bin in "${EXPECTED_BINS[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    printf '    %-12s -> %s\n' "$bin" "$(command -v "$bin")"
  else
    printf '    %-12s MISSING\n' "$bin"
    missing+=("$bin")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "==> FAIL: installed but not on PATH: ${missing[*]}" >&2
  exit 1
fi

echo "==> apt stage complete"
