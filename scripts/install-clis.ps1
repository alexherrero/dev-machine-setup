#!/usr/bin/env pwsh
# scripts/install-clis.ps1 — Windows CLI agent installer.
#
# Mirror of scripts/install-clis.sh, with Windows-native install paths:
#   - Claude Code  : winget install Anthropic.ClaudeCode (system-managed,
#                    user runs `winget upgrade` periodically). The native
#                    `irm https://claude.ai/install.ps1 | iex` alternative
#                    is documented in docs/windows.md for users who prefer
#                    auto-updating installs; the script does not install
#                    both — claude-code#31980 documents the dedupe footgun.
#   - Gemini CLI   : npm install -g @google/gemini-cli (Node >= 20 from
#                    install-tooling.ps1's OpenJS.NodeJS.LTS).
#   - Codex CLI    : OPT-IN via $env:WITH_CODEX = '1'. On Windows, even
#                    when opted in, this script SKIPS WITH WARN — the
#                    @openai/codex npm package is currently broken on
#                    Windows (issues #18648, #11744 — the win32-x64
#                    optionalDependency isn't published as expected, npm
#                    resolves stale binary). Mac and Linux install Codex
#                    normally. Revisit when OpenAI fixes the npm package.
#
# Idempotent. Hard-fails if Node < 20 (Gemini requires it). Ensures
# %APPDATA%\npm is on user PATH before npm install -g (the OpenJS Node
# installer adds Node itself to Machine PATH but doesn't add the npm-
# globals prefix).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Same opt-in env-var pattern as setup.sh / install-clis.sh on Mac / Linux.
$WithCodex = $env:WITH_CODEX -eq '1'

# --- helpers ----------------------------------------------------------------

function Update-PathFromRegistry {
  # Read both PATH scopes from the registry and join into the running shell
  # so subsequent commands see whatever winget / Node / npm just wrote.
  # `Update` (vs `Refresh`) is the approved-verb spelling per PowerShell
  # conventions; behaviorally identical to a registry-PATH refresh.
  $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path    = "$machinePath;$userPath"
}

function Add-DirToUserPath {
  # Idempotently append a directory to the persistent User PATH (registry).
  # Subsequent fresh shells inherit it; we also splice it into $env:Path
  # for the running session.
  param([Parameter(Mandatory)] [string] $Dir)
  $current = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $entries = if ($current) { $current -split ';' } else { @() }
  if ($entries -contains $Dir) {
    '    {0,-30} already in user PATH' -f $Dir | Write-Host
    return
  }
  $new = if ($current) { "$current;$Dir" } else { $Dir }
  [System.Environment]::SetEnvironmentVariable('Path', $new, 'User')
  '    {0,-30} appended to user PATH' -f $Dir | Write-Host
  $env:Path = "$env:Path;$Dir"
}

function Test-NodeVersion {
  # Hard-fail if Node < 20 (Gemini CLI requires it). install-tooling.ps1
  # installs OpenJS.NodeJS.LTS which is currently 22, so this guard is
  # defensive — fires only if someone manually installed an older Node.
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Error "node not found on PATH. Run scripts/install-tooling.ps1 first."
    exit 1
  }
  $version = & node --version 2>$null
  $major = [int]($version -replace '^v(\d+).*$', '$1')
  if ($major -lt 20) {
    Write-Error "Node $version is too old. Gemini CLI requires >= 20."
    Write-Error "Run scripts/install-tooling.ps1 to install OpenJS.NodeJS.LTS (currently 22)."
    exit 1
  }
}

# --- 1. Claude Code (winget) -----------------------------------------------

Write-Host "==> Claude Code CLI (winget)"
$existingClaude = Get-Command claude -ErrorAction SilentlyContinue
if ($existingClaude) {
  $current = & claude --version 2>&1 | Select-Object -First 1
  "    currently: $current ($($existingClaude.Source))" | Write-Host
}
& winget install --exact `
                 --id Anthropic.ClaudeCode `
                 --accept-package-agreements `
                 --accept-source-agreements `
                 --silent
if ($LASTEXITCODE -ne 0) {
  # winget exit codes are noisy: 0 = success, various others for benign
  # already-installed-or-up-to-date states. Surface as warning; the
  # post-check is the actual gate.
  Write-Warning ("winget install Anthropic.ClaudeCode exited {0}" -f $LASTEXITCODE)
}
Update-PathFromRegistry

# --- 2. Node version guard + npm prefix on PATH ----------------------------

Write-Host "==> npm prerequisites"
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error "npm not found on PATH. Run scripts/install-tooling.ps1 first."
  exit 1
}
Test-NodeVersion
# Ensure the npm-globals dir is on persistent user PATH so `gemini` (and
# any future npm-installed CLI) resolves in fresh shells.
$npmPrefix = Join-Path $env:APPDATA 'npm'
Add-DirToUserPath -Dir $npmPrefix

# --- 3. Gemini CLI (npm global) --------------------------------------------

Write-Host "==> Gemini CLI (@google/gemini-cli)"
$existingGemini = Get-Command gemini -ErrorAction SilentlyContinue
if ($existingGemini) {
  $current = & gemini --version 2>&1 | Select-Object -First 1
  "    currently: $current" | Write-Host
}
& npm install -g '@google/gemini-cli'
if ($LASTEXITCODE -ne 0) {
  Write-Error ("npm install -g @google/gemini-cli failed (exit {0})" -f $LASTEXITCODE)
  exit 1
}
Update-PathFromRegistry

# --- 4. Codex CLI (skip-with-warn on Windows) ------------------------------

if ($WithCodex) {
  Write-Host "==> Codex CLI: requested via --with-codex but skipped"
  Write-Host "    Codex's npm package is currently broken on Windows"
  Write-Host "    (openai/codex#18648, #11744 — win32-x64 optionalDependency"
  Write-Host "    not published as expected; npm resolves stale binary)."
  Write-Host "    Mac and Linux install Codex normally. Revisit when fixed."
}
else {
  Write-Host "==> Codex CLI: skipped (pass --with-codex to setup.ps1 to include)"
}

# --- 5. Post-check ----------------------------------------------------------

Write-Host "==> verifying"
# Codex is intentionally not in this list on Windows — see the skip block
# above. The expected set is just claude + gemini regardless of WITH_CODEX.
$expected = @('claude', 'gemini')
$missing = @()
foreach ($bin in $expected) {
  $cmd = Get-Command $bin -ErrorAction SilentlyContinue
  if ($cmd) {
    $version = & $bin --version 2>&1 | Select-Object -First 1
    '    {0,-8} {1,-50} {2}' -f $bin, $cmd.Source, $version | Write-Host
  }
  else {
    '    {0,-8} MISSING' -f $bin | Write-Host
    $missing += $bin
  }
}

if ($missing.Count -gt 0) {
  Write-Error ("FAIL: CLIs not on PATH: {0}" -f ($missing -join ', '))
  Write-Error "Open a fresh PowerShell session (winget user-PATH writes may not propagate to the running shell) and re-run."
  exit 1
}

Write-Host "==> clis stage complete"
