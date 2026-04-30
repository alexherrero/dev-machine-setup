# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Repository visibility flipped to public** (`feat-curl-bash-installer` task 4). Six-track pre-public audit (task 1) found 0 secrets in tree or git history, 0 API-key-shaped patterns; one hardcoded `/Users/alex/` path in the gitignored project-local file was genericized; four `/setup`-seeded placeholder wiki pages were dropped; three stale wiki status lines were bumped to v2.0.0. New `static-analysis` CI job (task 3) gates future PRs against regression: shellcheck, actionlint, pwsh AST parse, lychee link-check on user-facing docs, secret-scan + personal-data regex, LICENSE non-empty check.

### Added
- **`LICENSE`** at repo root — MIT, Copyright (c) 2026 Alex Herrero. README gained `## License` section.
- **`static-analysis` CI job** in `.github/workflows/ci-tests.yml` — parallel to mac/ubuntu/windows-test on ubuntu-latest. Six steps; ~12 sec runtime; the named gate every remaining task in `feat-curl-bash-installer` references. End-to-end CI green on [run 25150482876](https://github.com/alexherrero/dev-machine-setup/actions/runs/25150482876).

## [v2.0.0] — 2026-04-29

> **Windows is now real.** `feat-windows-cli-support` is complete with `passes: true` in `.harness/features.json`. All three features (Mac, Debian/Ubuntu, Windows) are CI-verified end-to-end on a single dispatch — [run 25142962483](https://github.com/alexherrero/dev-machine-setup/actions/runs/25142962483). Major bump: Windows users on v1.x hit the stub-only path (printed TODO + exited 0); on v2.0.0 they hit the real installer that actually does work. No API surface changed, but user expectations did.

### Added
- **`scripts/install-tooling.ps1`** — winget toolchain installer. Git for Windows (required by Claude Code — shells out to Git Bash), Node LTS, gh, ripgrep. Idempotent skip-if-on-PATH; PATH refresh from registry into running shell. Shipped at v1.1.0; finalized here.
- **Real `scripts/install-clis.ps1`** — Claude Code via `winget install Anthropic.ClaudeCode`; Gemini via `npm install -g @google/gemini-cli`; Codex skip-with-warn (cites `openai/codex#18648` and `#11744` — npm package broken on Windows). `Update-PathFromRegistry`, `Add-DirToUserPath`, `Test-NodeVersion` helpers. Hard-fails if Node < 20.
- **Real `scripts/install-gui-apps.ps1`** — winget Antigravity Desktop + Claude Desktop. Single `Install-WingetApp` helper with `NO_APPLICATIONS_FOUND` skip-with-manual-URL-fallback. Gemini Desktop explicitly skipped (no first-party Windows app).
- **Real `scripts/link-configs.ps1`** — symlink-with-copy-fallback for `CLAUDE.md` (handles `UnauthorizedAccessException` when Dev Mode is off). Copy-if-absent for JSON configs at Windows-native paths. Co-Authored-By kill-switch merge via `ConvertFrom-Json` / `ConvertTo-Json` roundtrip. Explicit skip with rationale for the MSIX-redirected Claude Desktop config (`claude-code#26073`).
- **Real `scripts/verify-install.ps1`** — two-tier health check (global + harness). Eight approved-verb helpers including `Test-WindowsApp` (registry uninstall-key search across HKLM + HKLM\WOW6432Node + HKCU). Codex skip-only regardless of `WITH_CODEX`; `SKIP_APPS=1` consolidates GUI checks.
- **Real `scripts/auth-checklist.ps1`** — five numbered items on Windows (claude, gh, gemini, Antigravity, Claude Desktop); Codex note appended with `WITH_CODEX`-aware messaging.
- **`-WithCodex` flag** on `setup.ps1`. Mirrors `setup.sh`'s `--with-codex`. Sets `$env:WITH_CODEX=1` for sub-stages. (Note: Codex is currently skip-with-warn on Windows even with the flag set.)

### Changed
- **`setup.ps1`** stage list: `brew` → `tooling` (script `install-tooling.ps1`). `-SkipApps` now also exports `$env:SKIP_APPS=1` for sub-stages (matches `setup.sh`'s `export SKIP_APPS`). PATH refreshed from the registry between every stage so child processes see what prior stages installed via winget.
- **`.github/workflows/ci-tests.yml`** windows-test job upgraded from **smoke-only** (orchestrator + AST parse, ~25 sec) to **full install pipeline** (~6 min) parallel to the Mac/Ubuntu jobs: `-Help` smoke + grep, `-DryRun`, end-to-end `-SkipApps`, verify-install 0-warn assertion (with `SKIP_APPS=1` env explicit), idempotency `git status` check, `-SkipApps -WithCodex` exits 0 + asserts `codex` is **NOT** on PATH (Windows skip-with-warn invariant), AST-parse-all-.ps1 preserved.
- **`docs/windows.md`** rewritten end-to-end. Drops the "deferred / TODO stubs" framing. New content: quick-start, supported-version table, Codex-not-supported section, winget-vs-native-installer trade-off, Developer-Mode toggle instructions, MSIX-mess rationale.
- **`README.md`** Status section: Windows flipped from "deferred" to "ready (full GUI + CLI, mirrors Mac scope)". Testing section drops the smoke framing.

### Fixed
- **`Write-Host` capture failure** in CI assertions. Both `setup.ps1 -Help` and `verify-install.ps1` use `Write-Host` exclusively, which writes to the Information stream (#6) and bypasses the success pipeline. Variable assignments captured nothing → assertions falsely fired. Fix: `6>&1` redirect.
- **`"$Desc:"` parser error** in `scripts/verify-install.ps1`. PowerShell parsed `$Desc:` as a scoped-variable reference (`:` is the scope separator). Fix: `${Desc}:` to delimit explicitly.
- **PATH propagation across setup.ps1 stages.** winget installs registered in user PATH (registry), but child stage processes inherited setup.ps1's stale `$env:Path` (captured at orchestrator start). Fix: refresh PATH from registry inside setup.ps1's per-stage loop.
- **PATH propagation across CI steps.** Fresh GH Actions step shells inherit the runner agent's PATH (captured at service start, before our installs). Fix: refresh PATH at the top of the verify-install step.
- **Untracked `verify.out`** caused idempotency drift in CI. The Windows job's `Tee-Object -FilePath verify.out` wrote into the repo working dir; the next step's `git status --porcelain` saw it as untracked. Fix: tee to `$env:RUNNER_TEMP` (matches Mac/Linux's `/tmp`).

### Closed out
- `feat-windows-cli-support.passes` → `true`.
- All three features now pass; the project's stated cross-platform contract is fully realized.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v1.1.0...v2.0.0

## [v1.1.0] — 2026-04-29

> ⚠️ **Mid-feature release.** Tasks 1–6 of 9 done for `feat-windows-cli-support`. Mac and Debian paths are unchanged and stable. The six Windows `.ps1` scripts are now real implementations (no longer stubs), but `setup.ps1` still wires up to the *old* stub names (`install-brew.ps1` etc.) — task 7 renames the stages to point at the new files. Until then the new scripts exist on disk but aren't reachable via `setup.ps1`. **Stay on v1.0.0 if you're using Windows now**; this tag is incremental tagging hygiene only. v2.0.0 ships when CI's windows-test goes green end-to-end (real install pipeline, task 8) and `feat-windows-cli-support.passes=true` lands (task 9).

### Added
- **`scripts/install-tooling.ps1`** — Windows equivalent of `install-brew.sh` / `install-apt.sh`. Pre-flight winget existence check; installs Git.Git (required by Claude Code — shells out to Git Bash), OpenJS.NodeJS.LTS, GitHub.cli, BurntSushi.ripgrep.MSVC. Skips jq (PowerShell native `ConvertFrom-Json`), shellcheck, shfmt (no bash on Windows). Idempotent skip-if-on-PATH; PATH refresh from registry into running shell; post-check loop verifies five binaries.
- **`scripts/install-clis.ps1`** rewritten from stub. Claude via `winget install Anthropic.ClaudeCode`; Gemini via `npm install -g @google/gemini-cli`; **Codex skip-with-warn on Windows** (cites `openai/codex#18648` and `#11744` — upstream npm package broken). Three approved-verb helpers (`Update-PathFromRegistry`, `Add-DirToUserPath`, `Test-NodeVersion`) plus a Node ≥ 20 hard-fail guard.
- **`scripts/install-gui-apps.ps1`** rewritten from stub. Antigravity Desktop (`Google.Antigravity` — winget id unconfirmed in Google's docs; falls back to skip-with-warn + manual-URL pointer if winget can't find it), Claude Desktop (`Anthropic.Claude` — distinct from `Anthropic.ClaudeCode`). Gemini Desktop explicitly skipped (no first-party Windows app).
- **`scripts/link-configs.ps1`** rewritten from stub. Five PowerShell-native helpers (`Backup-IfNeeded`, `Set-RepoSymlink` with copy-fallback on `UnauthorizedAccessException`, `Copy-RepoFileIfAbsent`, `Merge-Gitconfig`, `Set-ClaudeCoAuthoredByDisabled`). Symlink-with-copy-fallback for `CLAUDE.md` (Dev Mode toggle documented); copy-if-absent for the three JSON configs at Windows-native `%USERPROFILE%\.claude\`, `\.gemini\`, `\.antigravity\` paths. Antigravity `argv.json` placed at the VSCode-convention path pending empirical verification on a Windows runner. Co-Authored-By kill-switch merge via `ConvertFrom-Json` / `ConvertTo-Json` roundtrip (no jq dep). Explicit skip with rationale for the MSIX-redirected Claude Desktop config (`claude-code#26073`).
- **`scripts/verify-install.ps1`** rewritten from stub. Two tiers (global + harness). Eight approved-verb helpers including `Test-WindowsApp` (registry uninstall-key search across HKLM + HKLM\WOW6432Node + HKCU). Codex skip-only regardless of `WITH_CODEX`; `SKIP_APPS=1` consolidates GUI app checks; symlink-or-copy both accepted as OK. PostToolUse hook check via `ConvertTo-Json -Compress` + regex match for `verify\.sh`.
- **`scripts/auth-checklist.ps1`** rewritten from stub. Always 5 numbered items on Windows (claude, gh, gemini, Antigravity, Claude Desktop); Codex note appended at end with `WITH_CODEX`-aware messaging (no numbered codex login step since install-clis.ps1 doesn't install it).

### Plan
- New feature `feat-windows-cli-support` in `.harness/features.json` (`passes: false` until CI green). Three open questions surfaced and resolved during planning: (1) Codex Windows → skip-with-warn; (2) Claude Code install → winget (override of original native-installer recommendation, per user preference for system-managed installs); (3) Antigravity `argv.json` path → verify empirically with skip-the-file fallback.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v1.0.0...v1.1.0

## [v1.0.0] — 2026-04-29

> **First stable release.** Both `feat-debian-cli-support` and `feat-ci-verification` are complete with `passes: true` in `.harness/features.json`. The Mac and Debian/Ubuntu paths are end-to-end CI-verified on a single dispatch — [run 25087515129](https://github.com/alexherrero/dev-machine-setup/actions/runs/25087515129) (macOS 1m34s, Ubuntu 1m20s, Windows-smoke 0m25s, all `success`). Windows is **smoke-only** (orchestrator + AST parse); real Windows install verification is the next plan, `feat-windows-cli-support`.

### Added
- **`.github/workflows/ci-tests.yml`** — manually-dispatched CI workflow with three parallel jobs:
  - **`macos-test`** (`macos-latest`) runs `setup.sh --skip-apps` end-to-end (GUI installer needs a human, hence skipped). Asserts `verify-install` reports zero warns, idempotency on re-run, and that `--with-codex` actually installs Codex.
  - **`ubuntu-test`** (`ubuntu-latest`) runs `setup.sh` end-to-end including the full apt path (NodeSource node 22 LTS, GitHub CLI repo, all six apt packages). Asserts zero warns, idempotency, `--with-codex`, and a negative test that the Mac-only `~/Library/Application Support/Claude/` is **not** created on Linux.
  - **`windows-test`** (`windows-latest`) is smoke-only: orchestrator stubs run cleanly + every `.ps1` AST-parses.
  Triggered by `workflow_dispatch` only — no push, no PR, no schedule. Workflow-level `concurrency: cancel-in-progress` so a second dispatch on the same ref supersedes the older run. README has a CI status badge + `## Testing` section explaining the manual-dispatch flow.
- **`SKIP_APPS=1` env-var pattern** in `setup.sh` and `verify-install.sh`. Mirrors `WITH_CODEX`. When `--skip-apps` is passed, `verify-install.sh` consolidates the three `/Applications/*.app` checks + the Mac-only Claude Desktop config check into a single `[SKIP] /Applications/*.app + Claude Desktop config (--skip-apps was set)` line, so a CI Mac run with `--skip-apps` reports `0 warn` instead of false-WARNing on apps it deliberately didn't install.

### Fixed
- **NodeSource apt key signature failure on Debian.** `install-apt.sh::install_keyring` was writing the upstream URL's response verbatim via `tee`. NodeSource serves the key ASCII-armored at `.gpg.key` while modern apt with `signed-by=/etc/apt/keyrings/...gpg` expects the file to be **dearmored binary**, so `apt update` failed with `NO_PUBKEY 2F59B5F99B1BE0B4`. Helper now takes an `armored` flag; NodeSource pipes through `gpg --dearmor` before write. GitHub CLI's URL serves binary already → unchanged.
- **`includeCoAuthoredBy` kill-switch missing on fresh Macs.** On a fresh-install Mac, the Claude Code installer (or its first `claude --version` invocation in `install-clis.sh`'s post-check) writes a default `~/.claude/settings.json` *before* `link-configs.sh` runs. `link_copy_if_absent` then preserves the default file and our captured kill-switch from `configs/claude/settings.json` never lands. New `link-configs.sh::ensure_claude_co_authored_by_disabled()` merges `includeCoAuthoredBy=false` into whatever's on disk via a `jq`-driven temp-file rename. Idempotent: already-false is a no-op print.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v0.6.1...v1.0.0

## [v0.6.1] — 2026-04-28

### Changed
- **Wiki**: `feat-debian-cli-support` close-out (task 8/8). New `wiki/how-to/Bootstrap-A-New-Debian-Or-Ubuntu.md` (links out to `docs/debian.md` rather than duplicating; cites `antigravity.google/docs/command` for the GUI-only-on-Linux rationale). `wiki/how-to/Bootstrap-A-New-Mac.md` flipped pending → implemented (v0.1.0). `wiki/explanation/Dev-Machine-Setup-Design.md` rewritten for the cross-platform OS-dispatch architecture with per-component Mac/Debian comparison table and Trade-offs covering GUI-only-on-Linux, the shared-scripts architecture, the `rc_file()` helper, and the Codex opt-in. `wiki/Home.md` + `wiki/_Sidebar.md` index the new page. All 9 flat-namespace wiki links resolve.
- **`.harness/PLAN.md`** plan-level Status flipped from "in progress" to "complete pending VM verification". All 8 tasks marked `[x]`. `features.passes` stays `false` (per plan contract — flips only after a real Debian VM run, scheduled for `/release`-gate).

> No code changes vs v0.6.0. The Debian path is feature-complete via static verification but **still has not been exercised on a real Debian/Ubuntu host**. Same "should work but unverified" caveat as v0.6.0 applies. Mac users on v0.2.0+ are unaffected.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v0.6.0...v0.6.1

## [v0.6.0] — 2026-04-28

> **First Debian-runnable release.** Tasks 1–7 of 8 done for `feat-debian-cli-support`. The Mac path is unchanged and stable. The Debian path is now feature-complete end-to-end via static verification (forced `OS=debian` dispatch on Mac dev box across every stage) but **has not yet been exercised on a real Debian VM** — task 8 closes that out and flips `features.passes=true`. Treat v0.6.0 as "should work but unverified" on actual Debian/Ubuntu hosts. Mac users on v0.2.0+ are unaffected.

### Changed
- **`scripts/verify-install.sh`** is now cross-platform. `brew` is Mac-only; `/Applications/*.app` checks (Antigravity / Gemini / Claude) and the `~/Library/.../claude_desktop_config.json` JSON validity check are gated on `OS==macos` (one consolidated `[SKIP]` line on Debian). Codex PATH check + `--version` smoke test are gated on `WITH_CODEX==1` — when off, both emit `[SKIP] codex … (set WITH_CODEX=1 to include Codex CLI)` rather than a false-alarm WARN. `check_zshrc_marker` → `check_rc_marker` via shared `rc_file()` so Debian-with-bash inspects `~/.bashrc`. Banner shows `OS=$OS`. Mac default output is unchanged: 30 ok / 0 warn baseline preserved exactly.
- **`scripts/auth-checklist.sh`** is now cross-platform. Steps built dynamically into a single array with auto-numbering. GUI sign-in steps (`open -a Antigravity`, `open -a Claude`) appended only when `OS==macos`. Codex `login` step (verified against `npx @openai/codex --help`, which exposes a `login` subcommand) appended only when `WITH_CODEX==1`; default-off prints a one-line "(Codex CLI step omitted — pass --with-codex to setup.sh to include it.)". Heading text differs per OS: Mac says "Installed tooling is in place"; Debian says "CLI install complete (no GUI apps on Debian — that's by design)" so the GUI omission on Linux is deliberate, not a bug. Banner shows `OS=$OS`.
- **`docs/first-run.md`** rewritten with two subsections (`## Mac`, `## Debian / Ubuntu`); the optional Codex step documented in both; trailing "What `setup.sh` leaves behind" now flags platform-specific paths explicitly (Claude Desktop config Mac-only; `~/.bashrc` on Debian-with-bash; `~/.npm-global/bin` Debian-only).
- **`README.md`** reframed for Mac (full GUI + CLI) or Debian / Ubuntu (CLI-only). Three platform subsections under Usage (`### macOS`, `### Debian / Ubuntu`, `### Windows`); both Mac and Debian show `--with-codex` as the opt-in install. Layout block expanded to show the per-script tree (`lib/os.sh`, `install-brew`/`install-apt` split, etc.). Status section: Mac ready / Debian ready / Windows deferred.

### Added
- **`docs/debian.md`** — supported-distro matrix (Debian 11/12/13 Bullseye/Bookworm/Trixie; Ubuntu 20.04/22.04/24.04 LTS) with per-release `shfmt`-source column (apt vs GitHub-release fallback); amd64 + arm64 both supported. Debian-flavored stage list, "What's omitted vs Mac" comparison, the explicit "Why Antigravity isn't supported on Linux" callout citing Google's own `antigravity.google/docs/command` docs (`agy` is a desktop-IDE launcher, not a headless agent), toolchain detail (NodeSource node 22 LTS, GitHub CLI apt repo, npm-globals-without-sudo via `~/.npm-global` prefix, shfmt fallback), and a future-work section.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v0.5.0...v0.6.0

## [v0.5.0] — 2026-04-27

> ⚠️ **Mid-feature release.** Tasks 1–4 of 8 done for `feat-debian-cli-support`. Mac path is unchanged and stable. The Debian path now runs through `apt → clis → link-configs` cleanly — no Mac-flavored paths get written into the Linux home. `verify-install.sh` and `auth-checklist.sh` still have Mac-only assumptions (`/Applications/*.app` checks, GUI sign-in steps); end-to-end Debian readiness lands with task 7. Stay on **v0.2.0 for production Mac use** until this feature ships in full.

### Changed
- **`scripts/lib/os.sh`** now also exports `rc_file()` — returns the rc file PATH-marker writes should target. Mac → `~/.zshrc`; Debian → `~/.zshrc` if `$SHELL` ends in `/zsh`, else `~/.bashrc`. Centralized so `install-clis.sh` and `link-configs.sh` route to the same file.
- **`scripts/install-clis.sh`** uses the shared `rc_file()` instead of its own local copy from v0.4.0.
- **`scripts/link-configs.sh`** sources `os.sh`. The Mac-only Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`) is now gated on `OS==macos` — on Debian the entry prints `skip ... (Mac-only — Claude Desktop)` and the path is never created. Post-check JSON validation drops the Library path on Debian too. `append_zshrc_additions` renamed to `append_shell_additions` since the destination is now `rc_file()`-driven (the old name was misleading on Debian-with-bash, where the additions go to `~/.bashrc`). All other strategies (CLAUDE.md symlink, Claude / Gemini / Antigravity JSONs, `git config --global` user.name/email merge) are platform-portable as-is and behave identically on both platforms.

**Full diff:** https://github.com/alexherrero/dev-machine-setup/compare/v0.4.0...v0.5.0

## [v0.4.0] — 2026-04-27

> ⚠️ **Mid-feature release.** Tasks 1–3 of 8 done for `feat-debian-cli-support`. Mac path is unchanged and stable. The Debian path now has the `apt` install stage and a cross-platform `install-clis.sh`, so `OS=debian ./setup.sh` runs further than it did at v0.3.0 — but `link-configs.sh`, `verify-install.sh`, and `auth-checklist.sh` still have Mac-only assumptions (Claude Desktop config path, `/Applications/*.app` checks, GUI sign-in steps). End-to-end Debian readiness lands with task 7. Stay on **v0.2.0 for production Mac use** until this feature ships in full.

### Added
- **`scripts/install-apt.sh`** — Debian/Ubuntu equivalent of `install-brew.sh`. Adds two third-party apt repos with explicit keyrings (NodeSource for Node.js 22 LTS — apt's `nodejs` is too old for Gemini CLI; GitHub CLI's official repo for `gh`) and installs `nodejs`, `gh`, `jq`, `ripgrep`, `shellcheck`, `shfmt`. `shfmt` is in apt on Debian 12+ / Ubuntu 24.04+; on older releases the script falls back to fetching the matching GitHub-release binary into `/usr/local/bin/shfmt` (release tag resolved via `/releases/latest` HTTP redirect — no jq dependency, since we may be installing jq in the same run). Architecture-aware (`dpkg --print-architecture` for the `gh` repo `arch=` clause and the `shfmt` fallback URL). Idempotent: keyring/sources.list writes are guarded; apt install naturally skips installed packages. Defensive Mac guard exits 2 before any `sudo` if `OS != debian`.
- **`--with-codex`** flag on `setup.sh` — opt-in install of OpenAI Codex CLI (`@openai/codex`), default off. Sets `WITH_CODEX=1` for the `install-clis` stage. The flag intentionally exists at the top-level orchestrator so users opt in once at the entry point, not inside a sub-script.

### Changed
- **`scripts/install-clis.sh`** is now cross-platform (sources `scripts/lib/os.sh`). Per-OS rc-file picker writes `~/.zshrc` on Mac (captured shell), `~/.zshrc` if `$SHELL` ends in `/zsh` on Debian else `~/.bashrc`. Debian-only logic: configures a user-local npm prefix at `~/.npm-global` (so `npm install -g` works without sudo) with idempotent PATH append, and hard-fails if `node --version` < 20 with a pointer to `install-apt.sh`. Mac path unchanged. Codex install + post-check entry are gated on `WITH_CODEX==1` — default runs print `==> Codex CLI: skipped (pass --with-codex to setup.sh to include)` and the binary-on-PATH check verifies only `claude` + `gemini` (no false `codex MISSING`).

## [v0.3.0] — 2026-04-27

> ⚠️ **Mid-feature release.** This is task 1 of 8 for `feat-debian-cli-support`. The Mac path is unchanged and stable. The Debian path is **not yet runnable end-to-end** — `OS=debian ./setup.sh` will warn-skip the not-yet-existent `install-apt.sh` and then fail at `install-clis.sh` (still Mac-only until task 3). Stay on **v0.2.0 for production Mac use**; this tag exists for incremental tagging hygiene only.

### Added
- `scripts/lib/os.sh` — sourced helper that exports `$OS` (`macos` | `debian`) based on `uname -s` plus `/etc/debian_version` / `lsb_release` probes. Anything else exits 2 with a descriptive error (uname, kernel rev, `/etc/os-release` ID + PRETTY_NAME). External `$OS` overrides are validated against the allowed values so `OS=plan9 ./setup.sh` exits 2 rather than silently dispatching to the Debian branch. Tests can force the Debian path on a Mac with `OS=debian ./setup.sh --dry-run`.
- `setup.sh` — sources the OS helper and builds platform-specific `STAGE_NAMES` / `STAGE_SCRIPTS` / `STAGE_DESCS` arrays. Mac plan unchanged: `brew → clis → gui-apps → link-configs → verify-install → auth-checklist`. Debian plan: `apt → clis → link-configs → verify-install → auth-checklist` (no GUI stage — Antigravity is GUI-only by design and out of scope; CLI-only Debian flow). `--help` shows the detected OS and the per-OS stage list. `--only` validates against the per-OS list (so `--only gui-apps` correctly errors on Debian).

## [v0.2.0] — 2026-04-27

### Added
- `scripts/verify-install.sh` + Windows stub — warn-only post-setup health check that runs after `link-configs` and before `auth-checklist`. Two tiers: **global** (PATH binaries, GUI app bundles, captured-config validity, `~/.zshrc` PATH marker, `claude`/`gemini --version` smoke tests, the `includeCoAuthoredBy` kill-switch, global agents/skills dirs); **harness** (only when CWD has `.harness/` — verifies PLAN.md / progress.md / features.json, `.harness/verify.sh` is executable, project `.claude/{agents,skills,commands}` populated, `PostToolUse` hook references `.harness/verify.sh`). Each check prints `[ OK ]` / `[WARN]` / `[SKIP]`; always exits 0 so the bootstrap never halts on an advisory failure. Manual auth steps stay in `auth-checklist.sh` since they can't be machine-verified.
- `configs/claude/CLAUDE.md` — global Claude Code instruction telling Claude not to append `Co-Authored-By: Claude …` trailers to commits. Symlinked into `~/.claude/CLAUDE.md` by `link-configs.sh`, so every fresh Mac inherits the rule. History on this repo (and on `agentic-harness` and `sherwood`) was retroactively scrubbed.

### Changed
- `configs/claude/settings.json` + project `.claude/settings.json` set `includeCoAuthoredBy: false` — the canonical Claude Code kill-switch for the trailer. Belt-and-braces alongside the CLAUDE.md instruction.
- README: Claude / Gemini / Antigravity badges next to the title; Usage section split into `macOS / Linux` and `Windows` subsections with refresh-PATH commands for both shells.

## [v0.1.0] — 2026-04-23

### Added
- `setup.sh` orchestrator — runs install stages in order with `--dry-run`, `--skip-apps`, `--only <stage>`, and `--help`. Missing stage scripts warn+skip (supports in-progress plans); `set -euo pipefail` + direct invocation halts on first real failure.
- `scripts/link-configs.sh` — places captured configs at OS locations via four per-file strategies: symlink for user-authored files (`CLAUDE.md` only); copy-if-absent for app-owned JSON (Claude Code and Claude Desktop both confirmed to rewrite in place); append-idempotent under a marker for `~/.zshrc`; `git config --global` merge for `user.name`/`user.email` (preserves existing includes, credential helpers, signing config). Pre-existing files move to `~/.dev-machine-setup-backup/<utc>/`; backup dir is lazy-created so converged reruns leave no trace. JSONC-aware validation for `argv.json`.
- `scripts/auth-checklist.sh` + `docs/first-run.md` — post-setup checklist of the 5 manual steps (`claude login`, `gh auth login`, `gemini` first-run oauth, Antigravity sign-in, Claude Desktop sign-in) + a doc that traces each command to the install stage that provisioned it.
- `setup.ps1` + `scripts/install-*.ps1` + `docs/windows.md` — Windows orchestrator skeleton matching the Mac flag shape, five per-stage stubs, and a deferral doc with per-stage remaining-work table. AST validation deferred to a Windows reference VM.

### Changed
- First release using conventional-commit `feat:` prefixes so the `ship-release` skill classifies feature drops as **minor** bumps (v0.0.5 → v0.1.0) instead of defaulting to **patch**. Calibration applied mid-session; prior v0.0.1–v0.0.5 releases used `setup:` prefixes that fell through the classifier.

## [v0.0.5] — 2026-04-23

### Added
- `scripts/install-clis.sh` — installs the two non-brew CLIs in one pass: Claude Code CLI via Anthropic's official curl installer pinned to the `stable` channel (lands at `~/.local/bin/claude`), and Gemini CLI as an npm global (`@google/gemini-cli`, requires node from `install-brew.sh`). Idempotent-appends `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` with a marker comment so future shells find `claude`.
- `scripts/install-gui-apps.sh` — browser-assisted installer for Antigravity, Gemini Desktop, and Claude Desktop. Direct-curl download of the DMGs was investigated and found infeasible (Claude's `claude.ai/api/desktop/darwin/universal/dmg/latest/redirect` sits behind a Cloudflare JS challenge that returns 403 to curl; Antigravity and Gemini Desktop have no discoverable direct-DMG URL). For each missing app, the script `open`s the vendor's download page in the default browser and polls `/Applications/<App>.app` until the user has dragged the bundle in, then strips Gatekeeper quarantine with `xattr -rc`. Fully no-op skip-path when all three apps are already installed. URLs live in a top-of-file parallel-array table for one-line updates.

## [v0.0.4] — 2026-04-23

### Added
- `scripts/install-brew.sh` — installs Homebrew (if missing, via the official `NONINTERACTIVE` installer) and brew-installs `node`, `gh`, `jq`, `ripgrep`, `shellcheck`, `shfmt`. Idempotent across re-runs. Wires `brew shellenv` into `~/.zprofile` on Apple Silicon so future shells find brew.

### Fixed
- Wiki-sync CI was failing on every push because the harness scaffold shipped two `README.md` files under `wiki/` (GitHub Wiki is a flat namespace and the sync workflow's duplicate-basename guard correctly aborted). Renamed the nested ADR-index file to `wiki/explanation/decisions/Decisions.md`.

### Changed
- `.harness/PLAN.md` task 4 renamed to `install-clis.sh` — the Gemini CLI is an npm global (`@google/gemini-cli`), not a brew formula, so it folds into the same stage as the Claude Code CLI curl installer. `setup.sh` stage list updated to match.

## [v0.0.3] — 2026-04-22

### Added
- `setup.sh` — top-level Mac orchestrator stub with `--help` listing install stages.
- `README.md` — repo layout, usage, and status.
- `configs/` — literal captured app configs for Claude Code, Claude Desktop, Gemini, Antigravity, zsh PATH additions, git user.
- `scripts/capture.sh` — idempotent capture of the current machine's configs into `configs/`, normalized for stable diffs and secret-stripped (machine-unique `crash-reporter-id` removed; `$HOME` substituted for hardcoded user paths).
- Pending wiki pages: `how-to/Bootstrap-A-New-Mac.md`, `explanation/Dev-Machine-Setup-Design.md`.
- `.harness/PLAN.md` with the 9-task plan for `feat-mac-one-shot-setup`, plus a matching entry in `.harness/features.json`.

### Changed
- `.harness/verify.sh` — replaced the scaffold with real per-file linting: `bash -n` plus optional `shellcheck` on `.sh`, pwsh AST parse on `.ps1`, and `jq empty` on `.json`.

## [v0.0.2] — 2026-04-22

### Changed
- `.harness/init.sh` — replaced the template with a prereq check (required: `git`, `gh`, `jq`, `bash`; optional: `shellcheck`, `shfmt`, `brew`). Fails fast on missing required tools.

## [v0.0.1] — 2026-04-22

### Added
- Initial project scaffold: bootstrapped with [agentic-harness](https://github.com/alexherrero/agentic-harness) v0.8.7 + hooks. Includes adapters for Claude Code, Antigravity, Codex, and Gemini plus `PostToolUse` / `PreCompact` / `SessionStart(compact)` hooks.

[v2.0.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v2.0.0
[v1.1.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v1.1.0
[v1.0.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v1.0.0
[v0.6.1]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.6.1
[v0.6.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.6.0
[v0.5.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.5.0
[v0.4.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.4.0
[v0.3.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.3.0
[v0.2.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.2.0
[v0.1.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.1.0
[v0.0.5]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.5
[v0.0.4]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.4
[v0.0.3]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.3
[v0.0.2]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.2
[v0.0.1]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.1
