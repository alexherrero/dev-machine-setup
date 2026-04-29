# Plan: CI verification for setup scripts (Mac, Ubuntu, Windows smoke)

**Status:** complete (2026-04-29 — first three-platform green dispatch on run 25087515129; v1.0.0 ships)
**Brief:** Add a manually-triggered GitHub Actions workflow that runs `setup.sh` / `setup.ps1` on fresh runners across macOS, Ubuntu, and Windows. When all three jobs pass on a single dispatch, the install scripts are demonstrably working end-to-end — that's the gate that justifies flipping `feat-debian-cli-support.passes=true` and shipping v1.0.0. Windows is **smoke-only** in this plan (orchestrator runs cleanly + all `.ps1` files AST-parse); the immediate follow-on plan (`feat-windows-cli-support`) replaces the smoke job with real Windows install verification.

## Goal

A single workflow file, `.github/workflows/ci-tests.yml`, runs three jobs in parallel — `macos-test`, `ubuntu-test`, `windows-test` — when manually dispatched. Each job exercises the install pipeline as much as the runner allows (Mac skips GUI apps; Windows is stub-only) and asserts idempotency on a re-run. CI is the user-controlled VM-verification step that closes out the prior `feat-debian-cli-support` plan.

## Constraints

- **Triggers:** `workflow_dispatch` **only**. No `push`, no `pull_request`, no `schedule`. The user controls when CI runs.
- **Concurrency:** workflow-level `concurrency: { group: ci-tests-${{ github.ref }}, cancel-in-progress: true }` — if a run is already in progress on the same ref and the user dispatches again, the older run is cancelled in favour of the new one.
- **Hosted runners only.** No self-hosted.
- **No branch protection** added as part of this plan. CI status is informational; you keep direct push access to main.
- **No local-replication script.** `scripts/ci-verify.sh` is out of scope.
- **Mac GUI apps stay out of CI.** `install-gui-apps.sh` needs a human; we use `--skip-apps`. Documented as an acknowledged gap.
- **Windows is smoke-only** in this plan. Verifies orchestrator + per-stage stubs exit 0 and all `.ps1` files AST-parse. Real install verification is the immediate next plan.
- **No caching.** Each run mirrors a fresh-machine bootstrap; caching would defeat the test.
- **No auto-flip of `features.passes`.** When CI is green, you (the human) commit the flip — keeps the repo's commit history human-driven.

## Out of scope

- **Real Windows install verification** — own plan, immediately following this one.
- **Auth-flow testing** — `claude login`, `gh auth login`, `gemini` first-run oauth, `codex login` need a human. CI verifies binaries are installed and `--version` exits 0; nothing more.
- **Multi-version matrix** — single runner per platform (`macos-latest`, `ubuntu-latest`, `windows-latest`). No Intel-Mac coverage; no Ubuntu 22.04 coverage of the shfmt-fallback path. Acceptable gaps.
- **Caching** — see above.
- **Cron / drift detection** — explicitly excluded per this plan.

## Tasks

### 1. `.github/workflows/ci-tests.yml` — full workflow with all three jobs

> **Scope expansion noted (2026-04-28):** During preflight, the "0 warn" assertion on Mac was found to fail with `--skip-apps` because `verify-install.sh` would WARN on missing `/Applications/*.app` and the Claude Desktop config. Resolved by adding `SKIP_APPS=1` env-var support to `setup.sh` (export when `--skip-apps`) and `verify-install.sh` (skip GUI checks when set) — same pattern as `WITH_CODEX`. ~10 lines across two files; mirrors the existing opt-in env-var pattern. Verified locally: Mac default still 30 ok / 0 warn; Mac with `SKIP_APPS=1` reports 26 ok / 0 warn (3 GUI apps + Claude Desktop config consolidated to one `[SKIP]` line).

