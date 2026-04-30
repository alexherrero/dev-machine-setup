# Windows support

CLI-and-GUI scope, mirroring Mac. `setup.ps1` on a fresh Windows 10/11
host installs the toolchain (Git for Windows, Node LTS, gh, ripgrep —
all via winget), the CLI agents (Claude Code via winget, Gemini CLI via
npm), and the GUI apps (Antigravity Desktop + Claude Desktop via
winget). Configs are placed at Windows-native paths
(`%USERPROFILE%\.claude\`, `%USERPROFILE%\.gemini\`, etc.).

## Quick start

```powershell
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.ps1 -Help                     # prints the 6-stage list
./setup.ps1                           # end-to-end (Antigravity + Claude Desktop install)
./setup.ps1 -SkipApps                 # CLI-only, no GUI installs (CI / headless)
./setup.ps1 -WithCodex                # opt in to Codex CLI (note: skip-with-warn on Windows)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

The PATH-refresh one-liner at the end picks up the registry-PATH writes
that winget made — same idea as `source ~/.zshrc` on Unix. New shells
inherit the user-PATH automatically; only the running shell needs the
explicit refresh.

## Supported

| Component | Status |
| --- | --- |
| Windows 10 1809+ (winget pre-installed) | supported |
| Windows 11 | supported |
| PowerShell 7+ (`pwsh`) | required (Windows PowerShell 5.1 likely works for most stages but isn't routinely tested) |
| amd64 / arm64 | both work via winget's per-arch resolution |

CI runs `./setup.ps1 -SkipApps` end-to-end on `windows-latest` whenever
the workflow is dispatched — see
[.github/workflows/ci-tests.yml](../.github/workflows/ci-tests.yml).

## Stage list

```
tooling          winget Git for Windows + Node LTS + gh + ripgrep
clis             Claude Code (winget) + Gemini CLI (npm); Codex skip-with-warn
gui-apps         Antigravity Desktop + Claude Desktop (winget)
link-configs     Place captured configs at Windows OS locations
verify-install   Warn-only post-setup health check
auth-checklist   Print the manual auth steps
```

## Codex on Windows

OpenAI Codex CLI is **not installed on Windows in this scope**, even
when `-WithCodex` is passed. The `@openai/codex` npm package is
currently broken on Windows — the per-platform native binary (`@openai/codex-win32-x64`)
isn't published as expected, so npm resolves a stale binary. See
[openai/codex#18648](https://github.com/openai/codex/issues/18648) and
[#11744](https://github.com/openai/codex/issues/11744). Mac and Linux
still install Codex normally. Revisit when upstream fixes the package.

`-WithCodex` is still honored as a signal of intent — the user-facing
checklist and verifier produce different messages so users know whether
they asked for Codex or not.

## Claude Code: winget vs native installer

This setup uses `winget install Anthropic.ClaudeCode`. The Anthropic
docs also offer a native PowerShell installer
(`irm https://claude.ai/install.ps1 | iex`) that drops the binary at
`%USERPROFILE%\.local\bin\claude.exe` and **auto-updates in the
background**. Trade-offs:

- **winget (this repo's default)**: system-managed, no auto-update.
  User runs `winget upgrade Anthropic.ClaudeCode` periodically.
- **Native installer**: auto-updates. Symmetric with the Mac/Linux
  `claude.ai/install.sh` model.

Installing both at once is a documented footgun
([claude-code#31980](https://github.com/anthropics/claude-code/issues/31980))
because they land at different paths and don't dedupe. Pick one.

## Symlink for `CLAUDE.md`

`link-configs.ps1` symlinks `%USERPROFILE%\.claude\CLAUDE.md` to the
repo's `configs\claude\CLAUDE.md` so edits sync both ways. On Windows,
unprivileged symlinks require **either admin OR Developer Mode**
enabled. The script tries `New-Item -ItemType SymbolicLink` first; on
`UnauthorizedAccessException` it falls back to `Copy-Item` and prints a
warning that repo edits won't auto-sync.

To get symlinks working without admin: open Settings → Privacy &
security → For developers → Developer Mode → toggle **on**. Then
re-run `setup.ps1` (or just the link-configs stage:
`./setup.ps1 -Only link-configs`).

## What this script does NOT do

- **Manage `claude_desktop_config.json`.** The MSIX install of Claude
  Desktop redirects `%APPDATA%\Claude\` to a virtualized location
  under `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\`,
  while the Electron "Edit Config" button bypasses the redirect. You
  can end up with two configs and silent MCP-server failures
  ([claude-code#26073](https://github.com/anthropics/claude-code/issues/26073)).
  v1 of Windows GUI support punts: the user manages this config via
  Claude Desktop's UI. If you need MCP server config, edit through the
  app rather than dropping a file in the seemingly-canonical path.
- **Install Gemini Desktop.** No first-party Windows app exists.
  Community Electron wrappers (`bwendell/gemini-desktop`,
  `dortanes/gemini-desktop`) are out of scope. Use the Gemini CLI
  (which IS installed) or Gemini in the browser.
- **Install Codex CLI.** See above.
- **Capture live Windows configs back to the repo.** No
  `scripts\capture.ps1` Windows variant in this scope. The current
  configs come from a Mac reference machine; Windows installs use
  those same platform-agnostic JSONs.

## File layout

```
setup.ps1                    Top-level orchestrator
scripts\install-tooling.ps1  winget toolchain (Git, Node LTS, gh, ripgrep)
scripts\install-clis.ps1     Claude (winget) + Gemini (npm) + Codex (skip)
scripts\install-gui-apps.ps1 Antigravity + Claude Desktop (winget)
scripts\link-configs.ps1     Place captured configs at Windows paths
scripts\verify-install.ps1   Warn-only post-setup health check
scripts\auth-checklist.ps1   Print manual auth steps
```

## Future work

- **Antigravity `argv.json` path**: currently placed at
  `%USERPROFILE%\.antigravity\argv.json` (VSCode-fork convention) on
  the assumption that Antigravity follows VSCode. Google's docs only
  confirm `%APPDATA%\Antigravity\` for auth-tokens and Cache; if
  Antigravity uses a different argv.json path on Windows, the seeded
  file is a stray no-op. Empirical verification welcome.
- **Codex CLI** when upstream fixes the npm package, or via the
  GitHub-Release `codex-x86_64-pc-windows-msvc.tar.gz` fallback (out
  of scope for v1).
- **Claude Desktop config management** when the MSIX-redirect
  duality lands a documented stable path.
- **Gemini Desktop** if Google ever ships a first-party standalone
  Windows app.
- **`scripts\capture.ps1`** for re-syncing live Windows configs into
  the repo. Useful if a user wants to capture from a Windows reference
  machine; not blocking since the existing Mac-captured configs are
  platform-agnostic.

## Reference

- [first-run.md](first-run.md) — manual auth checklist (claude login,
  gh auth login, etc.).
- [debian.md](debian.md) — Debian/Ubuntu CLI-only path (no GUI apps).
- [.harness/PLAN.md](../.harness/PLAN.md) — `feat-windows-cli-support`
  task list.
- [scripts/install-tooling.ps1](../scripts/install-tooling.ps1) — winget
  toolchain installer.
- [scripts/install-clis.ps1](../scripts/install-clis.ps1) — CLI agent
  installer.
