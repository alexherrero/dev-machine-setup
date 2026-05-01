# Progress

Append-only log. Newest entries at the bottom. Format: `<YYYY-MM-DD HH:MM> /<phase> — <one-line summary>`.

---
2026-04-22 23:07 /plan — created plan "One-shot Mac dev-machine setup" with 9 tasks
2026-04-22 23:25 /work — completed task 1: "Scaffold the setup-scripts layout" (4 files, 0 tests added)
2026-04-22 23:31 /work — completed task 2: "Capture current machine configs into configs/" (8 files, 0 tests added)
2026-04-23 06:48 /work — completed task 3: "Write the Homebrew install script" (4 files, 0 tests added)
2026-04-23 07:03 /work — completed task 4: "Write the CLI-install script" (3 files, 0 tests added)
2026-04-24 01:55 /work — completed task 5: "Write the GUI-apps install script" (1 file, 0 tests added) — browser-assisted (direct-URL curl infeasible: CF JS challenge on Claude, no canonical URL for Antigravity/Gemini)
2026-04-24 02:07 /work — completed task 6: "Write the config-link script" (1 file, 0 tests added) — confirmed Claude Code + Claude Desktop rewrite their JSONs in place; used copy-if-absent for all app-owned JSON, symlink for CLAUDE.md only, append-with-marker for zshrc, git config --global merge for user info. Backup under ~/.dev-machine-setup-backup/<utc>/, lazy-created.
2026-04-24 02:20 /work — completed task 7: "Wire the top-level orchestrator" (1 file, 0 tests added) — setup.sh with --dry-run / --skip-apps / --only <stage> / --help; missing stage scripts warn+skip (supports in-progress plan); all flag paths verified including real --only link-configs run. First commit using conventional-commit `feat:` prefix per ship-release skill classification rules (calibration noted earlier in session).
2026-04-24 02:30 /work — completed task 8: "Post-setup auth checklist" (2 files, 0 tests added) — scripts/auth-checklist.sh prints the 5 manual steps; docs/first-run.md documents each with provisioning-source references. Orchestrator now finds the script (no longer warn-skipped).
2026-04-24 02:45 /work — completed task 9: "Windows stubs" (7 files, 0 tests added) — setup.ps1 mirrors setup.sh shape (same stages, same flags); five per-stage .ps1 stubs print banner + TODO + exit 0; docs/windows.md covers deferral rationale + per-stage remaining-work table. verify.sh no-ops cleanly on .ps1 without pwsh (AST check deferred to Windows reference VM). All 9 PLAN tasks now complete.

## compaction event — 2026-04-24T01:45:13Z
- trigger: auto
- branch: main
- The session was compacted at this point. To re-anchor on the
  in-flight task, read .harness/PLAN.md and the entries above
  this marker. The compaction summary alone is not enough.

## compaction event — 2026-04-24T22:17:17Z
- trigger: auto
- branch: main
- The session was compacted at this point. To re-anchor on the
  in-flight task, read .harness/PLAN.md and the entries above
  this marker. The compaction summary alone is not enough.

## /plan — feat-debian-cli-support — 2026-04-27
- Drafted 8-task plan for Debian CLI-only support in .harness/PLAN.md
- features.json: appended feat-debian-cli-support (passes: false)
- Open question 1: include Codex CLI? (recommend yes)
- Next: /work after open questions resolved

## /work — feat-debian-cli-support task 1 — 2026-04-27
- scripts/lib/os.sh: OS detection helper (macos|debian|exit 2). External $OS override path validates against allowed values.
- setup.sh: sources os.sh, builds per-OS STAGE_* arrays. Mac: 6 stages unchanged. Debian: 5 stages (apt instead of brew, no gui-apps).
- Verified: shellcheck clean; Mac auto-detect works; OS=debian forced works; OS=plan9 exits 2; --only validates per-OS list.

## /work — feat-debian-cli-support task 2 — 2026-04-27
- scripts/install-apt.sh: NodeSource (node 22 LTS) + GitHub CLI apt repos with explicit keyrings, apt-installs nodejs/gh/jq/ripgrep/shellcheck/shfmt, shfmt fallback to GitHub release binary on older distros (Debian 11, Ubuntu 22.04).
- Idempotent: keyring + sources.list writes guarded by file-exists checks. Defensive Mac guard exits 2 before any sudo if OS != debian.
- Verified: shellcheck -x clean, bash -n clean, Mac guard fires correctly, setup.sh dispatch resolves install-apt.sh as the apt stage on Debian. Runtime VM verification deferred to /release.

