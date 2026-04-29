#!/usr/bin/env pwsh
# scripts/link-configs.ps1 — place captured configs at Windows OS locations.
#
# Mirror of scripts/link-configs.sh, with these Windows-specific differences:
#
#   symlink-with-copy-fallback : Mac/Linux always symlinks. Windows requires
#                                admin OR Developer Mode for unprivileged
#                                symlinks. We try New-Item SymbolicLink;
#                                on UnauthorizedAccessException, fall back
#                                to Copy-Item with a warning that repo edits
#                                won't auto-sync.
#     - %USERPROFILE%\.claude\CLAUDE.md
#
#   copy-if-absent : same strategy as Mac/Linux. App-owned JSON gets seeded
#                    on a fresh machine; the owning tool rewrites in place
#                    afterward, so subsequent runs preserve the live file.
#     - %USERPROFILE%\.claude\settings.json    (Claude Code)
#     - %USERPROFILE%\.gemini\settings.json    (Gemini CLI)
#     - %USERPROFILE%\.antigravity\argv.json   (path subject to empirical
#                                                verification on Windows;
#                                                see PLAN.md open question 3)
#
#   No %APPDATA%\Claude\claude_desktop_config.json placement. The MSIX
#   install of Claude Desktop redirects %APPDATA%\Claude\ to a virtualized
#   location under %LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\..., which
#   is documented as a footgun (claude-code#26073). v1 of Windows GUI
#   support does not seed this config — the user manages it via the
#   desktop app's UI.
#
#   git-config merge : `git config --global user.name/user.email`. Same
#                      as Mac/Linux. Preserves any existing includes,
#                      credential helpers, signing config.
#
#   No PATH-rc-file append : Windows uses persistent user-PATH writes
#                            via [Environment]::SetEnvironmentVariable,
#                            which install-clis.ps1 handles directly.
#                            The Linux append_shell_additions has no
#                            Windows analogue here.
#
#   Co-Authored-By kill-switch merge : same belt-and-braces logic as the
#                                       Mac/Linux fix. Uses ConvertFrom-Json
#                                       / ConvertTo-Json instead of jq.
#                                       Idempotent — re-run is a no-op when
#                                       the value is already false.
#
# Backup: any pre-existing non-matching file at a destination is moved to
# %USERPROFILE%\.dev-machine-setup-backup\<utc>\ before being replaced.
# Backup dir is lazy-created so a converged re-run leaves no trace.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BackupRoot = Join-Path $env:USERPROFILE '.dev-machine-setup-backup'
$Timestamp  = (Get-Date -AsUTC -Format 'yyyyMMddTHHmmssZ')
$BackupDir  = Join-Path $BackupRoot $Timestamp
$script:BackedUp = $false

# --- helpers ----------------------------------------------------------------

