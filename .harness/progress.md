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

## compaction event — 2026-04-24T01:45:13Z
- trigger: auto
- branch: main
- The session was compacted at this point. To re-anchor on the
  in-flight task, read .harness/PLAN.md and the entries above
  this marker. The compaction summary alone is not enough.