## /work — feat-debian-cli-support task 3 — 2026-04-27
- scripts/install-clis.sh: cross-platform (sources os.sh), per-OS rc_file() picker, Debian npm-prefix at ~/.npm-global, Node ≥ 20 guard on Debian, Codex CLI added as third install (@openai/codex).
- Live run on Mac: claude 2.1.112 + gemini 0.39.1 + codex 0.125.0 (new). Idempotent re-run preserves PATH markers.
- Verified: shellcheck -x clean; rc_file() correct on debian/zsh, debian/bash, mac; harness verify.sh ok.

## /work — feat-debian-cli-support task 3 amendment — 2026-04-27
- Codex re-scoped from always-installed to opt-in via --with-codex flag (WITH_CODEX=1).
- setup.sh: --with-codex flag added; exports WITH_CODEX to env. install-clis.sh: Codex install + post-check entry both gated.
- Codex uninstalled from this Mac. Default run skips Codex with informative banner; post-check verifies only claude+gemini.
- Tasks 5 (verify-install) and 6 (auth-checklist) updated to honor the same flag conditionally.

## /work — feat-debian-cli-support task 4 — 2026-04-27
- scripts/lib/os.sh: rc_file() helper centralized (moved from install-clis.sh).
- scripts/install-clis.sh: uses shared rc_file() instead of local copy.
- scripts/link-configs.sh: sources os.sh; Claude Desktop block gated on OS==macos; append_zshrc_additions renamed to append_shell_additions and routes via rc_file(); post-check JSON list excludes ~/Library/... on Debian.
- Verified: Mac re-run no-op; OS=debian forced run skips Mac-only path correctly and validates 3 JSONs; rc_file() correct across debian/zsh, debian/bash, macos.

## /work — feat-debian-cli-support task 5 — 2026-04-28
- scripts/verify-install.sh: sources os.sh; brew Mac-only; GUI-apps + Library JSON consolidated to one OS==macos block (single SKIP on Debian); codex PATH+version conditional on WITH_CODEX (SKIP with hint when off); check_rc_marker replaces check_zshrc_marker via shared rc_file().
- Verified: Mac default 30 ok / 0 warn (baseline preserved); Mac WITH_CODEX=1 30 ok / 1 warn (correct — codex not installed since task 3 amendment); OS=debian forced 25 ok / 0 warn (lost: brew + 3 apps + Library JSON = 5 entries).

## /work — feat-debian-cli-support task 6 — 2026-04-28
- scripts/auth-checklist.sh: sources os.sh; dynamic steps array; codex login conditional on WITH_CODEX=1; GUI sign-ins Mac-only; OS-specific heading text.
- docs/first-run.md: rewritten with ## Mac (5/6 steps) and ## Debian / Ubuntu (3/4 steps) subsections; optional codex documented in both; trailing "What setup.sh leaves behind" updated for platform-specific paths.
- Verified: 4 configurations all correct (Mac default 5 items, Mac+codex 6, Debian 3, Debian+codex 4). Linux output has no Antigravity/Claude Desktop refs. Codex first-run verified as `codex login` via npx.

## /work — feat-debian-cli-support task 7 — 2026-04-28
- README.md: intro reframed for Mac/Debian/Windows; new ### Debian / Ubuntu Usage subsection with --with-codex documented; expanded Layout per-script tree; Status section gets Debian-ready row.
- docs/debian.md: new (~6.3 KB) — quick-start, supported-distros matrix (Debian 11/12/13 + Ubuntu 20.04/22.04/24.04), Antigravity-GUI-only callout citing official docs, toolchain detail, future-work.
- Verified: README has 3 platform subsections; all 5 internal links from README resolve; all 5 internal links from docs/debian.md resolve; Antigravity-not-supported callout grep-matches.

## /work — feat-debian-cli-support task 8 — 2026-04-28 (CLOSE-OUT)
- features.json: valid (jq empty), feat-debian-cli-support entry well-formed, passes:false (per plan — flips at /release-gate after Debian VM exercise).
- All 8 tasks marked [x] in PLAN.md; plan-level Status: "complete pending VM verification".
- documenter sub-agent dispatched: 1 new wiki page (Bootstrap-A-New-Debian-Or-Ubuntu) + 4 edits (Bootstrap-A-New-Mac flipped pending->implemented, Dev-Machine-Setup-Design rewritten for cross-platform OS-dispatch architecture, Home + _Sidebar index updates).
- 9 flat-namespace wiki links all resolve to .md files. Antigravity-GUI-only callout grep-matches in two wiki pages.
- Remaining work for /release: Debian VM run; flip features.passes=true; final v1.0.0 release.