function Backup-IfNeeded {
  param([Parameter(Mandatory)] [string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  # Already the correct symlink into our repo? No backup needed.
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -like "$RepoRoot*") {
    return
  }
  if (-not $script:BackedUp) {
    [void](New-Item -ItemType Directory -Path $BackupDir -Force)
    $script:BackedUp = $true
  }
  # Build a path under the backup dir that mirrors the original under HOME.
  if ($Path.StartsWith($env:USERPROFILE, [System.StringComparison]::OrdinalIgnoreCase)) {
    $rel = $Path.Substring($env:USERPROFILE.Length).TrimStart('\')
  }
  else {
    # Drop the drive colon for paths outside USERPROFILE.
    $rel = $Path.Replace(':', '').TrimStart('\')
  }
  $bdest = Join-Path $BackupDir $rel
  $bdir  = Split-Path -Parent $bdest
  if (-not (Test-Path -LiteralPath $bdir)) {
    [void](New-Item -ItemType Directory -Path $bdir -Force)
  }
  Move-Item -LiteralPath $Path -Destination $bdest -Force
  '    backed up: {0} -> {1}' -f $Path, $bdest | Write-Host
}

function Set-RepoSymlink {
  # Mirror of link_symlink in the bash version. Tries SymbolicLink; falls
  # back to Copy-Item on UnauthorizedAccessException (no admin / no Dev Mode).
  param(
    [Parameter(Mandatory)] [string] $SrcRel,
    [Parameter(Mandatory)] [string] $Dest
  )
  $src = Join-Path $RepoRoot $SrcRel
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
    Write-Error "    FAIL: missing source $src"
    exit 1
  }
  $destDir = Split-Path -Parent $Dest
  if (-not (Test-Path -LiteralPath $destDir)) {
    [void](New-Item -ItemType Directory -Path $destDir -Force)
  }
  # Already correct symlink?
  if (Test-Path -LiteralPath $Dest) {
    $existing = Get-Item -LiteralPath $Dest -Force
    if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -ieq $src) {
      '    symlink   {0,-55} (already correct)' -f $Dest | Write-Host
      return
    }
  }
  Backup-IfNeeded -Path $Dest
  try {
    [void](New-Item -ItemType SymbolicLink -Path $Dest -Target $src -ErrorAction Stop)
    '    symlink   {0,-55} -> {1}' -f $Dest, $src | Write-Host
  }
  catch [System.UnauthorizedAccessException] {
    Write-Warning "Symlink creation requires admin or Developer Mode. Falling back to copy."
    Write-Warning "Edits in the repo won't auto-sync. Toggle Developer Mode in Settings > Privacy & security > For developers, then re-run."
    Copy-Item -LiteralPath $src -Destination $Dest -Force
    '    copied    {0,-55} (no symlink — see warning above)' -f $Dest | Write-Host
  }
  catch {
    # Some PowerShell versions / privilege configurations wrap the access
    # denied error differently. Retry as Copy-Item rather than fail outright.
    Write-Warning ("Symlink creation failed: {0}. Falling back to copy." -f $_.Exception.Message)
    Copy-Item -LiteralPath $src -Destination $Dest -Force
    '    copied    {0,-55} (symlink fallback)' -f $Dest | Write-Host
  }
}

function Copy-RepoFileIfAbsent {
  # Mirror of link_copy_if_absent in the bash version.
  param(
    [Parameter(Mandatory)] [string] $SrcRel,
    [Parameter(Mandatory)] [string] $Dest
  )
  $src = Join-Path $RepoRoot $SrcRel
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
    Write-Error "    FAIL: missing source $src"
    exit 1
  }
  if (Test-Path -LiteralPath $Dest) {
    '    preserve  {0,-55} (exists; managed by owning tool)' -f $Dest | Write-Host
    return
  }
  $destDir = Split-Path -Parent $Dest
  if (-not (Test-Path -LiteralPath $destDir)) {
    [void](New-Item -ItemType Directory -Path $destDir -Force)
  }
  Copy-Item -LiteralPath $src -Destination $Dest -Force
  '    seeded    {0,-55} (copy of {1})' -f $Dest, $SrcRel | Write-Host
}

function Merge-Gitconfig {
  # Use `git config --global` so existing includes, credential helpers,
  # signing config survive — mirrors the bash version.
  $src = Join-Path $RepoRoot 'configs\git\.gitconfig'
  if (-not (Test-Path -LiteralPath $src)) { return }
  $name  = (& git config --file $src user.name 2>$null)
  $email = (& git config --file $src user.email 2>$null)
  if (-not $name -or -not $email) {
    "    gitconfig: no user.name/email in $src — skipping" | Write-Host
    return
  }
  $liveName  = (& git config --global user.name 2>$null)
  $liveEmail = (& git config --global user.email 2>$null)
  $gitconfig = Join-Path $env:USERPROFILE '.gitconfig'
  if ($liveName -eq $name -and $liveEmail -eq $email) {
    '    gitconfig {0,-55} (user.name/email already match)' -f $gitconfig | Write-Host
    return
  }
  & git config --global user.name $name
  & git config --global user.email $email
  '    gitconfig {0,-55} (set user.name={1}, user.email={2})' -f $gitconfig, $name, $email | Write-Host
}

