# Plan: One-shot Mac dev-machine setup

**Status:** in-progress
**Created:** 2026-04-22
**Brief:** Build a single-command bootstrap for a fresh Mac that reproduces the current dev environment — Antigravity, Gemini Desktop, Claude Desktop, Claude Code CLI, antigravity CLI, gemini CLI, the supporting Homebrew CLIs, and the literal config files captured from this machine (especially `~/.claude/settings.json` with its ~170/121 allow/ask permissions). Windows support is stubbed for a later pass using a reference VM.

## Goal

On a fresh Mac, `./setup.sh` leaves the user with every preferred AI tool installed, every config file in place, and a clear prompt to complete interactive auth steps (Claude login, gh auth, Gemini oauth, Antigravity sign-in). Re-running the script is safe and idempotent. Configs live as literal files in this repo under `configs/` so edits are tracked in git and portable.

## Constraints

- Literal config files in the repo (not templated). No secret-stripping via templating — we strip secrets at capture time and keep the repo public-safe.
- Claude Code CLI installed via Anthropic's official curl installer (not npm), to match the current machine.
- GUI apps (Antigravity, Gemini Desktop, Claude Desktop) pulled from official installer URLs; we do not rehost binaries.
- Secrets (oauth tokens, GitHub tokens, API keys) never enter the repo. Fresh machines re-authenticate.
- Mac-first. Windows gets skeleton files + a README note; real Windows implementation deferred to a later plan.
- Every script must be idempotent — safe to re-run without clobbering or re-prompting.

## Out of scope

- Windows implementation beyond stubs (deferred — intentional, revisit with reference VM).
- SSH key generation and GitHub key upload.
- Version managers (nvm, fnm, asdf, pyenv).
- Additional tooling the current machine doesn't have (Docker, VS Code, Cursor, tmux, fzf, starship, zoxide).
- Secret management / keychain integration.
- A dotfile manager (chezmoi, yadm) — plain copy/symlink is sufficient.
- Restoring `~/.claude.json` state (projects, caches, oauth) — each machine regenerates it.

## Tasks

### 1. Scaffold the setup-scripts layout
- **What:** Create the directory layout and empty entry points: `configs/` (captured app configs), `scripts/` (per-concern install scripts — brew, claude-cli, gui-apps, link-configs, auth-checklist), `setup.sh` (top-level orchestrator, stub only), and a `README.md` describing usage.
- **Verification:** `bash setup.sh --help` exits 0 and prints a usage banner listing the stages. `tree -L 2 .` shows `configs/`, `scripts/`, `setup.sh`, `README.md`. `.harness/verify.sh setup.sh` passes.
- **Status:** [x]

### 2. Capture current machine configs into `configs/`
- **What:** Copy the literal config files from the current machine into the repo under `configs/`, stripping secrets. Targets: `configs/claude/settings.json`, `configs/claude/CLAUDE.md`, `configs/claude-desktop/claude_desktop_config.json`, `configs/gemini/settings.json`, `configs/antigravity/argv.json`, `configs/zsh/.zshrc-additions` (PATH exports only, not a full shell replacement), `configs/git/.gitconfig` (user.name + user.email only). Write a small `scripts/capture.sh` that can re-run this capture so the repo stays in sync as configs evolve.
- **Verification:** Every file under `configs/` parses (`jq empty` on JSON, `bash -n` on `.zshrc-additions`). A grep for `(oauth|refresh_token|access_token|api[_-]?key|bearer)` under `configs/` returns only documented false positives (the literal `"oauth-personal"` auth-mode selector in Gemini settings, and permission-rule strings like `Bash(gh secret set:*)` in Claude settings — all semantically safe, no tokens or keys). `scripts/capture.sh` is idempotent — running twice produces no git diff.
- **Status:** [x]

