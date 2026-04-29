#!/usr/bin/env pwsh
# scripts/verify-install.ps1 — Windows post-setup health check.
#
# Mirror of scripts/verify-install.sh. Warn-only by design: prints
# OK / WARN / SKIP per check and exits 0 regardless. Two tiers:
#
#   global   : tools on PATH, captured configs at OS locations, GUI apps
#              installed (Mac-scope on Windows; gated on $env:SKIP_APPS),
#              CLI smoke tests. Codex on Windows is skip-only (install-
#              clis.ps1 doesn't install it; the message differentiates
#              WITH_CODEX-opted-in vs default).
#
#   harness  : runs only when CWD has .harness\. Project-level Claude
#              Code wiring + harness state.
#
# Manual auth steps (claude login, gh auth login, etc.) cannot be
# verified from a script and stay in auth-checklist.ps1.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$script:Pass = 0
$script:Warn = 0

$WithCodex = $env:WITH_CODEX -eq '1'
$SkipApps  = $env:SKIP_APPS  -eq '1'

# --- helpers ----------------------------------------------------------------

function Write-Ok {
  param([Parameter(Mandatory)] [string] $Msg)
  '    [ OK ] {0}' -f $Msg | Write-Host
  $script:Pass = $script:Pass + 1
}

function Write-Warn {
  param([Parameter(Mandatory)] [string] $Msg)
  '    [WARN] {0}' -f $Msg | Write-Host
  $script:Warn = $script:Warn + 1
}

function Write-Skip {
  param([Parameter(Mandatory)] [string] $Msg)
  '    [SKIP] {0}' -f $Msg | Write-Host
}

function Test-BinOnPath {
  param([Parameter(Mandatory)] [string] $Bin, [string] $Desc)
  if (-not $Desc) { $Desc = $Bin }
  $cmd = Get-Command $Bin -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Ok ("{0} on PATH ({1})" -f $Desc, $cmd.Source)
  }
  else {
    Write-Warn ("{0} not on PATH ({1})" -f $Desc, $Bin)
  }
}

function Test-JsonFile {
  param([Parameter(Mandatory)] [string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Warn "missing: $Path"
    return
  }
  try {
    [void](Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
    Write-Ok "valid JSON: $Path"
  }
  catch {
    Write-Warn "invalid JSON: $Path"
  }
}

function Test-JsoncFile {
  # JSONC: strip line comments before parsing. Mirrors `sed 's|//.*||'` in
  # the bash version.
  param([Parameter(Mandatory)] [string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Warn "missing: $Path"
    return
  }
  try {
    $stripped = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) -replace '(?m)//.*$', ''
    [void]($stripped | ConvertFrom-Json -ErrorAction Stop)
    Write-Ok "valid JSONC: $Path"
  }
  catch {
    Write-Warn "invalid JSONC: $Path"
  }
}

function Test-WindowsApp {
  # Search the standard Windows uninstall registry keys (machine + user)
  # for an app whose DisplayName matches $DisplayPattern. Mirror of the
  # Mac `[ -d /Applications/X.app ]` check.
  #
  # Limitation: MSIX-installed apps (like Claude Desktop's modern install)
  # may register under HKCU\...\Packages\... rather than the Uninstall key.
  # The pattern catches both shapes when DisplayName is set.
  param(
    [Parameter(Mandatory)] [string] $DisplayPattern,
    [Parameter(Mandatory)] [string] $FriendlyName
  )
  $keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  )
  $found = $false
  foreach ($key in $keys) {
    if (-not (Test-Path -LiteralPath $key)) { continue }
    $match = Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue | ForEach-Object {
      (Get-ItemProperty -LiteralPath $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
    } | Where-Object { $_ -and $_ -like $DisplayPattern } | Select-Object -First 1
    if ($match) { $found = $true; break }
  }
  if ($found) {
    Write-Ok "$FriendlyName installed (registry: $DisplayPattern)"
  }
  else {
    Write-Warn "$FriendlyName not found in Uninstall registry (may be MSIX-only — see PLAN.md follow-on)"
  }
}

function Test-RepoSymlinkOrCopy {
  # Mirror of check_symlink_into_repo. Windows allows two acceptable
  # outcomes: a SymbolicLink (preferred) or a Copy fallback (when admin /
  # Dev Mode is off). Both are reported as OK with the variant in the line.
  param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [string] $ExpectedSuffix
  )
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Warn "$Path missing"
    return
  }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType -eq 'SymbolicLink') {
    if ($item.Target -and ($item.Target -like "*$ExpectedSuffix") -and (Test-Path -LiteralPath $item.Target)) {
      Write-Ok "symlink: $Path -> $($item.Target)"
    }
    else {
      Write-Warn "symlink target unexpected: $Path -> $($item.Target)"
    }
  }
  else {
    # Copy fallback. Acceptable on Windows when Dev Mode is off.
    Write-Ok "copy (no symlink — Dev Mode off?): $Path"
  }
}

