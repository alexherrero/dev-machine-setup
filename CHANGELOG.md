# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[v0.0.3]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.3
[v0.0.2]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.2
[v0.0.1]: https://github.com/alexherrero/dev-machine-setup/releases/tag/v0.0.1
