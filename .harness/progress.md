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
