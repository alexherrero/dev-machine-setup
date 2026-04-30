# Plan: Real Windows CLI + GUI install support (feat-windows-cli-support)

**Status:** complete (2026-04-29 — all 9 tasks `[x]`; CI-verified green on run 25142962483; v2.0.0 ships next).
**Brief:** Replace the smoke-only Windows job in `ci-tests.yml` with real install verification. Windows matches **Mac scope** (full GUI + CLI: Antigravity Desktop + Claude Desktop), not Debian's CLI-only scope. The smoke job from `feat-ci-verification` (orchestrator runs cleanly + AST parse) gets upgraded to a real install pipeline that exercises every stage script.

## Goal

`./setup.ps1` on a fresh Windows 10/11 host installs the full toolchain (Git for Windows, Node LTS, gh, ripgrep — all via winget), the CLI agents (Claude Code via native installer, Gemini via npm), and the GUI apps (Antigravity Desktop + Claude Desktop via winget). Configs are placed at Windows-native paths (`%USERPROFILE%\.claude\`, `%USERPROFILE%\.gemini\`, etc.). `verify-install.ps1` confirms everything is in place. CI dispatch goes green on `windows-latest` end-to-end. When that passes, `feat-windows-cli-support.passes=true` and v1.1.0 ships.

## Constraints

- **Windows = Mac scope** (full GUI + CLI), not Debian (CLI-only). Antigravity Desktop and Claude Desktop are installed via winget. Gemini Desktop has no first-party Windows app — skipped.
- **winget is the package manager.** Pre-installed on Windows 10 1809+ / Windows 11. No Chocolatey fallback (winget covers our deps).
- **Claude Code via winget** (`Anthropic.ClaudeCode`). System-managed; doesn't auto-update (apt-style lifecycle, user runs `winget upgrade` periodically). Different binary location than the native installer would use; the native `irm | iex` alternative is documented in `docs/windows.md` for users who prefer auto-updating installs. Installing both is documented as a footgun (claude-code#31980) — the script picks one path and sticks to it.
- **No npm prefix relocation on Windows.** npm-globals on Windows install to `%APPDATA%\npm` by default; we ensure that path is in user PATH after `npm install -g`. Mac/Linux's `~/.npm-global` workaround is for sudo-avoidance — not needed on Windows where npm-globals are user-scoped already.
- **Persistent user PATH model**, not shell-rc. Updates via `[Environment]::SetEnvironmentVariable("Path", $newPath, "User")`. The Mac/Linux marker-block-in-rc-file pattern doesn't apply.
- **Symlink CLAUDE.md with copy fallback.** Try `New-Item -ItemType SymbolicLink`; on `UnauthorizedAccessException` (no admin, no Developer Mode) fall back to `Copy-Item` with a warning that repo edits won't auto-sync. Document the Developer-Mode-toggle workaround in `docs/windows.md`.
- **Don't touch Claude Desktop config.** The MSIX install redirects `%APPDATA%\Claude\` to `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\`; the Electron "Edit Config" button bypasses the redirect; you can end up with two configs and silent MCP-server failures (claude-code#26073). v1 of Windows GUI support **does not** seed `claude_desktop_config.json` — the user manages it via the desktop app's UI. Document the rationale in `docs/windows.md`.
- **Reuse existing `configs/` capture.** No `scripts/capture.ps1` Windows variant in this plan. The current `configs/claude/CLAUDE.md`, `configs/claude/settings.json`, `configs/gemini/settings.json`, and `configs/antigravity/argv.json` are platform-agnostic content; they place to the same files at Windows paths. The Mac-only `configs/claude-desktop/claude_desktop_config.json` is **not** placed on Windows (per the previous bullet).
- **Idempotent everywhere**, same contract as Mac/Debian: re-running converges; pre-existing files are backed up to `%USERPROFILE%\.dev-machine-setup-backup\<utc>\` before being replaced.

## Out of scope

- **Gemini Desktop on Windows.** No first-party standalone app exists; community Electron wrappers are out of scope.
- **Codex CLI on Windows** (default — see open question 1). The `@openai/codex` npm package is **currently broken on Windows** (issues #18648, #11744 — `@openai/codex-win32-x64` not published as an optionalDependency post-0.100.0; npm resolves stale binary). Default plan: `--with-codex` on Windows prints `==> Codex CLI: skipped (not supported on Windows yet — upstream npm packaging bugs)` and exits the stage cleanly. GitHub-Release-binary fallback is a known alternative; opt in via open question 1.
- **Managing Claude Desktop's `claude_desktop_config.json`** (per the MSIX-redirect mess above). User manages via the desktop app.
- **Capture script for Windows.** `scripts/capture.ps1` would mirror `scripts/capture.sh` for re-syncing live configs back into the repo from a Windows reference machine — useful but not needed for this plan since we reuse the Mac-captured configs.
- **Other Windows shells** (cmd.exe, Git Bash, MSYS2, WSL). PowerShell 5.1+ (pre-installed on every supported Windows) is the only target. WSL Ubuntu users hit the existing Debian path via `setup.sh`.

## Tasks

### 1. `scripts/install-tooling.ps1` — winget toolchain installer

- **What:** Mirror of `scripts/install-brew.sh` and `scripts/install-apt.sh`. Steps:
  - Pre-flight: assert winget exists; if missing (older Windows 10), exit 2 with a pointer to the App Installer / winget upgrade docs.
  - For each `(WingetId, ExpectedBinary)` pair, install via `winget install -e --id $WingetId --accept-package-agreements --accept-source-agreements --silent` if the binary isn't already on PATH:
    - `Git.Git` (required by Claude Code — shells out to Git Bash)
    - `OpenJS.NodeJS.LTS`
    - `GitHub.cli`
    - `BurntSushi.ripgrep.MSVC`
  - **Skip** `jq` (PowerShell has native `ConvertFrom-Json`), `shellcheck`, `shfmt` (no bash scripts on Windows).
  - After installs, refresh user PATH from registry into the current session (`$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")`) so subsequent stages see the new tools.
  - Post-check: `git --version`, `node --version`, `npm --version`, `gh --version`, `rg --version` all exit 0.
- **Verification:** `pwsh AST parse` (via `.harness/verify.sh` on the Windows runner — actually, our verify.sh skips when pwsh isn't available; the AST step in `windows-test` covers this). On Windows VM: every winget call is a no-op on second run (winget's `--accept-package-agreements` is idempotent — exits 0 even when already installed). All five binaries on PATH after first run.
- **Status:** [x] (2026-04-29: scripts/install-tooling.ps1 created. Pre-flight winget existence check (exits 2 with App Installer pointer if missing); 4 winget packages installed via parallel-array `[pscustomobject]@{Id=..., Bin=...}` (Git.Git, OpenJS.NodeJS.LTS, GitHub.cli, BurntSushi.ripgrep.MSVC); skip-if-binary-on-PATH for idempotency; PATH refresh from registry (Machine + User scopes joined) into the running shell; post-check loop verifies git/node/npm/gh/rg all resolve. Local pwsh AST parse not run (pwsh not installed on this Mac and brew cask requires sudo); harness verify.sh accepts the file (silent skip on the AST gate when pwsh missing). The Windows CI job's "AST-parse all .ps1 files" step is the actual AST gate; real winget runtime exercise lands when task 8 upgrades the windows-test job from smoke to real install.)

### 2. `scripts/install-clis.ps1` — real CLI installs

- **What:** Replace the stub. Three installs (Codex conditional):
  - **Claude Code**: `winget install -e --id Anthropic.ClaudeCode --accept-package-agreements --accept-source-agreements --silent`. winget manages the binary location and PATH update. Re-running is a no-op (winget exits 0 when already installed). Per-user winget upgrade is the user's responsibility (`winget upgrade Anthropic.ClaudeCode`).
  - **Gemini CLI**: `npm install -g @google/gemini-cli`. After install, ensure `%APPDATA%\npm` is in user PATH (npm doesn't always do this on Windows).
  - **Codex CLI**: gated on `$env:WITH_CODEX -eq '1'`. **Default behavior on Windows is skip-with-warn** (per the open question 1 default): print the "not supported on Windows yet" banner and continue without erroring. If the user opts into the GitHub-Release fallback (per open question 1), we instead download `codex-x86_64-pc-windows-msvc.tar.gz` from the latest release and drop `codex.exe` into `%USERPROFILE%\.local\bin\`.
  - Hard-fail with a clear message if `node --version` reports < 20 (Gemini CLI requires ≥ 20). winget Node LTS is currently 22, so this guard is defensive.
  - Post-check: `claude --version`, `gemini --version`, plus `codex --version` if WITH_CODEX=1 and the Codex install succeeded.
- **Verification:** AST parse clean. On Windows VM: all three (or two if Codex skipped) binaries resolve and `--version` exits 0. Re-run is idempotent.
- **Status:** [x] (2026-04-29: scripts/install-clis.ps1 rewritten from stub. Three install paths: Claude via `winget install --exact --id Anthropic.ClaudeCode --silent`; Gemini via `npm install -g @google/gemini-cli`; Codex skip-with-warn (warn message differentiates between `--with-codex`-opted-in vs default). Three approved-verb helpers: `Update-PathFromRegistry` (joins Machine + User scopes from registry into `$env:Path`), `Add-DirToUserPath` (idempotent registry-PATH append + session splice), `Test-NodeVersion` (hard-fails < 20 with pointer to install-tooling.ps1). Default npm prefix `%APPDATA%\npm` added to user PATH before `npm install -g` so gemini.cmd resolves. winget exit codes treated as warnings, not failures (post-check is the gate). Post-check expects only claude + gemini regardless of WITH_CODEX (Codex never installs on Windows in v1). Local pwsh AST parse not run (pwsh missing); harness verify.sh accepts. Windows CI's AST step is the gate; runtime exercise lands at task 8.)

### 3. `scripts/install-gui-apps.ps1` — winget GUI app installer

- **What:** Two installs:
  - **Antigravity Desktop**: `winget install -e --id Google.Antigravity` (or fall back to direct `.exe` download from `https://antigravity.google/` if the winget id isn't available — research couldn't confirm the exact id; verify during /work). Skip if `Get-AppxPackage` or registry-uninstall lookup says it's already present.
  - **Claude Desktop**: `winget install -e --id Anthropic.Claude` (distinct from `Anthropic.ClaudeCode`). Skip if already present.
  - **Gemini Desktop**: explicitly skipped — no first-party Windows app. Print `==> Gemini Desktop: skipped (no first-party Windows app)`.
- **Verification:** AST parse clean. On Windows VM: both apps appear in `Get-Package` / Add-or-Remove-Programs after first run; `Get-Command Antigravity` and Claude Desktop launcher present (paths differ — locate via Start Menu shortcuts or registry uninstall keys). Re-run is no-op (winget already-installed exits 0).
- **Status:** [x] (2026-04-29: scripts/install-gui-apps.ps1 rewritten from stub. Single helper `Install-WingetApp` parameterized over `(Id, DisplayName, ManualUrl)`. Three branches on `$LASTEXITCODE`: 0 → ok; `-1978335212` (APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND signed) → skip-with-warn + manual-URL pointer; other non-zero → generic warning (verify-install confirms post-install state). Antigravity uses `Google.Antigravity`; if that id isn't published on the default winget source, the no-applications-found branch fires and the user gets the antigravity.google homepage. Claude Desktop uses `Anthropic.Claude` (distinct from the CLI's `Anthropic.ClaudeCode` from task 2). Gemini Desktop explicitly skipped — no first-party Windows app. Pre-flight asserts winget exists. Local pwsh AST parse not run; CI's AST step is the gate. Empirical id-correctness verification waits for the first task-8 dispatch.)

### 4. `scripts/link-configs.ps1` — Windows-native config placement

- **What:** Mirror of `scripts/link-configs.sh` for Windows paths:
  - **Symlink-with-copy-fallback** for `%USERPROFILE%\.claude\CLAUDE.md` → repo's `configs\claude\CLAUDE.md`. Try `New-Item -ItemType SymbolicLink -Path $dest -Target $src`; on `UnauthorizedAccessException` (no admin, no Developer Mode), fall back to `Copy-Item -Path $src -Destination $dest -Force` and emit a warning that repo edits won't auto-propagate. Document the Developer-Mode toggle in docs/windows.md.
  - **Copy-if-absent** for the JSON configs:
    - `%USERPROFILE%\.claude\settings.json` ← `configs\claude\settings.json`
    - `%USERPROFILE%\.gemini\settings.json` ← `configs\gemini\settings.json`
    - `%USERPROFILE%\.antigravity\argv.json` ← `configs\antigravity\argv.json` *(path subject to open question 3 — verify during /work)*
  - **Co-Authored-By kill-switch merge**: same logic as the Mac/Linux fix. Use `ConvertFrom-Json` + `Add-Member -Force` + `ConvertTo-Json` on `%USERPROFILE%\.claude\settings.json` to ensure `includeCoAuthoredBy = false` regardless of whether the file existed pre-install.
  - **`git config --global` merge** for `user.name` / `user.email` (same as Mac). PowerShell-side: `git config --global user.name $name` etc.
  - **Backup** any pre-existing non-matching dest into `%USERPROFILE%\.dev-machine-setup-backup\<utc>\` before replacement. Lazy-create the backup dir.
  - **No Claude Desktop config placement** (per the MSIX-mess constraint).
  - **No Windows PATH-rc-file equivalent** — that work is done by `install-clis.ps1` directly (Claude installer + npm prefix → persistent user PATH).
- **Verification:** AST parse clean. On Windows VM: symlink path resolves to repo file (or copy + warn fired if Dev Mode off); the three JSONs are valid (Test-Json or ConvertFrom-Json doesn't throw); `includeCoAuthoredBy` is false post-merge; `git config --global user.name/email` matches captured. Re-run is fully no-op (no new backup dir created).
- **Status:** [x] (2026-04-29: scripts/link-configs.ps1 rewritten from stub. Five PowerShell-native helpers using approved verbs: `Backup-IfNeeded` (lazy backup-dir creation; honors existing-correct-symlink as no-backup-needed via LinkType + Target check), `Set-RepoSymlink` (try `New-Item -ItemType SymbolicLink`; catch `UnauthorizedAccessException` and any other exception, fall back to `Copy-Item` with a Dev-Mode-toggle warning), `Copy-RepoFileIfAbsent` (mirror of `link_copy_if_absent`), `Merge-Gitconfig` (uses `git config --global` to preserve existing includes/credential-helpers/signing config), `Set-ClaudeCoAuthoredByDisabled` (ConvertFrom-Json + Add-Member or assign + ConvertTo-Json roundtrip; idempotent). Five config placements: CLAUDE.md symlink-with-fallback, claude/gemini settings.json copy-if-absent, antigravity/argv.json copy-if-absent at the VSCode-convention path, explicit skip with rationale for Mac-only Claude Desktop config (MSIX-redirect mess). Strict-JSON post-check via `ConvertFrom-Json`; JSONC post-check for argv.json strips `//` line comments via `(?m)//.*$` regex (mirrors sed in the bash version). Local pwsh AST parse not run (pwsh missing); Windows CI's AST step is the gate. Runtime exercise + symlink-vs-copy fallback path verification land at task 8.)

### 5. `scripts/verify-install.ps1` — Windows post-setup health check

- **What:** Mirror of `scripts/verify-install.sh`. Two tiers (global + harness). Warn-only, exits 0 always:
  - **Global tier**: PATH-binary checks (`git`, `node`, `npm`, `gh`, `rg`, `claude`, `gemini`, `codex` if WITH_CODEX=1); GUI app presence (Antigravity Desktop + Claude Desktop via `Get-Package` or registry uninstall lookup, gated on `$env:SKIP_APPS -ne '1'`); captured-config validity (`Test-Path` + `Test-Json` for the three JSONs); `%USERPROFILE%\.claude\CLAUDE.md` is a symlink-or-file pointing at repo (with-or-without symlink); `includeCoAuthoredBy = false` in `%USERPROFILE%\.claude\settings.json`; `claude --version` / `gemini --version` smoke-tests.
  - **Harness tier** (only when `Test-Path .harness`): same checks as the bash version — `PLAN.md`, `progress.md`, `features.json` validity, `.harness\verify.sh` exists, project `.claude\agents`, `.claude\skills`, `.claude\commands` populated, `PostToolUse` hook references `verify.sh`.
  - PowerShell-native parsing (no jq dep). Tally OK / WARN / SKIP. Print summary line.
- **Verification:** AST parse clean. On Windows VM: after a full setup run, `verify-install.ps1` reports `0 warn` (Mac default baseline-equivalent). With `SKIP_APPS=1`, GUI app checks consolidate to a `[SKIP]` line. With `WITH_CODEX != 1`, Codex checks `[SKIP]`.
- **Status:** [x] (2026-04-29: scripts/verify-install.ps1 rewritten from stub. Mirror of verify-install.sh with PowerShell-native helpers (no jq dep). Eight approved-verb helpers: `Write-Ok`/`Write-Warn`/`Write-Skip` (counters via `$script:Pass`/`Warn`); `Test-BinOnPath`; `Test-JsonFile` / `Test-JsoncFile`; `Test-WindowsApp` (registry uninstall-key search across HKLM + HKLM/WOW6432Node + HKCU); `Test-RepoSymlinkOrCopy` (accepts both SymbolicLink and Copy-fallback as OK); `Test-CoAuthoredBy` (ConvertFrom-Json + property check); `Test-CliVersion`; `Test-DirNonEmpty`. Codex on Windows is skip-only regardless of WITH_CODEX (install-clis.ps1 doesn't install it); message differentiates WITH_CODEX-opted-in vs default. SKIP_APPS=1 consolidates GUI app checks into one SKIP line. Harness tier checks PLAN.md/progress.md/features.json/verify.sh, project sub-agents/skills/commands, PostToolUse hook reference (ConvertTo-Json -Compress + regex match for `verify\.sh` — robust to schema variations). Local pwsh AST parse not run; Windows CI's AST step is the gate. Runtime exercise lands at task 8.)

### 6. `scripts/auth-checklist.ps1` — Windows manual auth steps

- **What:** Mirror of `scripts/auth-checklist.sh`. Dynamic steps:
  - Always: `claude login`, `gh auth login`, `gemini` (first run).
  - Conditional on `WITH_CODEX=1` AND Codex actually installed: `codex login`. Default: skip with the "not supported on Windows yet" banner if `--with-codex` was passed, since the prior stage didn't install it.
  - GUI sign-ins (since Windows = Mac scope): "Open Antigravity from the Start menu" + "Open Claude Desktop from the Start menu". Use `Start-Process` if user wants the script to launch the apps directly, but default is just text instructions.
  - Heading: "Installed tooling is in place — complete each step below."
- **Verification:** AST parse clean. On Windows VM: 5 numbered items default (claude, gh, gemini, Antigravity, Claude Desktop). With `WITH_CODEX=1`: 6 items (+ codex). Output is plain text, no errors.
- **Status:** [x] (2026-04-29: scripts/auth-checklist.ps1 rewritten from stub. Always 5 numbered items on Windows: claude login, gh auth login, gemini (first run), Open Antigravity from Start menu, Open Claude from Start menu. Codex on Windows is skip-only regardless of WITH_CODEX (install-clis.ps1 doesn't install it), so the list size doesn't grow with WITH_CODEX=1 — instead a Codex note appears at the end with a different message depending on opt-in: `WITH_CODEX=1` mentions openai/codex#18648 and the Mac/Linux-only status; default mentions the flag exists. Steps built into a `[pscustomobject]` array with auto-numbering. PowerShell-native string formatting; no jq/bash artifacts. Local pwsh AST parse not run; CI AST step is the gate; runtime exercise lands at task 8.)

### 7. `setup.ps1` — orchestrator real-stage wiring

- **What:** The orchestrator already exists from `feat-debian-cli-support`'s task 9 (Windows stubs). It's already structured around stages; this task confirms the stage list points at the now-real `.ps1` files and adds `--with-codex` to its arg-parsing (mirror of the bash version). Inline OS detection (no `scripts\lib\os.ps1` helper needed; Windows is the only OS this script handles). Add `-Help` text describing the new stages.
- **Verification:** `setup.ps1 -Help` lists all 6 stages (`tooling`, `clis`, `gui-apps`, `link-configs`, `verify-install`, `auth-checklist`). `setup.ps1 -DryRun` exits 0 with paths. `setup.ps1 -SkipApps` filters out `gui-apps` AND exports `SKIP_APPS=1`. `setup.ps1 -WithCodex` exports `WITH_CODEX=1`.
- **Status:** [x] (2026-04-29: setup.ps1 stage list updated — `brew` renamed to `tooling` (script `install-tooling.ps1`); all six Desc strings rewritten to reflect the now-real installer behaviors. Added `-WithCodex` switch parameter; both `-SkipApps` and `-WithCodex` set `$env:SKIP_APPS` and `$env:WITH_CODEX` respectively (mirrors `setup.sh`'s `export` of the same vars). Help text updated to list all flags incl. the Codex caveat citing `openai/codex#18648`. Dead `scripts/install-brew.ps1` stub deleted; six .ps1 stage scripts now in place. Local pwsh AST parse not run (pwsh missing); harness verify.sh accepts. CI's AST step is the gate; runtime end-to-end exercise lands at task 8 once the workflow is upgraded to use `-SkipApps` etc.)

### 8. `.github/workflows/ci-tests.yml` — windows-test upgrade from smoke to real

- **What:** Replace the windows-test job's smoke steps with a real install pipeline parallel to the Mac job:
  1. `actions/checkout@v4`.
  2. `./setup.ps1 -Help` exits 0 with the 6-stage list.
  3. `./setup.ps1 -DryRun` exits 0.
  4. `./setup.ps1 -SkipApps` end-to-end (CI runners can't sign into Antigravity / Claude Desktop, so we skip GUI installs the same way the Mac job does). Note: the Windows GUI apps could *technically* be winget-installed in CI (no auth required for the install itself), but verifying them takes a human, so `-SkipApps` matches the Mac-CI posture.
  5. Assert `verify-install.ps1` reports `0 warn` (with `SKIP_APPS=1` env).
  6. **Idempotency**: re-run `./setup.ps1 -SkipApps`; assert `git status` is clean.
  7. **`--with-codex` variant**: `./setup.ps1 -SkipApps -WithCodex`. **Important:** with the default skip-with-warn behavior, this should still exit 0 (Codex stage skipped cleanly). The assertion is "exit 0", not "codex resolves on PATH" — that test only fires if open question 1 resolves to "GitHub-Release fallback".
  8. **AST-parse all `.ps1` files** (preserved from the smoke job — still useful as a regression catch).
- **Verification:** Local: actionlint clean. After commit + dispatch: windows-test job goes green end-to-end. The same `git status` idempotency assertion the Mac/Ubuntu jobs use catches drift.
- **Status:** [x] (2026-04-29: ci-tests.yml windows-test rewritten from smoke to full install pipeline. Eight steps now (was five): checkout, `-Help` smoke + grep for `tooling` and `auth-checklist`, `-DryRun`, end-to-end `-SkipApps`, `verify-install` 0-warn assertion (with `SKIP_APPS=1` env explicit per the Mac job's pattern), idempotency `git status --porcelain` empty assertion, `-SkipApps -WithCodex` exits 0 cleanly + asserts `codex` is **NOT** on PATH (Windows skip-with-warn invariant), AST-parse-all-.ps1 preserved as regression catch. Job timeout bumped from 10m to 30m to match the Mac job's full-install budget. Job name: "Windows smoke" → "Windows" (no longer smoke). **CI verified green** on run 25142962483 after five iterations of fixes — bugs caught: (a) `Write-Host` Information-stream output not captured into `$var = ...` assignments (fix: `6>&1` redirect on the Help and verify-install steps); (b) `"$Desc:"` parser error in verify-install.ps1 (PowerShell read it as scoped-variable reference; fix: `${Desc}:`); (c) winget-installed binaries in user-PATH registry not visible to setup.ps1's child stage processes (fix: registry refresh in setup.ps1's stage loop); (d) same registry-staleness on the workflow's verify-install step shell (fix: registry refresh at step start); (e) `verify.out` written into repo working dir caused untracked-file drift in idempotency check (fix: tee to `$env:RUNNER_TEMP` matching Mac/Linux's `/tmp`). All five were real correctness wins surfaced by CI doing its job.)

### 9. Docs + close-out

- **What:** Two parts:
  - **`docs/windows.md` rewrite**: drop the "deferred / per-stage TODO" framing. Add: quick-start, supported-Windows-version table (Windows 10 1809+, Windows 11), winget-as-prereq note, Codex-not-supported-yet note (citing the npm bugs), Claude Desktop config-management punt explanation (citing claude-code#26073), Developer-Mode toggle for symlinks, Antigravity argv.json path resolution.
  - **README**: Status section flipped from "Windows: deferred" to "Windows: ready (full GUI + CLI, full parity with Mac)". Layout block updated to reflect real .ps1 scripts. New Windows row in the badges line if a per-platform CI job badge exists, otherwise the existing CI badge covers all three jobs.
  - **`features.json` close-out** *(after CI green)*: `feat-windows-cli-support.passes` → `true`. v1.1.0 release (minor bump — additive, no breaking changes from v1.0.0).
- **Verification:** `docs/windows.md` exists and references all 6 .ps1 stage files; broken-link check via the same grep + find pattern as the prior plan. README shows the three platforms ready/ready/ready (or ready/ready/CLI-only-on-Linux/ready). `features.json` valid; `feat-windows-cli-support.passes == true`. v1.1.0 tagged + released.
- **Status:** [x] (2026-04-29: docs/windows.md rewritten — drops the "deferred / TODO stubs" framing entirely. New content: quick-start with `-WithCodex` variant, supported-Windows-version table (Windows 10 1809+, Windows 11, PowerShell 7+, amd64+arm64), stage list, Codex-not-supported-yet section citing openai/codex#18648 and #11744, winget-vs-native-installer trade-off note for Claude Code with the dedupe-footgun warning (claude-code#31980), Developer-Mode-symlink toggle instructions, MSIX-redirect-mess Claude Desktop config rationale (claude-code#26073), Gemini Desktop "no first-party app" justification, file layout, future-work pointers (Antigravity argv.json empirical, Codex when fixed, capture.ps1, etc.), reference links. README Status section flipped Windows from "deferred" to "ready (full GUI + CLI, mirrors Mac scope)". README Testing section rewritten: drops the "Windows smoke" framing and the "Real Windows install verification (beyond smoke) is the immediate next plan" paragraph since that next plan is now this complete plan. features.json: feat-windows-cli-support.passes flipped to true. PLAN.md plan-level Status: in progress → complete. v2.0.0 ships next — major bump because the Windows path going from smoke-only to fully install-verified is a breaking change in user expectations (users on v1.x with Windows would have hit the stubs, which printed TODO and exited 0; on v2.0.0 they hit the real installer that actually does work).)

## Risks / open questions

All three resolved on 2026-04-29:

1. ~~**Codex on Windows: skip-with-warn or GitHub-Release fallback?**~~ **Resolved → skip-with-warn.** Default applies. `--with-codex` on Windows prints `==> Codex CLI: skipped (not supported on Windows yet — see openai/codex#18648)` and continues without erroring. Mac and Linux still install Codex normally. Revisit when OpenAI fixes the npm package.

2. ~~**Claude Code Windows install method: native installer or winget?**~~ **Resolved → winget.** Override of the original recommendation; user prefers system-managed installs over auto-updating curl-style. `winget install -e --id Anthropic.ClaudeCode`. Constraints section updated. Native `irm | iex` documented in `docs/windows.md` as the alternative for users who want auto-updates. Installing both is a footgun (claude-code#31980); the script doesn't.

3. ~~**Antigravity `argv.json` path on Windows.**~~ **Resolved → verify-empirically-then-fall-back-to-skip.** Default applies. /work task 4 (`link-configs.ps1`) starts by trying `%USERPROFILE%\.antigravity\argv.json` (VSCode-fork convention). If empirical testing on a Windows host confirms a different path, switch to that. If neither path holds, drop the `argv.json` placement on Windows entirely (Antigravity falls back to defaults on first launch — usability nicety, not a hard requirement) and document the call.

## Verification strategy

- Per-task verification commands above are the per-task gates.
- Whole-plan gate: a single manual CI dispatch where all three jobs (`macos-test`, `ubuntu-test`, `windows-test`) go green simultaneously **with the windows-test job exercising the real install pipeline** (not the smoke-only steps that shipped in `feat-ci-verification`).
- After the plan completes: `feat-windows-cli-support.passes=true`; v1.1.0 release. The smoke-only acknowledged gap from v1.0.0's release notes is closed.

## Follow-on work (not in this plan)

- **`scripts/capture.ps1`**: Windows mirror of `scripts/capture.sh`. Useful if a user wants to re-sync live Windows configs back into the repo. Out of scope here since we reuse the Mac-captured platform-agnostic JSONs.
- **WSL Ubuntu detection in setup.sh**: currently WSL Ubuntu hits the existing Debian path, which works. If we ever want WSL-specific behavior (e.g., point at Windows-hosted browsers for oauth instead of trying to launch one inside WSL), that's a separate plan.
- **Claude Desktop config management on Windows**: the MSIX-redirect mess. Solveable (detect MSIX vs Electron install, write to the redirected path) but punted from v1 of this plan.
