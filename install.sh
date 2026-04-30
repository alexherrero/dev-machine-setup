#!/usr/bin/env bash
# install.sh — one-line bootstrap for dev-machine-setup.
#
# Fetches the latest tagged release from GitHub, extracts the source
# tarball to a temp dir, and exec's setup.sh from there with all
# user-supplied args forwarded. No git prereq on the host.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --with-codex
#   curl -fsSL .../install.sh | bash -s -- --skip-apps --dry-run
#
# Trust model: same as Homebrew's install.sh — the trust boundary is
# GitHub's TLS cert + the repo owner's release-signing discipline. Read
# the script before piping it to bash if you don't trust it. The
# `--inspect-before-run` recipe is in docs/install.md.

set -euo pipefail

REPO="alexherrero/dev-machine-setup"
LATEST_URL="https://github.com/${REPO}/releases/latest"

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

# Pick the first available downloader. curl preferred — pre-installed on
# every supported macOS and on most Debian/Ubuntu hosts. wget is the
# fallback for stripped-down container images.
if command -v curl >/dev/null 2>&1; then
  # -fsSI for HEAD-only fetch of headers (used to read the redirect
  # Location). Note: -f makes curl exit non-zero on >=400 but we want
  # to capture the 302 — curl treats redirects as success when not
  # following, so -f is fine here.
  fetch_headers() { curl -fsSI "$1"; }
  fetch_to() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  # wget -S prints headers to stderr; --max-redirect=0 makes it stop
  # at the first 302 instead of following.
  fetch_headers() { wget -S --max-redirect=0 --spider "$1" 2>&1 || true; }
  fetch_to() { wget -qO "$2" "$1"; }
else
  die "neither curl nor wget is on PATH — install one and retry"
fi

# Resolve the latest release tag by reading the Location header of the
# /releases/latest HTML redirect — *not* the JSON API. The API endpoint
# is rate-limited to 60 unauth requests/hr per IP and CI runners on
# shared NATs hit it routinely (HTTP 403). The HTML redirect has no
# such limit and is the same pattern we use for the shfmt fallback in
# install-apt.sh and the Anthropic docs use for claude.ai/install.sh.
#
#   HEAD https://github.com/<owner>/<repo>/releases/latest
#     → 302 Location: .../releases/tag/vX.Y.Z
#
# The trailing slash on `releases/tag/` is the only stable separator;
# strip everything up to and including it, then take the first token.
echo "==> Resolving latest release tag from ${LATEST_URL}"
TAG="$(
  fetch_headers "$LATEST_URL" \
    | tr -d '\r' \
    | grep -i '^location:' \
    | sed -E 's|.*/releases/tag/||' \
    | head -1 \
    | tr -d '[:space:]'
)"
[[ -n "${TAG}" ]] || die "could not parse tag from /releases/latest redirect"
echo "==> Latest release: ${TAG}"

# GitHub strips the leading 'v' from tag in the tarball directory name:
# tag v3.0.0 expands to 'dev-machine-setup-3.0.0/' inside the archive.
VERSION="${TAG#v}"
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"

# Stage everything under a fresh tempdir. macOS and Linux both honor
# TMPDIR; mktemp -d gives us a per-invocation scratch space. We don't
# auto-clean — leaving the dir lets users re-run setup.sh without
# re-downloading, and the OS will reap it on next reboot.
WORK_DIR="$(mktemp -d -t dev-machine-setup.XXXXXX)"
TARBALL="${WORK_DIR}/${TAG}.tar.gz"

echo "==> Downloading ${TARBALL_URL}"
fetch_to "$TARBALL_URL" "$TARBALL"

echo "==> Extracting to ${WORK_DIR}"
tar -xzf "$TARBALL" -C "$WORK_DIR"

EXTRACTED="${WORK_DIR}/dev-machine-setup-${VERSION}"
[[ -d "${EXTRACTED}" ]] || die "expected extract dir not found: ${EXTRACTED}"
[[ -x "${EXTRACTED}/setup.sh" ]] || die "setup.sh not found or not executable in ${EXTRACTED}"

echo "==> Running ${EXTRACTED}/setup.sh $*"
echo "    (extract dir kept at ${WORK_DIR} — re-run setup.sh from there to skip the download)"
echo

cd "${EXTRACTED}"
exec ./setup.sh "$@"