## /plan — feat-ci-verification — 2026-04-28
- 3-task plan written to .harness/PLAN.md.
- features.json: appended feat-ci-verification (passes:false).
- Scope: workflow_dispatch only, no push/PR/cron triggers; macos-latest + ubuntu-latest full pipeline; windows-latest smoke-only (real Windows = next plan); cancel-in-progress concurrency.
- Next: /work task 1 (write the workflow file).

## /work — feat-ci-verification task 1 — 2026-04-28
- .github/workflows/ci-tests.yml: workflow_dispatch only, cancel-in-progress concurrency, 3 parallel jobs (macos-test, ubuntu-test, windows-test).
- Mac job (macos-latest): --help/--dry-run smoke, end-to-end --skip-apps, verify-install 0-warn assertion (with SKIP_APPS=1), idempotency check, --with-codex variant.
- Ubuntu job (ubuntu-latest): same shape + apt path + negative test for ~/Library/... not created on Linux.
- Windows job (windows-latest): smoke only — orchestrator runs cleanly + AST-parse all .ps1 files.
- Scope expansion: SKIP_APPS env-var support added to setup.sh + verify-install.sh (~10 lines) so Mac --skip-apps reports 0 warns. Mirrors WITH_CODEX pattern. Mac default still 30 ok / 0 warn.
- Verified: actionlint clean; structural YAML correct; SKIP_APPS gating works locally.

## /work — feat-ci-verification task 2 — 2026-04-28
- README.md: GH Actions CI badge added (linked to actions/workflows/ci-tests.yml); new ## Testing section explains manual workflow dispatch flow + cancel-in-progress concurrency.
- docs/debian.md: Future work section rewritten — Reference Debian VM entry replaced by CI-verification pointer at .github/workflows/ci-tests.yml; new "Other Ubuntu / Debian releases" entry flags the shfmt-fallback CI gap.
- "Update prior feat-debian-cli-support plan section" sub-step was a no-op — prior plan was overwritten; equivalent state lives in features.json + CHANGELOG.
- Verified: 6 README + 6 docs/debian.md internal links resolve; anchor target exists.

## /work — feat-ci-verification task 1 follow-up — 2026-04-28 (CI fixes)
- install-apt.sh: install_keyring gains armored=0|1 param; NodeSource key piped through gpg --dearmor (root cause: NO_PUBKEY error in CI run 25087325478).
- link-configs.sh: new ensure_claude_co_authored_by_disabled() merges includeCoAuthoredBy=false into ~/.claude/settings.json post-copy. Fixes Mac CI false-warn on fresh runners where Claude installer creates a default settings.json before our seed runs.
- Verified: merge path adds key when missing; idempotent path skips when already set; Mac SKIP_APPS=1 verify-install reports 26 ok / 0 warn.

## /work — feat-ci-verification task 3 — 2026-04-29 (CLOSE-OUT)
- First three-platform green CI dispatch (run 25087515129): macOS 1m34s + Ubuntu 1m20s + Windows 0m25s all success.
- Required two CI-fix iterations (NodeSource dearmor, Claude kill-switch merge) committed in d67affb.
- features.json: feat-ci-verification.passes and feat-debian-cli-support.passes both flipped to true.
- PLAN.md plan-level Status: complete. All 3 tasks [x].
- Next: ship-release v1.0.0 (explicit version, major bump).

## /plan — feat-windows-cli-support — 2026-04-29
- 9-task plan written to .harness/PLAN.md.
- features.json: appended feat-windows-cli-support (passes:false).
- Scope: Windows = Mac scope (full GUI + CLI). Antigravity + Claude Desktop via winget. Gemini Desktop no first-party app — skipped. Codex skip-with-warn (upstream npm broken). Native Claude installer + winget for everything else. PowerShell-native JSON parsing, no jq on Windows.
- 3 open questions surfaced inline with defaults: (1) Codex skip-with-warn vs GitHub-Release fallback; (2) Claude Code native installer vs winget; (3) Antigravity argv.json path empirical verification.
- Next: confirm open questions then /work task 1.

