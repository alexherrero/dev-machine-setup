# How to bootstrap a new Mac

> [!NOTE]
> **Status:** implemented (v0.1.0)
> **Goal:** Take a fresh Mac from zero to a fully configured AI-first dev environment — Antigravity, Gemini Desktop, Claude Desktop, the Claude Code / antigravity / gemini CLIs, supporting Homebrew tooling, and all captured config files in place.
> **Prereqs:** Admin on the target Mac; internet access; a GitHub account with access to this repo.

`setup.sh` detects macOS via `scripts/lib/os.sh` and runs the full GUI + CLI plan: `xcode → brew → clis → gui-apps → link-configs → verify-install → auth-checklist`. Linux runs a different (CLI-only) plan — see [Bootstrap a new Debian or Ubuntu host](Bootstrap-A-New-Debian-Or-Ubuntu).

## Steps

1. Clone the repo:
   ```bash
   git clone git@github.com:alexherrero/dev-machine-setup.git
   cd dev-machine-setup
   ```
2. Run the orchestrator:
   ```bash
   ./setup.sh                  # Claude + Gemini + Antigravity
   ./setup.sh --with-codex     # also installs the OpenAI Codex CLI
   ```
3. Reload your shell so PATH and rc-file additions take effect:
   ```bash
   source ~/.zshrc
   ```
4. Complete the interactive auth checklist printed at the end of the run (`claude login`, `gemini`, `gh auth login`, GUI sign-ins for Antigravity / Claude Desktop / Gemini Desktop, optionally `codex login`).

## Verify

`scripts/verify-install.sh` runs as the penultimate stage. The Mac baseline is **30 ok / 0 warn** — any warning or skip outside that baseline means a step didn't land cleanly.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `command not found: claude` after install | `source ~/.zshrc` (the npm-global PATH addition is appended to the rc file but not exported into the parent shell). |
| Gatekeeper blocks a freshly installed `.app` | Right-click the app in Finder → Open, or run `xattr -dr com.apple.quarantine /Applications/<App>.app`. |
| `verify-install.sh` reports a missing CLI you didn't ask for | Codex is opt-in. Re-run with `./setup.sh --with-codex` if you want it; otherwise the SKIP is expected. |
