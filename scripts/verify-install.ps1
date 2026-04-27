#!/usr/bin/env pwsh
# verify-install.ps1 — Windows stub (PLAN.md task 9).
#
# Mirrors scripts/verify-install.sh: warn-only post-setup health check
# in two tiers (global / harness-project). Will become a near-direct port
# once the preceding Windows install stages are real and writing to the
# Windows config locations (%APPDATA%\Claude, %USERPROFILE%\.claude, etc.).
# See docs/windows.md.

$ErrorActionPreference = 'Stop'

Write-Host '==> verify-install (Windows)'
Write-Host '    TODO: implement on Windows reference VM'
exit 0
