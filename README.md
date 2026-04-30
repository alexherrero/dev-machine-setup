# dev-machine-setup <img src="https://img.shields.io/badge/Claude-D97757?logo=claude&logoColor=white&style=flat-square" alt="Claude" align="right"> <img src="https://img.shields.io/badge/Gemini-4285F4?logo=googlegemini&logoColor=white&style=flat-square" alt="Gemini" align="right"> <img src="https://img.shields.io/badge/Antigravity-1A73E8?logo=google&logoColor=white&style=flat-square" alt="Antigravity" align="right">

[![CI tests](https://github.com/alexherrero/dev-machine-setup/actions/workflows/ci-tests.yml/badge.svg)](https://github.com/alexherrero/dev-machine-setup/actions/workflows/ci-tests.yml)

Opinionated one-shot bootstrap for a Mac (full GUI + CLI) or Debian /
Ubuntu (CLI-only) dev environment built around AI coding tools (Claude,
Gemini, optionally OpenAI Codex; Antigravity Desktop on Mac).
Configuration lives as literal files in `configs/` so the setup is
diffable, auditable, and portable.

---

## Usage

### macOS

```bash
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.sh --help               # prints the stage list
./setup.sh                      # end-to-end bootstrap
./setup.sh --with-codex         # also install Codex CLI (opt-in)
source ~/.zshrc                 # refresh PATH so newly-installed CLIs resolve
```

### Debian / Ubuntu

CLI-only scope: Claude Code + Gemini CLI (+ optional Codex CLI), no GUI
apps. Antigravity Desktop is GUI-only and out of scope on Linux. See
[docs/debian.md](docs/debian.md) for the supported-distro matrix and
what's omitted vs Mac.

```bash
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.sh --help               # prints the Debian-flavored stage list
./setup.sh                      # end-to-end bootstrap (sudo prompts during apt)
./setup.sh --with-codex         # also install Codex CLI (opt-in)
source ~/.zshrc || source ~/.bashrc   # whichever rc file matches your $SHELL
```

### Windows

```powershell
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.ps1 -Help    # prints the stage list
./setup.ps1          # end-to-end bootstrap (currently a stub — see docs/windows.md)
# Refresh PATH in the current session so new tools resolve:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

The orchestrator detects OS, runs each stage in order, and stops on the
first failure. Every stage is idempotent — re-running the script does
not reinstall or clobber. After the script finishes, it prints a manual
auth checklist tailored to the platform and the flags used (`claude
login`, `gh auth login`, `gemini`, optionally `codex login`, plus the
Mac-only GUI sign-ins).

## Layout

```
.
├── setup.sh              Top-level orchestrator (Mac + Debian/Ubuntu)
├── setup.ps1             Windows entry point (stubbed — see docs/windows.md)
├── configs/              Literal captured app configs (claude, gemini, antigravity, …)
├── scripts/              Per-concern install stages
│   ├── lib/os.sh         OS detection helper (sets $OS = macos|debian)
│   ├── install-brew.sh   Mac toolchain (Homebrew + formulae)
│   ├── install-apt.sh    Debian toolchain (apt + NodeSource + gh repos)
│   ├── install-clis.sh   Claude + Gemini (+ Codex when --with-codex)
│   ├── install-gui-apps.sh  Mac-only GUI apps (browser-assisted)
│   ├── link-configs.sh   Place captured configs at OS locations
│   ├── verify-install.sh Warn-only post-setup health check
│   └── auth-checklist.sh Print manual auth steps
├── docs/                 First-run guide, Debian + Windows notes
└── .harness/             agentic-harness state (PLAN.md, progress.md, hooks)
```

## Status

**Mac:** ready (full GUI + CLI install path).
**Debian / Ubuntu:** ready (CLI-only). See [docs/debian.md](docs/debian.md)
for the supported-distro matrix.
**Windows:** ready (full GUI + CLI, mirrors Mac scope). winget for
toolchain + Claude Code + Antigravity Desktop + Claude Desktop, npm for
Gemini. Codex skip-with-warn (upstream npm broken on Windows). See
[docs/windows.md](docs/windows.md).

## Testing

CI is **manually dispatched** — no auto-runs on push or PR. The
[`ci-tests.yml`](.github/workflows/ci-tests.yml) workflow runs the full
install pipeline on three fresh runners: `macos-latest` (`--skip-apps`,
since the Mac GUI installer needs a human), `ubuntu-latest` (full
Debian path, no GUI apps in scope), and `windows-latest`
(`-SkipApps`, full toolchain + CLIs + the Codex-skipped invariant).
Each platform's job asserts `verify-install` reports zero warns and
that a re-run produces no repo drift.

To dispatch:

1. Open the [Actions tab](https://github.com/alexherrero/dev-machine-setup/actions)
   on GitHub.
2. Pick **CI tests** in the left sidebar.
3. Click **Run workflow** → **Run workflow** (default branch `main`).

Concurrency is `cancel-in-progress`: dispatching again while a run is
active supersedes the older one.

## Development

This repo uses the [agentic-harness](https://github.com/alexherrero/agentic-harness)
phase-gated workflow. Work is organized around `/plan` → `/work` → `/review`
→ `/release`. State lives under `.harness/`; documentation lives under
`wiki/`. See [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md) for the
agent entry points, and [.harness/verify.sh](.harness/verify.sh) for the
per-file lint gate wired into `PostToolUse`.