## /plan — feat-windows-cli-support open-questions resolved — 2026-04-29
- Q1 Codex on Windows: skip-with-warn (default applied).
- Q2 Claude Code install: winget (override of original recommendation; constraints + task 2 updated).
- Q3 Antigravity argv.json: verify-empirically-then-fall-back-to-skip (default applied).
- PLAN.md plan-level Status: in progress. Ready for /work task 1.

## /work — feat-windows-cli-support task 1 — 2026-04-29
- scripts/install-tooling.ps1: winget toolchain installer. Mirrors install-brew.sh / install-apt.sh shape.
- Installs Git.Git (Claude Code dep), OpenJS.NodeJS.LTS, GitHub.cli, BurntSushi.ripgrep.MSVC. Skips jq (PowerShell native), shellcheck, shfmt.
- Pre-flight winget existence check (exit 2 with installer pointer); idempotent skip-if-on-PATH; PATH registry refresh into running shell; post-check loop (git/node/npm/gh/rg).
- Local pwsh AST parse not feasible (pwsh not installed; brew cask needs admin); harness verify.sh accepts the file. Windows CI AST step is the real gate.
- Existing scripts/install-brew.ps1 stub left in place; task 7 will rename the setup.ps1 stage and remove the dead stub.

## /work — feat-windows-cli-support task 2 — 2026-04-29
- scripts/install-clis.ps1: rewritten from stub. Claude via winget (Anthropic.ClaudeCode), Gemini via npm install -g, Codex skip-with-warn (cites openai/codex#18648 in the message).
- Three approved-verb helpers: Update-PathFromRegistry, Add-DirToUserPath, Test-NodeVersion. PSScriptAnalyzer-clean naming.
- Idempotent: skip-if-on-PATH for Claude; npm install -g is naturally idempotent; user-PATH npm-prefix add is dedupe-checked.
- Verified: harness verify.sh ok; CI AST step is the real gate.

## /work — feat-windows-cli-support task 3 — 2026-04-29
- scripts/install-gui-apps.ps1: rewritten from stub. Antigravity Desktop (winget Google.Antigravity), Claude Desktop (winget Anthropic.Claude). Gemini Desktop explicitly skipped (no first-party app).
- Single Install-WingetApp helper handles known winget exit codes: 0 → ok; NO_APPLICATIONS_FOUND → skip-with-warn + manual-URL pointer; other non-zero → generic warning (verify-install is the source of truth).
- Empirical Antigravity winget-id correctness verification waits for the first real task-8 dispatch.

## /work — feat-windows-cli-support task 4 — 2026-04-29
- scripts/link-configs.ps1: rewritten from stub. Mirror of link-configs.sh with PowerShell-native helpers and Windows-specific symlink fallback.
- Five config placements: CLAUDE.md symlink-with-copy-fallback, claude/gemini/antigravity JSON copy-if-absent, explicit skip for MSIX-mess Claude Desktop config.
- Co-Authored-By kill-switch merge via ConvertFrom-Json/ConvertTo-Json roundtrip (no jq dep on Windows).
- Strict-JSON validation via ConvertFrom-Json; JSONC for argv.json strips // comments via regex.
- Antigravity argv.json placed at VSCode-convention path; empirical verification waits for task 8 CI.

## /work — feat-windows-cli-support task 5 — 2026-04-29
- scripts/verify-install.ps1: rewritten from stub. Mirror of verify-install.sh; PowerShell-native helpers (no jq dep).
- Two tiers (global + harness, same as bash version). Codex skip-only on Windows; SKIP_APPS=1 consolidates GUI checks; symlink-or-copy both OK.
- Test-WindowsApp: registry uninstall-key search across HKLM + HKLM/WOW6432Node + HKCU. Limitation: pure-MSIX installs may register elsewhere — flagged for follow-on.
- PostToolUse hook check uses ConvertTo-Json -Compress + regex match for verify.sh, mirroring jq tostring/test pattern.
- Local pwsh AST not run; CI AST step is the gate.

## /work — feat-windows-cli-support task 6 — 2026-04-29
- scripts/auth-checklist.ps1: rewritten from stub. 5 numbered items (claude, gh, gemini, Antigravity, Claude Desktop) regardless of WITH_CODEX since Codex is skip-only on Windows.
- Codex note appended at end with WITH_CODEX-aware message.
- pscustomobject array + auto-numbering loop. PowerShell-native, no jq/bash artifacts.

## /work — feat-windows-cli-support task 7 — 2026-04-29
- setup.ps1: stage `brew` renamed to `tooling` (script install-tooling.ps1); Desc strings rewritten; -WithCodex switch added; both -SkipApps and -WithCodex now set $env:SKIP_APPS / $env:WITH_CODEX for sub-stage scripts.
- Help text rewrites: lists all 6 stages, documents Codex Windows caveat.
- scripts/install-brew.ps1 deleted (dead stub from feat-debian-cli-support task 9).
- Six .ps1 stage scripts now wired up. Coupled with task 8 (CI workflow upgrade) — running CI between task 7 and 8 would exercise the full pipeline without -SkipApps. Saving dispatch for after task 8.

## /work — feat-windows-cli-support task 8 — 2026-04-29
- ci-tests.yml windows-test: 5-step smoke → 8-step real install pipeline. Symmetric with macos-test and ubuntu-test.
- New steps: end-to-end -SkipApps, verify-install 0-warn assertion (with SKIP_APPS=1 env), idempotency git-status check, -WithCodex exits 0 + codex-NOT-on-PATH invariant, AST-parse preserved.
- Job timeout bumped 10m → 30m to match Mac install budget. Job name: "Windows smoke" → "Windows".
- actionlint clean. Empirical verification on next CI dispatch.

## /work — feat-windows-cli-support task 8 — 2026-04-29 (CI green)
- ci-tests.yml windows-test: smoke → real install pipeline.
- Five CI iterations to land green: Write-Host capture, $Desc: parse error, two PATH-from-registry refresh sites (setup.ps1 stage loop + verify-install step), verify.out drift fix.
- Run 25142962483: all three jobs green simultaneously.

## /work — feat-windows-cli-support task 9 — 2026-04-29 (CLOSE-OUT)
- docs/windows.md: rewritten. Drops "deferred/TODO" framing. Quick-start, supported-version table, Codex/winget-vs-native/Dev-Mode-symlink/MSIX-mess sections, file layout, future work, references.
- README: Windows status flipped to ready. Testing section drops the smoke framing.
- features.json: feat-windows-cli-support.passes = true. All three features now pass.
- PLAN.md plan-level Status: complete.
- Next: v2.0.0 release.

## compaction event — 2026-04-30T01:54:41Z
- trigger: manual
- branch: main
- The session was compacted at this point. To re-anchor on the
  in-flight task, read .harness/PLAN.md and the entries above
  this marker. The compaction summary alone is not enough.

## /plan — feat-curl-bash-installer — 2026-04-30T04:14:30Z
- 10 tasks: deep audit, LICENSE, static-analysis CI, visibility flip, install.sh, install.ps1, README rewrite, wiki polish, bootstrap-from-curl CI, v3.0.0.
- All verification gates moved to CI (new static-analysis job).
- README style ref: TsekNet/converge.
- Confirmed: MIT license; .harness/progress.md kept as-is; lychee only in v1, markdownlint as fast-follow.
- Next: /work to start on task 1 (audit).

## /work — feat-curl-bash-installer task 1 — 2026-04-30T04:52:20Z (audit complete)
- 6-track pre-public audit run; 0 secrets in tree or history; 1 LEAK fixed (genericized /Users/alex/ path); 4 placeholder pages dropped; 3 stale wiki status lines bumped to v2.0.0.
- Decisions: kept .gitconfig noreply email; kept PLAN.md "I" usages.
- Audit-as-CI-step lands in task 3 (static-analysis job).
- Next: /work task 2 (LICENSE).

## /work — feat-curl-bash-installer task 2 — 2026-04-30T05:42:18Z (LICENSE)
- LICENSE added at repo root: standard MIT text, Copyright (c) 2026 Alex Herrero.
- README gained ## License section pointing at LICENSE.
- CI gate (test -f / test -s) wires up in task 3 (static-analysis job).
- Next: /work task 3 (static-analysis CI job).

## /work — feat-curl-bash-installer task 3 — 2026-04-30T06:20:24Z (static-analysis CI green)
- Static-analysis job added: shellcheck + actionlint + pwsh AST + lychee + audit regex + LICENSE check.
- 3 dispatches to land green: (a) excluded .harness/ vendored from shellcheck/AST/lychee; (b) narrowed lychee scope to README/CHANGELOG/docs/ (skip wiki + AGENTS/CLAUDE meta-docs).
- CI green on run 25150482876: static-analysis 12s + Mac 1m12s + Ubuntu 2m28s + Windows 2m48s.
- The named gate every remaining task references is now in place.
- Next: /work task 4 (visibility flip to public).

## /work — feat-curl-bash-installer task 4 — 2026-04-30T06:24:05Z (PUBLIC)
- Repo visibility flipped to PUBLIC via `gh repo edit ... --visibility public --accept-visibility-change-consequences`.
- Three unauth checks pass: raw.githubusercontent.com README, releases/latest API, archive tarball download (200 / 130KB).
- CHANGELOG [Unreleased] section added: visibility flip + LICENSE + static-analysis.
- Re-dispatch CI to confirm post-flip jobs still green.
- Next: /work task 5 (install.sh POSIX bootstrap).

## /work — feat-curl-bash-installer task 5 — 2026-04-30T13:56:14Z (install.sh CI green)
- install.sh added: bash bootstrap. curl/wget; HTML-redirect tag parse (no API rate limit); mktemp -d → tarball → extract → exec setup.sh "$@".
- 2 iterations to land green: (1) macos-latest hit HTTP 403 on the JSON API; (2) switched to /releases/latest redirect (resolved).
- CI green on run 25169301931: 4/4 jobs incl. bootstrap-from-curl on Mac + Ubuntu.
- Documenter: all 3 pending wiki pages held pending until task 6 (install.ps1) — atomic flip with the Windows mirror.
- Next: /work task 6 (install.ps1).

## /work — feat-curl-bash-installer task 6 — 2026-04-30T14:08:00Z (install.ps1 CI green)
- install.ps1 added: PowerShell mirror of install.sh. Pre-applied task 5 redirect-Location lesson (no API rate limit).
- @PSBoundParameters splatting forwards args. windows-test CI step uses temp-file pattern.
- CI green on first dispatch (run 25169710091): 4/4 jobs incl. bootstrap-from-iwr on Windows.
- Documenter flipped 3 pending wiki pages to implemented (Public-Curl-Bash-Installer, Install-Via-One-Liner, Scripts.md) — bootstrap pair complete.
- Next: /work task 7 (README rewrite in converge style).

## /work — feat-curl-bash-installer task 7 — 2026-04-30T23:41:11Z (README rewrite CI green)
- README.md rewritten in converge style: centered title + badges, ## Install (one-liners first), Quick start, tables for What gets installed / Stages / Flags / Documentation / Testing.
- docs/architecture.md added (cut content: Layout tree, OS-dispatch arch, trade-offs, agentic-harness pointer).
- New readme-shape CI step (10 grep checks) catches accidental section-rename / badge-removal in PRs.
- CI green on first dispatch (run 25170296627): 4/4 jobs.
- Documenter flagged wiki/explanation/Dev-Machine-Setup-Design.md missing Windows row → deferred to task 8.
- Next: /work task 8 (wiki + docs polish).

## /work — feat-curl-bash-installer task 8 — 2026-05-01T03:34:38Z (wiki/docs polish)
- wiki/explanation/Dev-Machine-Setup-Design.md: Windows row added to Shape + Component table; xcode dropped; Bootstrap row added; Trade-offs expanded.
- wiki/how-to/Bootstrap-A-New-Mac.md + Bootstrap-A-New-Debian-Or-Ubuntu.md: SSH→HTTPS, dropped xcode + Windows-deferred stale claims, mentioned curl|bash, Related sections.
- wiki/Home.md + _Sidebar.md: added Reference + Install-Via-One-Liner + Public-Curl-Bash-Installer entries.
- docs/first-run.md: added Windows section (5 steps) + cross-platform "What setup leaves behind".
- docs/debian.md + windows.md: SSH→HTTPS, dropped CI-scheduled bullet, updated Reference labels.
- 2 CI dispatches both green (run 25200691273 + post-debian/windows fixes).
- Documenter caught 4 real misses in docs/debian.md + docs/windows.md — resolved in scope.
- Next: /work task 9 (bootstrap-from-curl end-to-end CI + features.json).

## /work — feat-curl-bash-installer task 9 — 2026-05-01T03:43:45Z (passes flipped)
- CI dispatch on c50c876: run 25201071711, all 4 jobs green simultaneously incl. bootstrap-from-curl + bootstrap-from-iwr steps.
- features.json: feat-curl-bash-installer.passes false → true. Description refreshed with redirect-Location detail and run reference.
- Deferred (post-v3.0.0): rename the repo. Added to PLAN.md follow-on work; GitHub Issue filed at end of session.
- Next: /work task 10 (v3.0.0 release).
