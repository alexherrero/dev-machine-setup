# Project Wiki

Welcome to the dev-machine-setup wiki — human-and-agent-readable documentation for this codebase. The sections below follow the Diátaxis convention ([ADR 0004](https://github.com/alexherrero/agentic-harness/blob/main/wiki/architecture/decisions/0004-diataxis-documentation-spec.md)): each page is written for a single reader intent — doing, looking up, or understanding — and never mixes modes.

> [!NOTE]
> This page is maintained by the `documenter` sub-agent at phase boundaries. Humans may edit it directly; the sub-agent preserves human edits.

## 🔧 How-to guides

Task-focused recipes for users who already know the basics.

- [Install via the one-liner](Install-Via-One-Liner) — `curl | bash` / `irm | iex` bootstrap. No `git` prereq.
- [Bootstrap a new Mac](Bootstrap-A-New-Mac) — fresh Mac → full GUI + CLI dev environment via `git clone`.
- [Bootstrap a new Debian or Ubuntu host](Bootstrap-A-New-Debian-Or-Ubuntu) — fresh Linux host → CLI-only dev environment via `git clone`.

## 📖 Reference

Canonical lookup surface — tables of commands, flags, exit codes, paths.

- [Scripts reference](Scripts) — entry-point scripts (`install.sh`, `install.ps1`, `setup.sh`, `setup.ps1`); flags, exit codes, files written.

## 💡 Explanation

Intent, rationale, and trade-offs — the *why*, not the *how*.

- [Dev-machine setup — design](Dev-Machine-Setup-Design) — intent, shape, and trade-offs of the OS-dispatch orchestrator architecture.
- [Public curl|bash installer — design](Public-Curl-Bash-Installer) — bootstrap layer's intent, trust model, and why the redirect-Location parse beats the JSON Releases API.
- [Architecture decisions](Decisions) — ADRs for non-obvious choices.

## Conventions

See [README](README) for the page templates, filename rules, and stylistic conventions this wiki follows.