- **What:** Single workflow file with `name: CI tests`, `on: workflow_dispatch:` only, workflow-level `concurrency: { group: ci-tests-${{ github.ref }}, cancel-in-progress: true }`, and three jobs in parallel:
  - **`macos-test`** (`runs-on: macos-latest`):
    1. `actions/checkout@v4`.
    2. `./setup.sh --help` exits 0; output contains the 6 Mac stage names.
    3. `./setup.sh --dry-run` exits 0; output contains 6 stage paths.
    4. `./setup.sh --skip-apps` end-to-end (drops `gui-apps`). Real brew formulae install (or skip if already present), real Claude curl install, real Gemini npm install, real `link-configs.sh`, real `verify-install.sh`, real `auth-checklist.sh`.
    5. Re-run `./scripts/verify-install.sh` and assert summary line shows `0 warn` (grep on `0 warn`).
    6. **Idempotency:** re-run `./setup.sh --skip-apps` and assert `git status --porcelain` is empty.
    7. **Codex variant:** `./setup.sh --skip-apps --with-codex`; assert `command -v codex` resolves and `codex --version` exits 0.
  - **`ubuntu-test`** (`runs-on: ubuntu-latest`):
    1. `actions/checkout@v4`.
    2. `./setup.sh --help` exits 0; output contains the 5 Debian stage names (no `gui-apps`).
    3. `./setup.sh --dry-run` exits 0; lists `apt` instead of `brew`.
    4. `./setup.sh` end-to-end. Real `install-apt.sh` (NodeSource keyring + sources.list, GitHub CLI keyring + sources.list, `apt update`, install of nodejs/gh/jq/ripgrep/shellcheck/shfmt). Real `install-clis.sh` (Claude curl + npm globals via `~/.npm-global` prefix). Real `link-configs.sh`. Real `verify-install.sh`. Real `auth-checklist.sh`. Job runs as the runner user with passwordless sudo.
    5. Assert `verify-install.sh` summary shows `0 warn`.
    6. **Idempotency:** re-run `./setup.sh`; assert `git status --porcelain` empty + apt step's "0 newly installed" appears.
    7. **Codex variant:** `./setup.sh --with-codex`; assert `command -v codex` resolves.
    8. **Negative test:** assert `~/Library/Application Support/Claude/` was **not** created (link-configs gated correctly on Mac-only paths).
  - **`windows-test`** (`runs-on: windows-latest`):
    1. `actions/checkout@v4`.
    2. `./setup.ps1 -Help` exits 0.
    3. `./setup.ps1 -DryRun` exits 0; lists the 5 stub stages.
    4. `./setup.ps1` exits 0 (runs all stubs, each prints "TODO" and exits 0).
    5. AST-parse every `.ps1` file via `[System.Management.Automation.Language.Parser]::ParseFile`; fail if any file has parse errors.
- **Verification:** `actionlint` if available locally (silent skip if not); workflow YAML parses on push (GH serves a parse error in the Actions tab if invalid). Workflow appears in the Actions tab. `Run workflow` button is visible. Concurrency cancellation visible in the run log when two dispatches land back-to-back.
- **Status:** [x] (2026-04-28: `actionlint` clean; YAML parses via Python yaml; harness `verify.sh` accepts the touched .sh files; structural inventory shows 3 jobs (macos-test 7 steps, ubuntu-test 8 steps, windows-test 5 steps) on the right runners. SKIP_APPS env-var addition to setup.sh + verify-install.sh verified locally — Mac default unchanged at 30 ok / 0 warn; Mac with `SKIP_APPS=1` reports 26 ok / 0 warn as the CI step will assert. End-to-end CI dispatch is the user-driven gate covered in task 3 close-out.)

### 2. README badge + docs update

