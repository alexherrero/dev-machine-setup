#!/usr/bin/env pwsh
# scripts/auth-checklist.ps1 — printed at the end of setup.ps1.
#
# Mirror of scripts/auth-checklist.sh. Always exits 0; informational
# output only, not a gate. Windows = Mac scope (full GUI + CLI), so the
# checklist includes the GUI sign-in steps that the Linux version drops.
#
# Codex on Windows is skip-only — install-clis.ps1 doesn't install it
# (upstream npm package broken on this platform). Even when --with-codex
# is passed, we omit `codex login` from the numbered list and instead
# print a note explaining why.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$WithCodex = $env:WITH_CODEX -eq '1'

# Build the steps list. PSCustomObject pairs (Cmd, Desc) — printed with
# auto-numbering so additions / removals don't require renumbering.
$steps = @()

# CLI auth steps (always).
$steps += [pscustomobject]@{
  Cmd  = 'claude login'
  Desc = 'Sign in to the Claude Code CLI. Opens a browser for Anthropic oauth.'
}
$steps += [pscustomobject]@{
  Cmd  = 'gh auth login'
  Desc = 'Sign in to GitHub. Pick "GitHub.com" -> "HTTPS" -> "Login with a web browser". Required for `gh pr create`, `gh release create`, etc.'
}
$steps += [pscustomobject]@{
  Cmd  = 'gemini'
  Desc = 'First invocation of the Gemini CLI triggers Google oauth. Just run `gemini` in any terminal and follow the browser prompt.'
}

# GUI sign-ins (always — Windows = Mac scope, both apps installed via winget).
$steps += [pscustomobject]@{
  Cmd  = 'Open Antigravity from the Start menu'
  Desc = 'Launch Antigravity Desktop and sign in with the Google account you want it tied to. First launch finalizes workspace + agent config.'
}
$steps += [pscustomobject]@{
  Cmd  = 'Open Claude from the Start menu'
  Desc = 'Launch Claude Desktop and sign in with your Anthropic account. MCP extensions and preferences persist across restarts under %APPDATA%\Claude or %LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\... depending on install variant.'
}

# Print.
Write-Host '==> first-run auth checklist (OS=windows)'
Write-Host ''
Write-Host 'Installed tooling is in place. Complete each step below in any order — this is'
Write-Host 'the minimum set that can''t be scripted (oauth, interactive login, or signing'
Write-Host 'into the GUI apps).'
Write-Host ''

$i = 1
foreach ($s in $steps) {
  '  {0}. {1}' -f $i, $s.Cmd | Write-Host
  '     {0}'   -f $s.Desc    | Write-Host
  Write-Host ''
  $i++
}

# Codex note. Always-on note explaining why codex login isn't in the list,
# regardless of WITH_CODEX, since the install behavior on Windows is the
# same either way (skip-only). Different message based on whether the
# user opted in.
if ($WithCodex) {
  Write-Host '  (Codex CLI step omitted — Codex was requested via --with-codex but is'
  Write-Host '   not installed on Windows yet. The @openai/codex npm package is currently'
  Write-Host '   broken on Windows: see openai/codex#18648 and #11744. Mac and Linux still'
  Write-Host '   install it normally. Revisit when upstream fixes the package.)'
}
else {
  Write-Host '  (Codex CLI step omitted — pass --with-codex to setup.ps1 to include it.'
  Write-Host '   Note: Codex on Windows is skip-only at this time even with the flag set;'
  Write-Host '   it works on Mac and Linux only. See PLAN.md for the rationale.)'
}
Write-Host ''
Write-Host 'See docs/first-run.md for the same list with extra context.'

exit 0
