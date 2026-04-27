# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[v0.2.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.2.0
[v0.1.0]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.1.0
[v0.0.5]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.5
[v0.0.4]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.4
[v0.0.3]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.3
[v0.0.2]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.2
[v0.0.1]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.1
