# Plan: Debian CLI-only dev-machine support

**Status:** in progress (open question 1 resolved 2026-04-27: Codex CLI is in scope on both platforms)
**Created:** 2026-04-27
**Brief:** Add Debian (and Debian-derivatives like Ubuntu) support to the dev-machine-setup install script. Scope is **CLI agents only — no GUI apps**, and includes **Codex CLI** alongside Claude Code + Gemini CLI on both Mac and Debian. Antigravity is GUI-only on every platform and remains out of scope. Mirror the existing Mac flow (idempotent, captured-config-driven, post-setup health-checked) where the logic is portable; diverge only where the OS forces us to.

## Goal

On a fresh Debian/Ubuntu machine, `./setup.sh` leaves the user with the supported CLI agents (Claude Code, Gemini CLI; Codex pending decision) installed, the supporting toolchain on PATH (`node`, `gh`, `jq`, `ripgrep`, `shellcheck`, `shfmt`), the captured agent configs placed at their Linux locations (`~/.claude/`, `~/.gemini/`), the global Claude Code instructions (`~/.claude/CLAUDE.md`, the `Co-Authored-By` kill-switch) in effect, and a clear printed checklist for the manual auth steps that can't be scripted. Re-running is safe and idempotent. The script auto-detects platform — no separate entry point.

## Constraints

- **CLI agents only.** No GUI apps on Linux. The `gui-apps` stage is filtered out of the Linux stage list at the orchestrator level. Antigravity is documented as Mac-only.
- **No Codex on Mac unless we also add it to Debian, and vice-versa** — the Mac and Linux stage lists must stay in lockstep on which agents they install. (See open question 1.)
- **Claude Code via curl installer**, not apt repo. Mirrors the Mac path exactly (`curl https://claude.ai/install.sh | bash -s stable` → `~/.local/bin/claude`). Self-updates in background; matches existing user expectations.
- **Node 22 LTS via NodeSource**, not distro-shipped `nodejs`. apt's package is too old for Gemini CLI's Node ≥ 20 requirement on older Debian/Ubuntu.
- **No `sudo npm install -g`.** Configure a user-local npm prefix (`~/.npm-global`) so the npm globals (Gemini, optionally Codex) install without root. PATH-export idempotently appended to `~/.zshrc`.
- **One script set, OS-aware internally.** Add a small `scripts/lib/os.sh` that exports `OS=macos|debian` and helper predicates. `setup.sh` builds the stage list per OS; sub-scripts that diverge (`install-brew.sh` vs new `install-apt.sh`) live as siblings; sub-scripts that converge (`install-clis.sh`, `link-configs.sh`, `verify-install.sh`, `auth-checklist.sh`) gain internal `if linux` branches but stay single files.
- **Idempotent everywhere.** Same contract as Mac: re-running converges; pre-existing files are backed up to `~/.dev-machine-setup-backup/<utc>/` before being replaced.
- **Configs stay literal in `configs/`**, not templated. The Mac and Debian setups place the same `configs/claude/CLAUDE.md`, `configs/claude/settings.json`, `configs/gemini/settings.json` into the same `~/.claude/` and `~/.gemini/` paths (these are platform-neutral). The Mac-only `~/Library/Application Support/Claude/claude_desktop_config.json` is skipped on Linux.

## Out of scope

- **GUI apps on Linux** (Antigravity, Claude Desktop, Gemini Desktop). Antigravity is GUI-only by design; Claude Desktop ships an `.AppImage`/`.deb` but pulling it in violates the CLI-only scope. If wanted later, that's a separate plan.
- **Other Linux distros** (Fedora/RHEL `dnf`, Arch `pacman`, openSUSE `zypper`, NixOS, Alpine). Debian and derivatives only. The OS-detection helper will fail fast with a clear error on anything else.
- **WSL-specific handling.** WSL Ubuntu hits the same code path as native Debian; we don't add WSL detection or special-case anything (the user can `apt install` and run scripts the same way).
- **`nvm` / `fnm` / version managers.** Same posture as Mac — single global Node.
- **Codex CLI on either platform** unless open question 1 resolves to "yes."
- **Capturing live Linux configs** (`scripts/capture.sh` Linux variant). The repo's captured configs come from the reference Mac; the Linux setup *consumes* them. Adding a `capture.sh` Linux mode is a follow-up, not in this plan.