function Test-CoAuthoredBy {
  param([Parameter(Mandatory)] [string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Skip "no $Path; Co-Authored-By kill-switch check skipped"
    return
  }
  try {
    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    Write-Warn "$Path not valid JSON; cannot inspect includeCoAuthoredBy"
    return
  }
  if ($json.PSObject.Properties.Name -notcontains 'includeCoAuthoredBy') {
    Write-Warn "includeCoAuthoredBy not set in $Path (default lets Claude trailer through)"
    return
  }
  if ($json.includeCoAuthoredBy -eq $false) {
    Write-Ok "includeCoAuthoredBy:false in $Path"
  }
  else {
    Write-Warn "includeCoAuthoredBy=$($json.includeCoAuthoredBy) in $Path (expected false)"
  }
}

function Test-CliVersion {
  param([Parameter(Mandatory)] [string] $Bin)
  $cmd = Get-Command $Bin -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Skip "$Bin not on PATH; version check skipped"
    return
  }
  try {
    [void](& $Bin --version 2>&1)
    if ($LASTEXITCODE -eq 0) {
      Write-Ok "$Bin --version exits 0"
    }
    else {
      Write-Warn "$Bin --version failed (exit $LASTEXITCODE)"
    }
  }
  catch {
    Write-Warn "$Bin --version failed: $_"
  }
}

function Test-DirNonEmpty {
  param(
    [Parameter(Mandatory)] [string] $Dir,
    [Parameter(Mandatory)] [string] $Desc
  )
  if (-not (Test-Path -LiteralPath $Dir)) {
    Write-Warn "$Desc dir missing: $Dir"
    return
  }
  $count = @(Get-ChildItem -LiteralPath $Dir -ErrorAction SilentlyContinue).Count
  if ($count -gt 0) {
    Write-Ok "${Desc}: $count entries in $Dir"
  }
  else {
    Write-Warn "$Desc dir empty: $Dir"
  }
}

# --- global tier ------------------------------------------------------------

Write-Host "==> verify-install (global tier — OS=windows)"

# PATH binaries. Codex is skip-only on Windows regardless of WITH_CODEX
# (install-clis.ps1 doesn't install Codex on this platform — upstream
# npm package is broken; see PLAN.md).
$bins = @(
  @{ Bin = 'git';    Desc = 'Git for Windows' },
  @{ Bin = 'node';   Desc = 'Node' },
  @{ Bin = 'npm';    Desc = 'npm' },
  @{ Bin = 'gh';     Desc = 'GitHub CLI' },
  @{ Bin = 'rg';     Desc = 'ripgrep' },
  @{ Bin = 'claude'; Desc = 'Claude Code CLI' },
  @{ Bin = 'gemini'; Desc = 'Gemini CLI' }
)
foreach ($b in $bins) {
  Test-BinOnPath -Bin $b.Bin -Desc $b.Desc
}
if ($WithCodex) {
  Write-Skip "codex on PATH (Codex CLI not supported on Windows yet — see openai/codex#18648)"
}
else {
  Write-Skip "codex on PATH (set WITH_CODEX=1 + native install on Mac/Linux to include Codex CLI)"
}

# GUI apps. Mac scope on Windows. SKIP_APPS=1 (set by setup.ps1 -SkipApps,
# typically in CI) consolidates all checks into one SKIP line.
if ($SkipApps) {
  Write-Skip "GUI apps (Antigravity Desktop, Claude Desktop) — SKIP_APPS=1 was set"
}
else {
  Test-WindowsApp -DisplayPattern '*Antigravity*' -FriendlyName 'Antigravity Desktop'
  Test-WindowsApp -DisplayPattern '*Claude*'      -FriendlyName 'Claude Desktop'
  Write-Skip "Gemini Desktop (no first-party Windows app — community wrappers out of scope)"
}

# Captured configs.
Test-RepoSymlinkOrCopy `
  -Path (Join-Path $env:USERPROFILE '.claude\CLAUDE.md') `
  -ExpectedSuffix 'configs\claude\CLAUDE.md'

Test-JsonFile  (Join-Path $env:USERPROFILE '.claude\settings.json')
Test-JsonFile  (Join-Path $env:USERPROFILE '.gemini\settings.json')
Test-JsoncFile (Join-Path $env:USERPROFILE '.antigravity\argv.json')

# No %APPDATA%\Claude\... validation — link-configs.ps1 doesn't manage
# that file (MSIX-redirect mess). User manages via the desktop app.

# Co-Authored-By kill-switch.
Test-CoAuthoredBy (Join-Path $env:USERPROFILE '.claude\settings.json')