- **What:** Add a CI status badge to `README.md` (top of file, near the existing Claude / Gemini / Antigravity badges). Update `docs/debian.md` "Future work" → replace the "Reference Debian VM" entry with a pointer to the CI workflow. Update the prior `feat-debian-cli-support` plan section in PLAN.md (now superseded by this plan) to note that CI now replaces the `/release`-gate VM-verification step for that feature. Add a `Testing` or `CI` section to README briefly explaining how to dispatch the workflow manually (Actions tab → CI tests → Run workflow).
- **Verification:** Badge URL renders (GH serves the SVG once the workflow has run at least once — first dispatch makes it appear). Updated `docs/debian.md` future-work section reflects the CI replacement. README badge href links to the workflow runs page.
- **Status:** [x] (verified 2026-04-28: README has the GH Actions native badge linking to `actions/workflows/ci-tests.yml` (placed below the title, separate from the right-aligned brand badges to avoid layout fight). New `## Testing` section in README explains the manual-dispatch flow (Actions tab → CI tests → Run workflow) and notes the cancel-in-progress concurrency. `docs/debian.md` "Future work" rewritten: the "Reference Debian VM" entry replaced by a CI-verification entry pointing at `../.github/workflows/ci-tests.yml`, plus an "Other Ubuntu / Debian releases" entry calling out the shfmt-fallback gap. The "update prior `feat-debian-cli-support` plan section" sub-step was a no-op — the prior plan was overwritten in PLAN.md when this plan landed; the equivalent state lives in `.harness/features.json` descriptions and CHANGELOG. All 6 README internal links + 6 docs/debian.md internal links resolve. Anchor target `## Debian / Ubuntu` confirmed present in `docs/first-run.md`.)

### 3. Close out: flip `features.passes=true` after first three-platform green run

- **What:** After **you** dispatch the workflow and all three jobs (`macos-test`, `ubuntu-test`, `windows-test`) succeed on a single run, manually edit `.harness/features.json`:
  - `feat-ci-verification.passes` → `true`
  - `feat-debian-cli-support.passes` → `true` (CI is the VM verification per the prior plan's contract; smoke-only Windows is a known limitation tracked by the follow-on `feat-windows-cli-support`).
- This is a **manual commit**, not auto-pushed by CI. After it lands, `ship-release v1.0.0` (explicit version since 0.x → 1.0 isn't auto-classified by the conventional-commit rules).
- **Verification:** `jq empty .harness/features.json` passes. Both `passes` flags read `true`. v1.0.0 release exists with notes pointing at the first green CI run URL.
- **Status:** [x] (verified 2026-04-29: first three-platform green dispatch on run 25087515129 (macOS 1m34s + Ubuntu 1m20s + Windows 0m25s, all `success`). Required two CI-fix iterations to get there: NodeSource key dearmor (Ubuntu) and Claude settings.json kill-switch merge (macOS), both committed in d67affb. `feat-ci-verification.passes` and `feat-debian-cli-support.passes` flipped to `true` in this commit. v1.0.0 ships next.)

## Risks / open questions

- **Homebrew install path uncovered.** `install-brew.sh`'s "if missing, install brew" branch never fires on `macos-latest` (brew is pre-installed). Gap; would need a self-hosted runner with brew uninstalled to cover.
- **Claude curl installer behavior on Linux is upstream-controlled.** If Anthropic ever changes the script's exit conventions or output, parsing could break. No cron means we'll find out on the next manual dispatch.
- **NodeSource and GitHub apt repos are upstream-controlled.** Same drift risk. Same mitigation.
- **Concurrency cancel-in-progress can kill mid-install runs.** Apt mid-transaction cancellation can leave dpkg "partial" — but each runner is a fresh VM, discarded after the cancel. Not a problem in CI.
- **Smoke-only Windows is a known gap.** Acknowledged in the close-out criteria; the follow-on `feat-windows-cli-support` plan exists to close it.

## Verification strategy

- Per-task verification commands above are the per-task gates.
- Whole-plan gate: a single manual dispatch with all three jobs **green simultaneously** (not "green at some point each"). This is what authorises the `features.passes=true` flip in task 3.

## Follow-on plan (next, after this one ships)

**`feat-windows-cli-support`** — replaces the smoke-only Windows job from task 1 with real install verification. Research needed: winget vs choco for the toolchain, Claude Code Windows installer (Anthropic-published?), Gemini CLI on Windows (npm should just work), Codex CLI on Windows. Same shape as `feat-debian-cli-support` (multi-task plan, ship-release per task). When that plan lands, the Windows job in `ci-tests.yml` is upgraded from smoke-only to a real install pipeline.