## Tasks

### 1. OS-detection helper + setup.sh dispatch

- **What:** Create `scripts/lib/os.sh` exporting `OS=macos|debian` (sourced by other scripts via `. "$REPO_ROOT/scripts/lib/os.sh"`). Detection: `[[ "$(uname -s)" == "Darwin" ]]` → macos; else `[[ -f /etc/debian_version ]] || (lsb_release -i | grep -qiE 'debian|ubuntu')` → debian; otherwise print a single-line error naming the unsupported distro and exit 2. Update `setup.sh` to source the helper, then build platform-specific `STAGE_NAMES` / `STAGE_SCRIPTS` / `STAGE_DESCS` arrays. On Debian: drop `gui-apps`; replace `brew` with `apt`.
- **Verification:** `bash -n scripts/lib/os.sh` and `shellcheck` pass. On Mac (this dev box): `OS` resolves to `macos`; `./setup.sh --dry-run` still shows the existing 6-stage Mac plan unchanged. Force the path on Mac with `OS=debian ./setup.sh --dry-run` (helper respects an externally-set `$OS` for testing) → 5-stage Debian plan with `apt` instead of `brew` and no `gui-apps`. Unsupported-OS path: stub `uname` to return `Linux` while removing `/etc/debian_version` access in a sandbox subshell — exit code 2, error names the distro.
- **Status:** [x] (verified 2026-04-27: `shellcheck` clean on `scripts/lib/os.sh` + `setup.sh`. Mac default → `macos`, 6-stage plan unchanged. `OS=debian ./setup.sh --dry-run` → 5-stage Debian plan with `install-apt.sh` in slot 1. `OS=plan9` exits 2 with `invalid $OS=plan9` (override-validation case added during build to prevent invalid externals falling through to the Debian dispatch branch). `OS=debian ./setup.sh --only gui-apps` correctly rejects with `unknown stage: gui-apps` against the Debian-specific stage list. `OS=debian ./setup.sh --only apt` warn-skips the missing `install-apt.sh` per existing setup.sh contract.)

### 2. `scripts/install-apt.sh` (Debian equivalent of install-brew.sh)

- **What:** New script. Steps: (a) `sudo install -d -m 0755 /etc/apt/keyrings`; (b) NodeSource keyring + sources.list (`https://deb.nodesource.com/node_22.x nodistro main`); (c) GitHub CLI keyring + sources.list (`https://cli.github.com/packages stable main` with `arch=$(dpkg --print-architecture)` so amd64 + arm64 both work); (d) `sudo apt update && sudo apt install -y nodejs gh jq ripgrep shellcheck shfmt`; (e) `shfmt` fallback: if `apt-cache show shfmt` reports nothing (older Debian/Ubuntu), `curl -fsSL` the matching `shfmt_v3.x.x_linux_$(dpkg --print-architecture)` GitHub-release binary into `/usr/local/bin/shfmt` with `install -m755`. Idempotent throughout — re-running is a no-op (apt key add, sources.list write, install all skip if already done). Pin NodeSource and GitHub apt-repo lines to literal strings at the top of the file for one-line updates.
- **Verification:** `shellcheck` passes. On a fresh Debian VM: every binary in `node`, `npm`, `gh`, `jq`, `rg`, `shellcheck`, `shfmt` resolves on PATH and `--version` exits 0. Re-run produces "0 upgraded, 0 newly installed" from apt and no rewrite of the keyring/sources files. Architecture parity check: same script on amd64 and arm64 hosts. (VM verification is a `/release`-gate manual step, not per-task.)
- **Status:** [x] (verified 2026-04-27 on Mac dev box: `shellcheck -x` clean — same posture as `setup.sh` since both source `os.sh` and the harness `verify.sh` already runs `-x`. `bash -n` clean. **Defensive Mac guard** added during build: if `OS != debian`, the script exits 2 with `error: install-apt.sh requires a Debian/Ubuntu host (OS=macos)` before any sudo or apt invocation — prevents accidental damage if someone runs it directly. Dispatch via `OS=debian ./setup.sh --dry-run --only apt` resolves the script. Idempotency primitives in place: `install_keyring` skips if file exists, `install_sources_line` skips if `grep -Fxq` finds the line. shfmt fallback uses `curl -fsSLI` against `/releases/latest` redirect to resolve the latest tag without needing jq (which we may be installing in the same run). Runtime `apt install` / network behavior is `/release`-gate VM work, not per-task.)