# CLI smoke tests.
Test-CliVersion 'claude'
Test-CliVersion 'gemini'
if ($WithCodex) {
  Write-Skip "codex --version (Codex CLI not supported on Windows yet)"
}
else {
  Write-Skip "codex --version (set WITH_CODEX=1 + Mac/Linux to include Codex CLI)"
}

# Global Claude agents/skills dirs (informational; users may have none).
$claudeAgents = Join-Path $env:USERPROFILE '.claude\agents'
if (Test-Path -LiteralPath $claudeAgents) {
  Test-DirNonEmpty -Dir $claudeAgents -Desc 'global Claude sub-agents'
}
else {
  Write-Skip "no $claudeAgents (no global sub-agents installed)"
}
$claudeSkills = Join-Path $env:USERPROFILE '.claude\skills'
if (Test-Path -LiteralPath $claudeSkills) {
  Test-DirNonEmpty -Dir $claudeSkills -Desc 'global Claude skills'
}
else {
  Write-Skip "no $claudeSkills (no global skills installed)"
}

# --- harness tier -----------------------------------------------------------

$cwd = (Get-Location).Path
$harnessDir = Join-Path $cwd '.harness'
if (Test-Path -LiteralPath $harnessDir) {
  Write-Host ""
  "==> verify-install (harness project tier: $cwd)" | Write-Host

  $planPath     = Join-Path $harnessDir 'PLAN.md'
  $progressPath = Join-Path $harnessDir 'progress.md'
  $featuresPath = Join-Path $harnessDir 'features.json'
  $verifyPath   = Join-Path $harnessDir 'verify.sh'

  if (Test-Path -LiteralPath $planPath)     { Write-Ok ".harness\PLAN.md present" }     else { Write-Warn "missing .harness\PLAN.md" }
  if (Test-Path -LiteralPath $progressPath) { Write-Ok ".harness\progress.md present" } else { Write-Warn "missing .harness\progress.md" }

  if (Test-Path -LiteralPath $featuresPath) {
    try {
      [void](Get-Content -LiteralPath $featuresPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
      Write-Ok ".harness\features.json valid JSON"
    }
    catch {
      Write-Warn ".harness\features.json invalid JSON"
    }
  }
  else {
    Write-Warn "missing .harness\features.json"
  }

  if (Test-Path -LiteralPath $verifyPath) {
    Write-Ok ".harness\verify.sh present"
  }
  else {
    Write-Warn "missing .harness\verify.sh"
  }

  # Project-level Claude Code wiring.
  $projAgents = Join-Path $cwd '.claude\agents'
  if (Test-Path -LiteralPath $projAgents) {
    Test-DirNonEmpty -Dir $projAgents -Desc 'project sub-agents'
  }
  else {
    Write-Skip "no .claude\agents (project has no local sub-agents)"
  }
  $projSkills = Join-Path $cwd '.claude\skills'
  if (Test-Path -LiteralPath $projSkills) {
    Test-DirNonEmpty -Dir $projSkills -Desc 'project skills'
  }
  else {
    Write-Skip "no .claude\skills (project has no local skills)"
  }
  $projCommands = Join-Path $cwd '.claude\commands'
  if (Test-Path -LiteralPath $projCommands) {
    Test-DirNonEmpty -Dir $projCommands -Desc 'project slash commands'
  }
  else {
    Write-Skip "no .claude\commands (project has no slash commands)"
  }

  # PostToolUse hook references verify.sh? Stringify the array and
  # substring-match — robust to schema variations across harness versions.
  $projSettings = Join-Path $cwd '.claude\settings.json'
  if (Test-Path -LiteralPath $projSettings) {
    try {
      $settings = Get-Content -LiteralPath $projSettings -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      $hooksAsJson = $settings.hooks.PostToolUse | ConvertTo-Json -Depth 100 -Compress
      if ($hooksAsJson -and ($hooksAsJson -match 'verify\.sh')) {
        Write-Ok "PostToolUse hook references .harness\verify.sh"
      }
      else {
        Write-Warn "PostToolUse hook missing or does not reference verify.sh"
      }
    }
    catch {
      Write-Warn ".claude\settings.json invalid JSON"
    }
    Test-CoAuthoredBy $projSettings
  }
  else {
    Write-Skip "no .claude\settings.json (project hook + kill-switch checks skipped)"
  }
}
else {
  Write-Host ""
  "    [SKIP] no .harness in $cwd — harness project tier skipped" | Write-Host
}

# --- summary ----------------------------------------------------------------

Write-Host ""
'==> verify-install summary: {0} ok, {1} warn' -f $script:Pass, $script:Warn | Write-Host
"    Warn-only — setup continues regardless. Review WARN lines above." | Write-Host
exit 0
