#!/usr/bin/env pwsh
# scripts/install-tooling.ps1 — Windows toolchain installer via winget.
#
# Mirror of scripts/install-brew.sh (Mac) and scripts/install-apt.sh (Debian).
# Installs the four winget-managed dev tools we depend on:
#   - Git.Git                  (required by Claude Code — shells out to Git Bash)
#   - OpenJS.NodeJS.LTS        (Gemini CLI requires Node >= 20; LTS is currently 22)
#   - GitHub.cli               (gh; auth, PRs, releases)
#   - BurntSushi.ripgrep.MSVC  (rg)
#
# We deliberately skip:
#   - jq          — PowerShell has native ConvertFrom-Json / ConvertTo-Json
#   - shellcheck  — no bash scripts on Windows
#   - shfmt       — same
#
# Idempotent: re-running is a no-op (winget exits cleanly when already
# installed). After installs, refresh the current session's PATH from the
# registry so subsequent setup.ps1 stages see the new tools without the
# user opening a fresh shell.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Pre-flight: winget is required. Ships with App Installer on Windows 10
# 1809+ and Windows 11. Older Windows or stripped images may need a manual
# upgrade.
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "==> winget not found"
  Write-Error @"
winget is required but not found. It ships with the App Installer in
Windows 10 1809+ and Windows 11. If missing, install or upgrade from
the Microsoft Store:
  https://apps.microsoft.com/detail/9NBLGGH4NNS1
"@
  exit 2
}

Write-Host "==> winget toolchain"

# winget id => binary expected on PATH afterward (for the post-check).
# Order matters: Git first since Claude Code at the next stage shells out to
# Git Bash; Node before any later npm-using stage; gh + rg are independent.
$Packages = @(
  [pscustomobject]@{ Id = 'Git.Git';                  Bin = 'git' }
  [pscustomobject]@{ Id = 'OpenJS.NodeJS.LTS';        Bin = 'node' }
  [pscustomobject]@{ Id = 'GitHub.cli';               Bin = 'gh'  }
  [pscustomobject]@{ Id = 'BurntSushi.ripgrep.MSVC';  Bin = 'rg'  }
)

foreach ($p in $Packages) {
  $existing = Get-Command $p.Bin -ErrorAction SilentlyContinue
  if ($existing) {
    '    {0,-30} already on PATH ({1})' -f $p.Id, $existing.Source | Write-Host
    continue
  }
  '    {0,-30} installing...' -f $p.Id | Write-Host
  & winget install --exact `
                   --id $p.Id `
                   --accept-package-agreements `
                   --accept-source-agreements `
                   --silent
  # winget exit codes are noisy: 0 = success, 0x8A15002B = already-installed
  # in older versions, various others for "no upgrade available" etc. We
  # surface non-zero as a warning rather than a hard fail; the post-check
  # below is the real gate (binary on PATH or not).
  if ($LASTEXITCODE -ne 0) {
    Write-Warning ("winget install {0} exited {1} (post-check below decides if this is a problem)" -f $p.Id, $LASTEXITCODE)
  }
}

# Refresh PATH from the registry into this session. winget writes to either
# Machine or User scope depending on the package; we union both so subsequent
# stages see everything. Mirrors the post-install shell-rc reload pattern on
# Mac/Linux.
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path    = "$machinePath;$userPath"

# --- post-check -------------------------------------------------------------

Write-Host "==> verifying binaries on PATH"
$expected = @('git', 'node', 'npm', 'gh', 'rg')
$missing = @()
foreach ($bin in $expected) {
  $cmd = Get-Command $bin -ErrorAction SilentlyContinue
  if ($cmd) {
    '    {0,-12} -> {1}' -f $bin, $cmd.Source | Write-Host
  }
  else {
    '    {0,-12} MISSING' -f $bin | Write-Host
    $missing += $bin
  }
}

if ($missing.Count -gt 0) {
  Write-Error ("FAIL: installed but not on PATH: {0}" -f ($missing -join ', '))
  Write-Error "Open a fresh PowerShell session (winget user-PATH writes may not propagate to the running shell) and re-run."
  exit 1
}

Write-Host "==> tooling stage complete"