function Set-ClaudeCoAuthoredByDisabled {
  # Ensure includeCoAuthoredBy=false in %USERPROFILE%\.claude\settings.json
  # even when copy-if-absent preserved an existing file. Claude Code may
  # write a default settings.json before link-configs runs on a fresh
  # machine; this merge is the same belt-and-braces logic as the bash
  # version, using ConvertFrom-Json / ConvertTo-Json instead of jq.
  $f = Join-Path $env:USERPROFILE '.claude\settings.json'
  if (-not (Test-Path -LiteralPath $f)) { return }
  try {
    $json = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    Write-Warning "$f is invalid JSON — skipping kill-switch merge"
    return
  }
  $alreadySet = ($json.PSObject.Properties.Name -contains 'includeCoAuthoredBy') -and ($json.includeCoAuthoredBy -eq $false)
  if ($alreadySet) {
    '    co-author {0,-55} (kill-switch already set)' -f $f | Write-Host
    return
  }
  if ($json.PSObject.Properties.Name -contains 'includeCoAuthoredBy') {
    $json.includeCoAuthoredBy = $false
  }
  else {
    $json | Add-Member -NotePropertyName 'includeCoAuthoredBy' -NotePropertyValue $false -Force
  }
  $json | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $f -Encoding UTF8
  '    co-author {0,-55} (merged includeCoAuthoredBy=false)' -f $f | Write-Host
}

# --- main -------------------------------------------------------------------

Write-Host "==> linking configs"

Set-RepoSymlink `
  -SrcRel 'configs\claude\CLAUDE.md' `
  -Dest (Join-Path $env:USERPROFILE '.claude\CLAUDE.md')

Copy-RepoFileIfAbsent `
  -SrcRel 'configs\claude\settings.json' `
  -Dest (Join-Path $env:USERPROFILE '.claude\settings.json')

# No %APPDATA%\Claude\claude_desktop_config.json placement — see header.
'    skip      {0,-55} (Windows: MSIX-redirect mess; user manages via app)' -f (Join-Path $env:APPDATA 'Claude\claude_desktop_config.json') | Write-Host

Copy-RepoFileIfAbsent `
  -SrcRel 'configs\gemini\settings.json' `
  -Dest (Join-Path $env:USERPROFILE '.gemini\settings.json')

# Antigravity argv.json: VSCode convention (%USERPROFILE%\.antigravity\argv.json).
# Path is unconfirmed in Google's docs (see PLAN.md open question 3); seed
# defensively. If Antigravity Desktop uses a different path, this file is
# a stray no-op that Antigravity ignores. Verify empirically in task-8 CI.
Copy-RepoFileIfAbsent `
  -SrcRel 'configs\antigravity\argv.json' `
  -Dest (Join-Path $env:USERPROFILE '.antigravity\argv.json')

Merge-Gitconfig
Set-ClaudeCoAuthoredByDisabled

# --- post-check -------------------------------------------------------------

Write-Host "==> verifying"

# Strict JSON validation via ConvertFrom-Json (no jq dep on Windows).
$strictJsons = @(
  (Join-Path $env:USERPROFILE '.claude\settings.json'),
  (Join-Path $env:USERPROFILE '.gemini\settings.json')
)
foreach ($json in $strictJsons) {
  if (-not (Test-Path -LiteralPath $json)) { continue }
  try {
    [void](Get-Content -LiteralPath $json -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
    '    json-ok   {0}' -f $json | Write-Host
  }
  catch {
    Write-Error "    FAIL: invalid JSON at $json"
    exit 1
  }
}

# argv.json is JSONC (Electron / VS Code convention — line comments allowed).
# Strip // line comments before parsing, mirroring sed's behavior in the
# bash version.
$argv = Join-Path $env:USERPROFILE '.antigravity\argv.json'
if (Test-Path -LiteralPath $argv) {
  try {
    $stripped = (Get-Content -LiteralPath $argv -Raw -Encoding UTF8) -replace '(?m)//.*$', ''
    [void]($stripped | ConvertFrom-Json -ErrorAction Stop)
    '    json-ok   {0} (jsonc)' -f $argv | Write-Host
  }
  catch {
    Write-Error "    FAIL: invalid JSONC at $argv"
    exit 1
  }
}

# CLAUDE.md placement check (symlink resolves into repo, or copy fallback).
$claudeMd = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (Test-Path -LiteralPath $claudeMd) {
  $item = Get-Item -LiteralPath $claudeMd -Force
  if ($item.LinkType -eq 'SymbolicLink') {
    '    readlink  {0} -> {1}' -f $claudeMd, $item.Target | Write-Host
  }
  else {
    '    copied    {0} (no symlink — see Dev Mode warning above)' -f $claudeMd | Write-Host
  }
}

if ($script:BackedUp) {
  '    backups:  {0}' -f $BackupDir | Write-Host
}

Write-Host "==> link-configs stage complete"
