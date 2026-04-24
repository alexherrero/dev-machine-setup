# First-run auth checklist

`setup.sh` installs the tooling and places configs, but five things
require a human: browser-based oauth flows and GUI sign-ins. Complete
these in any order on a freshly-bootstrapped Mac.

## 1. `claude login`

Signs you in to the Claude Code CLI. Opens a browser for Anthropic oauth
and writes the session state under `~/.claude.json` (which is explicitly
**not** captured into this repo — each machine regenerates it).

Installed by [scripts/install-clis.sh](../scripts/install-clis.sh) via
Anthropic's official curl installer (lands at `~/.local/bin/claude`).

## 2. `gh auth login`

Signs you in to GitHub. Prefer: `GitHub.com` → `HTTPS` → `Login with a
web browser`. Needed for `gh pr create`, `gh release create`, and the
`ship-release` skill defined under
[.claude/skills/ship-release/SKILL.md](../.claude/skills/ship-release/SKILL.md).

Installed as a formula by
[scripts/install-brew.sh](../scripts/install-brew.sh).

## 3. `gemini` (first run)

The Gemini CLI doesn't have a dedicated `login` subcommand — the first
invocation kicks off Google oauth in your browser. Just run `gemini` at
a prompt and follow the redirect.

Installed as an npm global (`@google/gemini-cli`) by
[scripts/install-clis.sh](../scripts/install-clis.sh).

## 4. `open -a Antigravity`

Launches the Antigravity app and walks you through sign-in with the
Google account you want it tied to. First launch also writes
`~/.antigravity/argv.json` (our captured version is seeded only if
absent, since Antigravity rewrites it in place — see
[scripts/link-configs.sh](../scripts/link-configs.sh)).

Installed via the browser-assisted installer
[scripts/install-gui-apps.sh](../scripts/install-gui-apps.sh) — you
dragged the `.app` into `/Applications` yourself.

## 5. `open -a Claude`

Launches Claude Desktop for Anthropic account sign-in. Preferences
persist under `~/Library/Application Support/Claude/`; MCP extensions
and their settings live in the same directory.

Installed via the browser-assisted installer
[scripts/install-gui-apps.sh](../scripts/install-gui-apps.sh).

## What `setup.sh` leaves behind

After the checklist is done:

- `~/.claude/CLAUDE.md` → symlinked into
  [configs/claude/CLAUDE.md](../configs/claude/CLAUDE.md) (edits sync
  both ways).
- `~/.claude/settings.json`, Claude Desktop config, Gemini settings,
  Antigravity `argv.json` → seeded once from `configs/` on a fresh
  machine, then owned by the tools themselves (they rewrite in place).
  Re-run [scripts/capture.sh](../scripts/capture.sh) to pull the current
  state back into the repo.
- `~/.zshrc` → a marker block appends the PATH lines the tools need
  (`~/.local/bin` for claude, `~/.antigravity/antigravity/bin` for
  antigravity-cli). Safe to edit above or below the marker.
- `~/.gitconfig` → `user.name` + `user.email` set via
  `git config --global`. Other gitconfig state (includes, credential
  helpers, signing config) is untouched.
- `~/.dev-machine-setup-backup/<utc-timestamp>/` → any pre-existing
  config files that `link-configs.sh` displaced. Safe to delete once
  you've confirmed nothing was lost.
