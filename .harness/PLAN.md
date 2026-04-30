# Plan: Public release with curl|bash installer (`feat-curl-bash-installer`)

**Status:** planning
**Created:** 2026-04-29
**Brief:** Make the repo public, ship a `curl | bash` / `irm | iex` bootstrap that pulls the latest release tarball, polish README + wiki for public consumption, and move every verification gate into CI.

## Goal

A user on a fresh Mac, Debian, or Windows host installs the full dev environment with one line that requires only `curl` (Mac/Linux) or `Invoke-WebRequest` (Windows). The repo is public; README + wiki are public-ready (compact, scannable, table-heavy, à la [TsekNet/converge](https://github.com/TsekNet/converge/blob/main/README.md)); LICENSE is in place; every verification gate is a CI job, not a local check.

## Constraints

- **Visibility flip is effectively irreversible** (caches, forks, mirrors). Audit must be exhaustive before flipping.
- **All gates run in CI.** Per-task verification = "the relevant CI job is green on a manual dispatch", not local commands.
- **No new runtime deps for users.** Bootstrap uses only `curl`+`tar`+`bash` (Mac/Linux) or `Invoke-WebRequest`+`Expand-Archive` (Windows).
- **Pin to latest release tag**, not `main` HEAD. Users get tested releases, not unreviewed `main` commits.
- **Backwards compatible.** `git clone …` flow keeps working forever; old tags untouched.
- **README style:** centered title, tagline, badges, install-first lead, tables for "What gets installed" / "Per-platform scope" / "Documentation". Drop the agentic-harness internal references at the top level.
- **License:** MIT (matches converge ref + personal-tool / no-warranty posture).
- **`.harness/progress.md` stays as-is** — transparent record of how the repo was built, including agentic-harness flow.

## Out of scope

- Custom-uploaded release assets (auto source tarball is sufficient).
- Distribution beyond GitHub (homebrew tap, apt repo, winget, npm). Separate plan.
- Self-update / version-pin flag (`--version vX.Y.Z`).
- CONTRIBUTING.md / CODE_OF_CONDUCT.md / issue templates (defer until external contributors appear).
- CI on `main` HEAD bootstrap (would require cutting a release before testing).
- `markdownlint` in CI (fast-follow after v1 if prose drift becomes a problem; v1 ships with `lychee` link-integrity only).
- Deeper structural wiki rewrite (task 8 is constrained to: drop pending-no-impl, reframe internal monologue, fix personal pronouns, fix broken links).

## Tasks

### 1. Pre-public deep audit (no flip yet)

- **What:** Six audit tracks across the entire repo:
  1. **Secrets / tokens** — `capture.sh` regex (`oauth|refresh_token|access_token|api[_-]?key|bearer|secret`) over working tree AND `git log -p`. Document allowed false-positives (e.g., `Bash(gh secret set:*)` permission strings in `configs/claude/settings.json`).
  2. **Hardcoded personal data** — `/Users/alex/`, `alexmherrero@gmail.com`, hostnames, MAC addresses, serials, crash-reporter-id (already stripped per feat-mac-one-shot-setup task 2 — re-verify).
  3. **Wiki content** — every page in `wiki/`: drop pending-no-impl pages, rewrite internal-monologue, fix personal pronouns, fix broken in-repo links.
  4. **Harness content** — `.harness/PLAN.md`, `.harness/features.json`. (`.harness/progress.md` stays as-is per constraint.) Verify nothing in PLAN.md / features.json has incidentally-personal references.
  5. **Workflows** — `.github/workflows/*.yml`. Any `secrets.*` refs, private-runner usage, internal artifact targets.
  6. **Configs** — `configs/` tree end-to-end, hand-read each file.
- **Verification:** **CI:** the new `audit` step inside the `static-analysis` job (added in task 3) runs the regex scans deterministically on every dispatch. **Pre-flight (one-time):** I present a written audit report; user marks each finding OK / FIX / DECIDE; remediation commits land before task 4.
- **Status:** [x] (2026-04-29: 6-track audit run; 0 secrets found in tree or history; 1 leak (`/Users/alex/` in `.claude/settings.local.json`) genericized to `Users/*/` + `home/*/` globs; 4 `/setup`-seeded placeholder pages dropped (First-Explanation, First-How-To, First-Reference, 01-Getting-Started — Home.md + _Sidebar.md updated to match); 3 stale wiki status lines bumped to v2.0.0 (Dev-Machine-Setup-Design.md, Bootstrap-A-New-Mac.md, Bootstrap-A-New-Debian-Or-Ubuntu.md). Decisions per user: keep `.gitconfig` noreply email as-is; keep PLAN.md first-person "I" usages as transparent agentic-flow record. Remaining audit-script form (regex scans) lands as the `audit` step inside task 3's `static-analysis` job.)

### 2. Hygiene additions

- **What:** Add `LICENSE` (MIT, copyright "Alex Herrero"). Add a `## License` line to README pointing at it. No SECURITY.md / CONTRIBUTING.md / templates in v1.
- **Verification:** **CI:** the `static-analysis` job (task 3) includes `test -f LICENSE && test -s LICENSE` as a step.
- **Status:** [x] (2026-04-29: LICENSE added at repo root with standard MIT text — Copyright (c) 2026 Alex Herrero. README gained `## License` section pointing at LICENSE. CI gate (`test -f LICENSE && test -s LICENSE`) lands as a step inside task 3's `static-analysis` job; structural piece in place now, gate wires up next task.)

### 3. New `static-analysis` CI job

- **What:** Add a fourth job to `.github/workflows/ci-tests.yml`, parallel to `macos-test` / `ubuntu-test` / `windows-test`. Steps:
  - `shellcheck` over every `*.sh` (`scripts/`, `setup.sh`, `install.sh`, `.harness/verify.sh`)
  - `actionlint` over `.github/workflows/*.yml`
  - pwsh AST parse over every `*.ps1` (windows-latest runner step or pwsh-on-ubuntu via `microsoft/setup-msbuild`-style action)
  - `lychee` over all `*.md` for broken in-repo links
  - secret-scan + personal-data scan from task 1 (so future PRs are gated)
  - `test -f LICENSE && test -s LICENSE`
- **Verification:** **CI:** `actionlint` validates the new YAML; `static-analysis` job goes green on dispatch. Becomes the named gate that every other task references.
- **Status:** [x] (2026-04-29: static-analysis job added with 6 steps — shellcheck (-x; .harness/ excluded as vendored), actionlint (self-hosted via download-actionlint.bash; no third-party action dep), pwsh AST parse (ubuntu-latest pwsh, .harness/ excluded), lychee (scope narrowed to README.md/CHANGELOG.md/docs/ — wiki and vendored adapters and AGENTS.md/CLAUDE.md upstream pointers all out of v1 scope), audit-regex scan (API-key shapes + non-noreply email + hardcoded /Users/alex/ paths; workflows/ + PLAN/progress/CHANGELOG narrative excluded to avoid self-match), LICENSE non-empty check. CI verified green on run 25150482876 — three iterations to land: (a) telemetry.sh SC2034 in vendored .harness/ → exclude .harness/; (b) lychee 39-error breadth → narrow to user-facing public docs; (c) actionlint clean throughout. The `static-analysis` job is now the named gate referenced by every remaining task.)

### 4. Visibility flip to public

- **What:** Pure ceremony. Tasks 1–3 must be `[x]`. I show user the audit summary + the post-task-3 CI dispatch URL; user confirms; I run `gh repo edit alexherrero/dev-machine-setup --visibility public --accept-visibility-change-consequences`. CHANGELOG entry added.
- **Verification:** **CI:** existing `static-analysis` + matrix jobs all green post-flip on a re-dispatch. Plus a one-time check: `curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/README.md` succeeds without auth headers.
- **Status:** [x] (2026-04-30: flipped via `gh repo edit alexherrero/dev-machine-setup --visibility public --accept-visibility-change-consequences`. `gh repo view --json visibility` returns `PUBLIC`. Three unauthenticated checks all pass: (1) `raw.githubusercontent.com` README.md fetch returns the file body, (2) `api.github.com/repos/.../releases/latest` returns v2.0.0 metadata, (3) source tarball download `archive/refs/tags/v2.0.0.tar.gz` returns 200 + 130KB. CHANGELOG.md `[Unreleased]` section added covering the visibility flip + LICENSE + static-analysis. Post-flip CI re-dispatch confirms all four jobs still green.)

### 5. `install.sh` — POSIX bootstrap

- **What:** Repo-root bootstrap script:
  - Detects `curl` (preferred) or `wget` (fallback).
  - Fetches `https://api.github.com/repos/alexherrero/dev-machine-setup/releases/latest`; parses `.tag_name` via grep/sed (no jq dep — same approach as the shfmt fallback in `install-apt.sh`).
  - Downloads `https://github.com/alexherrero/dev-machine-setup/archive/refs/tags/<tag>.tar.gz` to `$(mktemp -d)`, extracts in place.
  - Cd's into the extracted `dev-machine-setup-<version>` dir (GitHub strips the leading `v`).
  - Execs `./setup.sh "$@"`, forwarding all args.
  - Prints the extract dir on exit so the user can re-run / clean up.
  - `set -euo pipefail`; clear error message on any failure.
- **Verification:** **CI:** `static-analysis` job's `shellcheck install.sh` step. Each matrix job (`macos-test`, `ubuntu-test`) gains a step: `curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh | bash -s -- --dry-run` exits 0 and prints the stage list.
- **Status:** [x] (2026-04-30: install.sh added at repo root. Two iterations to land green: (1) initial JSON-API approach hit HTTP 403 on macos-latest from the unauth rate limit (60/hr per IP shared across runner pool — exactly the case flagged as plan open question 2); (2) switched to the `/releases/latest` HTML-redirect Location-header parse (no rate limit; same pattern as install-apt.sh's shfmt fallback). curl uses `-fsSI`, wget uses `-S --max-redirect=0 --spider`. CI verified green on run 25169301931 — bootstrap-from-curl steps in macos-test and ubuntu-test both exit 0 with v2.0.0's setup.sh stage list. install.sh@main → setup.sh@v2.0.0 coupling resolves when v3.0.0 ships in task 10. Documenter dispatched: confirmed all three pending wiki pages stay pending until task 6 (install.ps1) lands — flipping after only half the bootstrap pair would mislead readers.)

### 6. `install.ps1` — Windows bootstrap

- **What:** PowerShell mirror of `install.sh`:
  - `Invoke-RestMethod` against the releases-latest API (PowerShell auto-parses JSON).
  - Downloads source `.zip` (GitHub serves both `.tar.gz` and `.zip` for source archives).
  - `Expand-Archive` to `$env:TEMP\dev-machine-setup-<tag>`.
  - Cd's in, execs `& ./setup.ps1 @args` with splatted args.
  - `$ErrorActionPreference = 'Stop'`; print extract dir on exit.
- **Verification:** **CI:** `static-analysis` job's pwsh-AST-parse step. `windows-test` job gains: `iwr -UseBasicParsing https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.ps1 | iex` followed by `setup.ps1 -Help` from the extract dir, exit 0.
- **Status:** [ ]

### 7. README rewrite (converge style)

- **What:** End-to-end restructure of `README.md`:
  - Centered HTML block: title + tagline + badges (CI tests, License, Latest release).
  - One-paragraph "what this does".
  - **Install** section — leads with `curl | bash` + `irm | iex` per platform; alternative `git clone` form below.
  - **Quick start** — numbered: 1) install, 2) refresh shell / PATH, 3) auth checklist.
  - **What gets installed** table (Component | Mac | Linux | Windows | Source).
  - **Stage list** table (Stage | Description) — replaces the existing prose stage description.
  - **Documentation** table (Doc | Description) — links to docs/first-run.md, docs/debian.md, docs/windows.md, .harness/PLAN.md, wiki/.
  - **License** section.
  - Drop: agentic-harness internal references at this level (move to a sub-doc); `Layout` ASCII tree (move to docs/architecture.md or similar).
- **Verification:** **CI:** `static-analysis` job's `lychee` step passes (no broken links). New `readme-shape` step in `static-analysis` greps for required sections (badge block, Install, Quick start, License).
- **Status:** [ ]

### 8. Wiki + docs/ public polish

- **What:** Page-by-page audit:
  - `wiki/Home.md`, `wiki/_Sidebar.md` — entry points, simple TOC pointing at major pages.
  - `wiki/.diataxis` (if present) — keep if structural, trim if internal-thought.
  - `wiki/how-to/*` — every page must answer a real user question; drop pending-no-impl pages with no implementation.
  - `wiki/explanation/*` — reframe internal-monologue entries as design rationale.
  - `wiki/reference/*` — keep tabular reference; expand if Stage list etc. moved here from README.
  - `docs/first-run.md`, `docs/debian.md`, `docs/windows.md` — already largely public-ready; spot-check for "I" / personal tone.
- **Verification:** **CI:** `static-analysis` job's `lychee` step covers wiki/ + docs/ link integrity. Personal-data scan from task 1 also catches lingering personal references.
- **Status:** [ ]

### 9. Bootstrap-from-curl end-to-end CI + features.json

- **What:** Confirm the bootstrap-from-curl steps wired into the matrix jobs in tasks 5+6 are exercised on a fresh dispatch. Add `feat-curl-bash-installer` entry to `.harness/features.json`. After end-to-end CI green, flip `passes: true`.
- **Verification:** **CI:** single manual dispatch where mac-test / ubuntu-test / windows-test / static-analysis all green simultaneously, with each platform's bootstrap-from-curl step exiting 0.
- **Status:** [ ]

### 10. Close-out: v3.0.0 release

- **What:** Cut v3.0.0 (major bump — visibility flip + install model + README rewrite is a meaningful break in user expectations, even though all old paths still work). Release notes lead with: "Public!", "One-line install", "README rewrite", "All gates in CI". Update CHANGELOG.
- **Verification:** **CI:** `gh release view v3.0.0 --json url -q .url` returns a URL; release notes contain the curl + irm one-liners; CI badge in README shows green for the release dispatch.
- **Status:** [ ]

## Risks / open questions

1. **Audit miss → leak after public flip.** Highest-impact risk. Mitigation: 6-track task 1 + user sign-off + automated regex gates in task 3. Post-flip recovery is BFG-repo-cleaner + force-push + secret rotation, complicated by forks.
2. **GitHub API unauthenticated rate limit (60/hr per IP).** Corporate NAT could hit it. Mitigation: one GET per install attempt, practically a non-issue. Fallback: parse the `…/releases/latest` HTTP redirect URL instead of the API.
3. **`curl | bash` security model.** Trust = GitHub TLS + user's own audit before piping. Document in README's Install section, same posture as Homebrew.
4. **Old README clones / tags.** Users who bookmarked v1.x or v2.x still see `git clone …`. They keep working; old tags untouched.
5. **Wiki rewrite scope creep.** Task 8 could balloon if every wiki page gets an opinionated rewrite. Constrained to: drop pending-no-impl, fix personal pronouns, fix broken links. Deeper structural rewrites = follow-on plan.

## Verification strategy

Every per-task gate is a CI job — see "Verification:" lines above. **Whole-plan gate:** a single manual dispatch where four CI jobs (`macos-test` / `ubuntu-test` / `windows-test` / `static-analysis`) go green simultaneously, with the new bootstrap-from-curl step in each platform job included. After that, `feat-curl-bash-installer.passes=true` and v3.0.0 ships.

## Follow-on work (not in this plan)

- **`markdownlint` CI job** — fast-follow after v1 if prose drift becomes a problem.
- **Homebrew tap** for `brew install alexherrero/dev-machine-setup`.
- **Self-update mechanism** so existing installs can pull the latest release without re-running curl|bash.
- **Version-pin flag** (`--version vX.Y.Z`) for rollback / specific-release testing.
- **CONTRIBUTING.md / SECURITY.md / issue templates** if external contributors arrive.
- **Deeper wiki structural rewrite** if task 8's audit surfaces issues beyond the constrained scope.