### 3. Make `install-clis.sh` cross-platform + Codex (opt-in)

- **What:** The existing Claude (curl) + Gemini (`npm install -g @google/gemini-cli`) logic is platform-portable. **Codex CLI is opt-in** (`@openai/codex`, gated on `WITH_CODEX=1`). User flips it on with `./setup.sh --with-codex`, which exports `WITH_CODEX=1` to the install-clis stage; default is off so the install stays minimal. Other changes: (a) source `scripts/lib/os.sh`; (b) update header comment from "Mac-specific" prose to platform-neutral, multi-CLI; (c) replace the unconditional zshrc-only PATH marker with a per-OS rc-file pick (zshrc on Mac since it's the captured shell; on Debian detect `$SHELL` and write to `~/.zshrc` if zsh else `~/.bashrc`); (d) configure user-local npm prefix on Debian (`npm config set prefix "$HOME/.npm-global"` + idempotent PATH append for `~/.npm-global/bin`). Mac path unchanged (brew's npm prefix is already user-writable on Apple Silicon). (e) Hard-fail with a clear message if `node --version` < 20 on Debian. (f) The post-check verifies `claude` + `gemini` always; appends `codex` to the expected-binaries list only when `WITH_CODEX=1` (so a default install doesn't false-positive `codex MISSING`).
- **Verification:** `shellcheck` passes. On Mac: re-running produces existing converged output (no new PATH lines, no npm prefix change). With `WITH_CODEX=1`, `codex --version` resolves; without, `==> Codex CLI: skipped (pass --with-codex to setup.sh to include)` is printed and post-check exits 0 with only claude+gemini. On Debian VM: `claude --version` and `gemini --version` exit 0 from a fresh shell after `source ~/.zshrc` (or `~/.bashrc`). Node-version guard: stub `node` to return `v18.0.0` and confirm the script exits 1 with the upgrade-Node message.
- **Status:** [x] (verified 2026-04-27 on Mac dev box. Initial implementation installed Codex unconditionally — re-scoped same day to opt-in per user request. Final state: `shellcheck -x` clean on `setup.sh` and `install-clis.sh`. Mac default run: claude 2.1.112 + gemini 0.39.1 only; "Codex CLI: skipped" banner; post-check passes. Mac with `WITH_CODEX=1`: codex 0.125.0 added (verified during the original universal-install pass — uninstalled during the re-scope so the default-off invariant holds on this Mac). `--help` shows the new flag. `--dry-run --with-codex` parses cleanly. **rc_file() dispatch**: `OS=debian SHELL=/bin/zsh` → `~/.zshrc`, `OS=debian SHELL=/bin/bash` → `~/.bashrc`, `OS=macos` → `~/.zshrc`. Debian-only Node-version guard (`check_node_version_debian`) and npm-prefix configuration verified by inspection — actual runtime exercise is `/release`-gate VM work.)

### 4. `link-configs.sh` Linux paths

- **What:** Source `scripts/lib/os.sh`. Make the `~/Library/Application Support/Claude/claude_desktop_config.json` `link_copy_if_absent` call Mac-only (skip on Debian — Claude Desktop isn't installed on Linux in this scope). Everything else (`~/.claude/CLAUDE.md` symlink, `~/.claude/settings.json`, `~/.gemini/settings.json`, `~/.antigravity/argv.json`, zshrc/bashrc PATH, `git config --global` user.name/email) is platform-portable as-is — Linux uses the same `$HOME/.claude` etc. paths. Update the post-check JSON validation list to skip the Mac-only path on Debian.
- **Verification:** `shellcheck` passes. On Mac: re-run is fully no-op (existing Mac contract preserved). On Debian VM: after running, `~/.claude/CLAUDE.md` is a symlink into the repo; `jq empty` succeeds on the three Linux JSONs; `~/.zshrc` (or `~/.bashrc`) has the PATH marker once; `~/Library/...` is not created (verified with `[ ! -e "$HOME/Library/Application Support/Claude" ]`). `git config --global user.name/email` matches the captured values. `~/.antigravity/argv.json` is still seeded — even though the GUI isn't installed, the JSONC config is harmless on disk and matches the "configs are literal" constraint; if we later add Antigravity-CLI parity, the file is already in place.
- **Status:** [ ]

### 5. `verify-install.sh` Linux skips + conditional Codex check

- **What:** Source `scripts/lib/os.sh`. Wrap the `/Applications/*.app` checks (Antigravity / Gemini / Claude) in `if [[ "$OS" == "macos" ]]` — otherwise emit `[SKIP] GUI app checks (Linux: CLI-only scope)`. Same for the `~/Library/...` JSON validity check. **Conditionally add `codex` to the PATH-binary loop and the CLI-version smoke-test loop** when `WITH_CODEX=1` (matching the install gate from task 3). When the env var is not set, codex is skipped with `[SKIP] codex check (set WITH_CODEX=1 to include)` rather than `[WARN] codex not on PATH` — the latter would be a false alarm on default installs. The CLAUDE.md symlink check, the global `~/.claude/settings.json` JSON check, the `includeCoAuthoredBy:false` kill-switch check, the harness-tier project checks — all stay unchanged.
- **Verification:** `shellcheck` passes. On Mac: existing 30 ok / 0 warn output preserved when Codex is off; with `WITH_CODEX=1 ./scripts/verify-install.sh` and codex installed, count goes up by 2 (PATH + version). On Debian VM after a full setup run: GUI-app + Mac-only-JSON checks emit `[SKIP]`; claude/gemini `[ OK ]`; codex `[SKIP]` or `[ OK ]` per the flag. Force the Linux path on Mac with `OS=debian ./scripts/verify-install.sh` and confirm the GUI-app checks all skip and the global tier still passes the rest.
- **Status:** [ ]

### 6. `auth-checklist.sh` Linux trim + conditional Codex login step

- **What:** Source `scripts/lib/os.sh`. **Conditionally add a `codex login` step** (or whatever Codex's first-run auth command is — verify against `codex --help` in this task; OpenAI's CLI uses interactive oauth) when `WITH_CODEX=1`. Skip the step otherwise so a default install doesn't tell users to log into a CLI they don't have. On Debian, drop the GUI sign-in steps (`open -a Antigravity`, `open -a Claude`); the Mac list keeps them. Update the heading text to "completed CLI install" rather than "installed tooling" on Linux to make the GUI-omission deliberate. `docs/first-run.md` gets a parallel Linux subsection.
- **Verification:** `shellcheck` passes. On Mac default: 5 numbered items (claude, gh, gemini, Antigravity, Claude Desktop; no codex). With `WITH_CODEX=1`: 6 numbered items (+ codex login). On Debian default (force with `OS=debian`): 3 numbered items (claude, gh, gemini). With `OS=debian WITH_CODEX=1`: 4 items (+ codex). `grep -E "Antigravity|Claude Desktop"` over Linux output returns nothing; `grep -i codex` only matches when WITH_CODEX=1.
- **Status:** [ ]

### 7. Docs: README + new `docs/debian.md`

- **What:** README — add a `### Debian / Ubuntu` subsection alongside the existing `### macOS / Linux` (rename the current one to `### macOS`, since "/ Linux" was aspirational). Subsection includes the `git clone` + `./setup.sh` lines plus the Linux PATH-refresh (`source ~/.zshrc` or `source ~/.bashrc`). Status section gains a Debian row. New `docs/debian.md`: supported-distro matrix (Debian 11/12/13, Ubuntu 22.04/24.04 LTS), what's omitted vs Mac (GUI apps, Claude Desktop config), why Antigravity isn't supported on Linux (one-paragraph callout citing the docs URL), and a "If you want GUI apps on Linux too" pointer for future plans.
- **Verification:** Markdown renders (no broken links via `grep -oE '\]\([^)]+\)' docs/debian.md README.md` cross-referenced against `find docs scripts -name '*.md' -o -name '*.sh' -o -name '*.ps1'`). README's three subsections (`### macOS`, `### Debian / Ubuntu`, `### Windows`) all present. `docs/debian.md` exists; the explicit Antigravity-not-supported callout is grep-able.
- **Status:** [ ]

### 8. Update `features.json` + close out

- **What:** Add a new feature entry `feat-debian-cli-support` to `.harness/features.json` with the 7 task summaries. Mark `passes: false` until tasks 1–7 are all `[x]` and verified end-to-end on a Debian VM. Append a single line to `.harness/progress.md` per task as work lands. Update CHANGELOG.md only at `/release` time, not per-task.
- **Verification:** `jq empty .harness/features.json` passes; the new feature entry is present and well-formed. `.harness/progress.md` has one line per completed task.
- **Status:** [ ]

## Risks / open questions

1. ~~**Codex CLI: include or exclude?**~~ **Resolved 2026-04-27: include.** Codex is now part of tasks 3 (install), 5 (verify), and 6 (auth checklist) on both Mac and Debian.
2. **Are you on Debian-proper or Ubuntu?** Affects whether `shfmt` is available in apt out-of-the-box (Ubuntu 24.04 yes, Debian 12 yes, Debian 11 needs the GitHub-release fallback, Ubuntu 22.04 needs the fallback). Plan covers both via a runtime probe; just want to confirm the dev box's `lsb_release -ds` so I know which path will fire on first run.
3. **Shell on Debian box: zsh or bash?** `install-clis.sh` and `link-configs.sh` need to know which rc-file to write the PATH marker into. Plan auto-detects via `$SHELL`; surfacing as a sanity check.
4. **GitHub CLI: apt repo signing-key fingerprint** can change. We pin to the URL, not the fingerprint, but should document where to refresh from if it ever rotates (`https://github.com/cli/cli/blob/trunk/docs/install_linux.md`).
5. **Claude Code curl installer behavior on Debian** (auto-updates in background) might surprise a sysadmin who expected apt-managed lifecycles. The plan keeps the curl path for parity with Mac; if you'd rather use the signed apt repo on Debian, that's a one-task switch — say the word.

## Verification strategy

- `.harness/verify.sh` runs per-file on every `Write|Edit` (bash `-n` + shellcheck, jq for JSON, pwsh AST for `.ps1`).
- Each task's own verification command (above) is the per-task gate. Anywhere I write "on Debian VM", that's a `/release`-gate manual step, not per-task.
- The two reproducible test surfaces on this Mac without a VM: (a) `OS=debian ./scripts/<name>.sh` to force the Linux branch on a Mac filesystem (good for argument parsing, dispatch, dry-runs, error paths); (b) the existing Mac path remains green throughout — if any of the five touched scripts (`install-clis.sh`, `link-configs.sh`, `verify-install.sh`, `auth-checklist.sh`, `setup.sh`) regresses on Mac, that's a per-task failure.
- Final `/release`-gate: full `./setup.sh` on a clean Debian VM (or container) producing the expected end-state. That work happens in `/release`, not here.
