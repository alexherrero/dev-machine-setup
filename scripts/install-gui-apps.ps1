#!/usr/bin/env pwsh
# scripts/install-gui-apps.ps1 — Windows GUI app installer via winget.
#
# Mirror of install-gui-apps.sh on Mac, but Windows installs run unattended
# (no browser-assisted DMG dance, no Cloudflare-blocked CDN), so this is
# a thin wrapper around two winget calls.
#
# Apps:
#   - Antigravity Desktop  : winget id `Google.Antigravity`. The exact id
#                            is not yet documented on Google's site;
#                            unconfirmed-id case is handled by skip-with-
#                            warn + manual-URL pointer (verify on first
#                            CI dispatch; if winget can't find it, swap
#                            the id or fall back to the .exe download).
#   - Claude Desktop       : winget id `Anthropic.Claude` (distinct from
#                            `Anthropic.ClaudeCode` which install-clis.ps1
#                            uses for the CLI).
#   - Gemini Desktop       : explicitly skipped — no first-party Windows
#                            app exists. Community Electron wrappers
#                            (bwendell/gemini-desktop, dortanes/gemini-
#                            desktop) are out of scope.
#
# Idempotent: winget on an already-installed package returns either 0
# (success — already-installed) or APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
# (no upgrade available). Both are treated as fine. The actual is-it-installed
# check lives in verify-install.ps1 / task 5.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# winget exit code for "no matching package found" (APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND).
# 0x8A150014 unsigned = -1978335212 signed. PowerShell's $LASTEXITCODE is int32,
# so we compare against the signed form.
$WingetNoApplicationsFound = -1978335212

function Install-WingetApp {
  param(
    [Parameter(Mandatory)] [string] $Id,
    [Parameter(Mandatory)] [string] $DisplayName,
    [string] $ManualUrl
  )
  '==> {0} (winget {1})' -f $DisplayName, $Id | Write-Host
  & winget install --exact `
                   --id $Id `
                   --accept-package-agreements `
                   --accept-source-agreements `
                   --silent
  $exit = $LASTEXITCODE
  if ($exit -eq 0) {
    Write-Host "    ok (winget exit 0)"
    return
  }
  if ($exit -eq $WingetNoApplicationsFound) {
    Write-Warning "winget package '$Id' not found in default sources — skipping"
    if ($ManualUrl) {
      "    install $DisplayName manually from: $ManualUrl" | Write-Host
    }
    return
  }
  # All other non-zero codes are surfaced as warnings. Many are benign
  # (already-installed, no-upgrade-available, etc.); verify-install.ps1
  # is the source of truth for what's actually on disk after this stage.
  Write-Warning ("winget install '{0}' exited {1} (verify-install.ps1 confirms post-install state)" -f $Id, $exit)
}

# --- Pre-flight -------------------------------------------------------------

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget not found. Run scripts/install-tooling.ps1 first."
  exit 1
}

# --- 1. Antigravity Desktop -------------------------------------------------

Install-WingetApp `
  -Id 'Google.Antigravity' `
  -DisplayName 'Antigravity Desktop' `
  -ManualUrl 'https://antigravity.google/'

# --- 2. Claude Desktop ------------------------------------------------------

Install-WingetApp `
  -Id 'Anthropic.Claude' `
  -DisplayName 'Claude Desktop' `
  -ManualUrl 'https://claude.com/download'

# --- 3. Gemini Desktop (skipped — no first-party Windows app) --------------

Write-Host "==> Gemini Desktop: skipped (no first-party Windows app)"

Write-Host "==> gui-apps stage complete"
