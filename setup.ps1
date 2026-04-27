#!/usr/bin/env pwsh
# setup.ps1 — Windows orchestrator (stub).
#
# Mirrors setup.sh: same stage list, same flag shape. Stage scripts are
# currently TODO — see docs/windows.md for the deferral rationale.

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$SkipApps,
  [string]$Only,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot

$Stages = @(
  [pscustomobject]@{ Name = 'brew';           Script = 'install-brew.ps1';       Desc = 'Install Windows package manager + tooling (winget/choco TBD)' }
  [pscustomobject]@{ Name = 'clis';           Script = 'install-clis.ps1';       Desc = 'Install Claude Code CLI + Gemini CLI' }
  [pscustomobject]@{ Name = 'gui-apps';       Script = 'install-gui-apps.ps1';   Desc = 'Install Antigravity, Gemini Desktop, Claude Desktop' }
  [pscustomobject]@{ Name = 'link-configs';   Script = 'link-configs.ps1';       Desc = 'Place captured configs into their OS locations' }
  [pscustomobject]@{ Name = 'verify-install'; Script = 'verify-install.ps1';     Desc = 'Health-check the install (warn-only — tools, configs, agents, skills)' }
  [pscustomobject]@{ Name = 'auth-checklist'; Script = 'auth-checklist.ps1';     Desc = 'Print the manual auth steps' }
)

function Show-Usage {
  Write-Host 'Usage: ./setup.ps1 [-DryRun] [-SkipApps] [-Only <stage>] [-Help]'
  Write-Host ''
  Write-Host 'Bootstrap a fresh Windows dev environment (currently a stub — see docs/windows.md).'
  Write-Host ''
  Write-Host 'Stages:'
  foreach ($s in $Stages) {
    '  {0,-15} {1}' -f $s.Name, $s.Desc | Write-Host
  }
  Write-Host ''
  Write-Host 'Options:'
  Write-Host '  -DryRun      Print the ordered stage list and exit (no scripts run)'
  Write-Host '  -SkipApps    Skip the gui-apps stage'
  Write-Host '  -Only <s>    Run only the named stage'
  Write-Host '  -Help        Show this help'
  Write-Host ''
  Write-Host 'Windows implementation is deferred — see docs/windows.md.'
}

if ($Help) { Show-Usage; exit 0 }

if ($Only) {
  $validNames = $Stages | ForEach-Object { $_.Name }
  if ($validNames -notcontains $Only) {
    Write-Error ("unknown stage: {0}" -f $Only)
    Write-Error ("valid stages: {0}" -f ($validNames -join ', '))
    exit 2
  }
}

$plan = $Stages | Where-Object {
  (-not $Only -or $_.Name -eq $Only) -and
  (-not $SkipApps -or $_.Name -ne 'gui-apps')
}

if ($DryRun) {
  Write-Host '==> planned stages:'
  if (-not $plan) {
    Write-Host '    (none)'
  } else {
    foreach ($s in $plan) {
      $path = Join-Path $RepoRoot (Join-Path 'scripts' $s.Script)
      '    {0,-15} ({1})' -f $s.Name, $path | Write-Host
    }
  }
  exit 0
}

if (-not $plan) {
  Write-Host '==> nothing to do (all stages filtered out)'
  exit 0
}

foreach ($s in $plan) {
  $scriptPath = Join-Path $RepoRoot (Join-Path 'scripts' $s.Script)
  Write-Host ''
  Write-Host ("====> stage: {0}" -f $s.Name)
  if (-not (Test-Path $scriptPath)) {
    Write-Warning ("{0} does not exist — skipping (see PLAN.md)" -f $scriptPath)
    continue
  }
  & pwsh -NoProfile -File $scriptPath
  if ($LASTEXITCODE -ne 0) {
    Write-Error ("stage {0} failed with exit code {1}" -f $s.Name, $LASTEXITCODE)
    exit $LASTEXITCODE
  }
}

Write-Host ''
Write-Host '====> setup.ps1 complete'
