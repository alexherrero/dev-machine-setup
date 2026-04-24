# dev-machine-setup <img src="https://img.shields.io/badge/Claude-D97757?logo=claude&logoColor=white&style=flat-square" alt="Claude" align="right"> <img src="https://img.shields.io/badge/Gemini-4285F4?logo=googlegemini&logoColor=white&style=flat-square" alt="Gemini" align="right"> <img src="https://img.shields.io/badge/Antigravity-1A73E8?logo=google&logoColor=white&style=flat-square" alt="Antigravity" align="right">

Opinionated one-shot bootstrap for a Mac dev environment built around AI
coding tools (Antigravity, Gemini Desktop, Claude Desktop, and their
respective CLIs) plus a minimal Homebrew toolchain. Configuration lives
as literal files in `configs/` so the setup is diffable, auditable, and
portable.

---

## Usage

On a fresh Mac:

```bash
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.sh --help    # today: prints the stage list
./setup.sh           # end-to-end bootstrap (lands in PLAN.md task 7)
```

The orchestrator runs each stage in order and stops on the first
failure. Every stage is idempotent — re-running the script does not
reinstall or clobber. After the script finishes, it prints a manual
auth checklist (`claude login`, `gh auth login`, `gemini`, sign in to
Antigravity, sign in to Claude Desktop).

## Layout

```
.
├── setup.sh              Top-level orchestrator (Mac)
├── setup.ps1             Windows entry point (stubbed — PLAN.md task 9)
├── configs/              Literal captured app configs (claude, gemini, antigravity, …)
├── scripts/              Per-concern install stages (install-brew, install-claude-cli, …)
├── docs/                 First-run guide and Windows deferral note
└── .harness/             agentic-harness state (PLAN.md, progress.md, hooks)
```

## Status

**Mac:** in progress — see [.harness/PLAN.md](.harness/PLAN.md) for the
task list.
**Windows:** deferred; skeleton files only. Real implementation happens
against a reference VM in a later plan ([.harness/PLAN.md](.harness/PLAN.md)
task 9).

## Development

This repo uses the [agentic-harness](https://github.com/alexherrero/agentic-harness)
phase-gated workflow. Work is organized around `/plan` → `/work` → `/review`
→ `/release`. State lives under `.harness/`; documentation lives under
`wiki/`. See [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md) for the
agent entry points, and [.harness/verify.sh](.harness/verify.sh) for the
per-file lint gate wired into `PostToolUse`.