### 3. Write the Homebrew install script
- **What:** `scripts/install-brew.sh` — installs Homebrew if missing (official `install.sh` URL), then `brew install` the formulae we use: `node`, `gh`, `jq`, `ripgrep`, `shellcheck`, `shfmt`. No casks (Antigravity/Gemini/Claude aren't brewed). Note: `gemini` is an npm global, not a brew formula — it installs in task 4.
- **Verification:** Running twice does not reinstall. After running, `brew list` contains every required formula; `node`, `gh`, `jq`, `rg`, `shellcheck`, `shfmt` are on PATH.
- **Status:** [x]

### 4. Write the CLI-install script (Claude Code CLI + gemini-cli)
- **What:** `scripts/install-clis.sh` — installs both non-brew CLIs. Runs Anthropic's official curl installer for Claude Code (lands at `~/.local/bin/claude`, pinned to the `stable` channel), then `npm install -g @google/gemini-cli` for the Gemini CLI (requires node from task 3). Ensures `~/.local/bin` is on PATH for future shells (idempotent append to `~/.zshrc` with a marker comment).
- **Verification:** After running, `command -v claude` resolves and `claude --version` exits 0; `command -v gemini` resolves and `gemini --version` exits 0. Running twice converges to the same end state (same claude + gemini versions, PATH marker not re-appended). npm may report non-empty "changed N packages" on re-run from dependency churn — that's intrinsic to npm and does not change the user-facing binaries.
- **Status:** [x]

### 5. Write the GUI-apps install script
- **What:** `scripts/install-gui-apps.sh` — **browser-assisted installer** (curl-direct download was investigated and abandoned: Claude's canonical DMG redirect sits behind a Cloudflare JS challenge that returns 403 to curl regardless of User-Agent, and Antigravity + Gemini Desktop have no discoverable direct-DMG URL). For each app, if `/Applications/<App>.app` is absent, the script `open`s the vendor's download page in the default browser and polls until the user has dragged the `.app` into `/Applications`, then strips Gatekeeper quarantine with `xattr -rc`. Skip-if-exists per app — fully no-op on an already-configured machine. URLs live in a top-of-file parallel-array table for one-line updates.
- **Verification:** Skip-if-exists path + post-check verified on this dev Mac (all three apps present — script runs silent and exits 0). `shellcheck` passes. Interactive download path can only be verified on a fresh Mac and is a `/release`-gate manual step, not a per-task gate. Non-interactive invocations (no TTY on stdin) fail fast with a pointer to `setup.sh --skip-apps` rather than hanging on `read`.
- **Status:** [x]

### 6. Write the config-link script
- **What:** `scripts/link-configs.sh` — places captured configs at their real OS locations using four per-file strategies driven by who writes the file in steady state: **symlink** for user-authored files (only `~/.claude/CLAUDE.md`); **copy-if-absent** for app-owned JSON that the owning tool rewrites in place (confirmed for `~/.claude/settings.json` — Claude Code reorders permissions arrays and inserts `autoUpdatesChannel` between runs; and for `~/Library/.../claude_desktop_config.json` — key order differs from sorted capture; extended by analogy to gemini and antigravity JSONs); **append-idempotent** with a marker comment for `~/.zshrc` (each PATH line added only if not already present verbatim); and **`git config --global` merge** for user.name/user.email so existing gitconfig includes / credential helpers / signing config survive. Any pre-existing non-matching file at a destination is moved to `~/.dev-machine-setup-backup/<utc-timestamp>/` before being replaced; backup dir is lazy-created so a converged re-run leaves no trace.
- **Verification:** `shellcheck` passes. Run 1 on this dev Mac: CLAUDE.md is backed up + symlinked; all four JSON dests are preserved (existed already); `~/.zshrc` gets the marker + the antigravity PATH line (the `~/.local/bin` line was deduped — already present from `install-clis.sh`); `user.name/email` match → no-op. Run 2 is fully no-op (no new backup dir created under `~/.dev-machine-setup-backup/`). `jq empty` passes on all strict JSONs; `argv.json` validates via the same JSONC strip (`sed 's|//.*||' | jq empty`) that `capture.sh` uses. `readlink ~/.claude/CLAUDE.md` points into the repo. The PLAN's original "readlink ~/.claude/settings.json points into the repo OR byte-exact copy" test resolved to the **copy branch** once live-file inspection confirmed Claude rewrites settings.json in place.
- **Status:** [x]

### 7. Wire the top-level orchestrator
- **What:** Flesh out `setup.sh` to run stages 3–6 in order. Flags: `--dry-run` (print ordered plan + script paths, exit 0), `--skip-apps` (drops the gui-apps stage — CI / headless), `--only <stage>` (filter to a single stage; validates against the known list). Each sub-script already prints its own `==> <name>` banner per harness convention; the orchestrator wraps each invocation in an outer `====> stage: <name>` so stage boundaries remain obvious in long logs. `set -euo pipefail` + direct `"$script"` invocation means any non-zero exit halts the pipeline. Stages whose scripts are not yet on disk (currently `auth-checklist` — task 8) warn + skip rather than failing, so partial pipelines still run what exists.
- **Verification:** `shellcheck` passes. `./setup.sh --help` → usage banner, exits 0. `./setup.sh --dry-run` → prints 5-stage plan with resolved script paths, exits 0. `./setup.sh --dry-run --skip-apps` → 4 stages (gui-apps dropped). `./setup.sh --dry-run --only brew` → 1 stage. `./setup.sh --only bogus` → exits 2 with error listing valid stages. `./setup.sh --only link-configs` runs on this dev Mac, produces fully-converged idempotent output, exits 0. Full `./setup.sh` on a fresh Mac is a `/release`-gate manual test (requires a clean VM / wiped account).
- **Status:** [x]

### 8. Post-setup auth checklist
- **What:** `scripts/auth-checklist.sh` — numbered, informational output enumerating the five manual steps that can't be scripted: `claude login`, `gh auth login`, `gemini` (first run triggers Google oauth — no `login` subcommand), `open -a Antigravity`, `open -a Claude`. Always exits 0 (informational, not a gate). `docs/first-run.md` covers the same five steps with extra context: which install stage provisioned each tool, where each tool's state lands on disk, and what `setup.sh` leaves behind (symlinks, seeded configs, zshrc marker block, gitconfig merge, backup dir).
- **Verification:** `shellcheck` passes on `scripts/auth-checklist.sh`. Script exits 0 and prints all five items. `./setup.sh --only auth-checklist` runs the stage via the orchestrator (no longer warn-skipped since the file now exists). `docs/first-run.md` exists and every listed command is one that an earlier install stage actually provisions: `claude` / `gemini` from `install-clis.sh`, `gh` from `install-brew.sh`, Antigravity.app / Claude.app from `install-gui-apps.sh`.
- **Status:** [x]

### 9. Windows stubs
- **What:** `setup.ps1` and `scripts/install-*.ps1` skeletons with the same stage banners but bodies that print `TODO: implement on Windows reference VM` and exit 0. A `docs/windows.md` note describing the deferral. Ensures the repo's contract is cross-platform even if Mac is the only live implementation today.
- **Verification:** Every `.ps1` parses under PowerShell AST (`.harness/verify.sh` handles this if `pwsh` is installed — otherwise confirmed later on the VM). `setup.ps1 --help` / equivalent prints the same stage list. `docs/windows.md` exists.
- **Status:** [ ]

## Risks / open questions

- **Installer URLs for Antigravity + Gemini Desktop may not be stable.** Google doesn't publish permanent direct-download URLs for either. If the URL breaks, task 5 fails and we either pin a version, scrape the download page, or fall back to a manual-install prompt. Mitigation: centralize URLs in a single table file so one-line fixes are cheap.
- **Claude Code may rewrite `~/.claude/settings.json` in place.** If it does, a symlink into the repo could cause inode churn or unintended commits. Task 6 must probe this behavior and choose symlink-vs-copy accordingly; falling back to copy-with-diff-detect is acceptable.
- **Gatekeeper quarantine on downloaded DMGs** will block first-launch. Task 5 handles this with `xattr -d com.apple.quarantine`, which requires the user to confirm once if the DMG is notarized unusually.

## Verification strategy

- `.harness/verify.sh` runs per-file on every `Write|Edit` (bash `-n` + shellcheck if present, pwsh AST parse, `jq empty` on JSON).
- Each task's own verification command (see above) is the primary gate before marking status `[x]`.
- `/review` produces the final deterministic pass (clean tree, all verification commands pass, no TODOs outside the Windows stubs).
- Manual: run the completed `./setup.sh` against a snapshot Mac VM (or a wiped user account) and confirm the resulting state matches the reference machine. This is a `/release`-gate, not per-task.
