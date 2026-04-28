# First-run auth checklist

`setup.sh` installs the tooling and places configs, but a few things
require a human: browser-based oauth flows and (on Mac) GUI sign-ins.
Complete these in any order on a freshly-bootstrapped machine.

This page has two sections — pick the one matching your platform:

- [Mac](#mac) — 5 steps (or 6 with `--with-codex`)
- [Debian / Ubuntu](#debian--ubuntu) — 3 steps (or 4 with `--with-codex`).
  No GUI sign-ins; CLI-only scope.

---

## Mac

### 1. `claude login`

Signs you in to the Claude Code CLI. Opens a browser for Anthropic oauth
and writes the session state under `~/.claude.json` (which is explicitly
**not** captured into this repo — each machine regenerates it).

Installed by [scripts/install-clis.sh](../scripts/install-clis.sh) via
Anthropic's official curl installer (lands at `~/.local/bin/claude`).

### 2. `gh auth login`

Signs you in to GitHub. Prefer: `GitHub.com` → `HTTPS` → `Login with a
web browser`. Needed for `gh pr create`, `gh release create`, and the
`ship-release` skill defined under
[.claude/skills/ship-release/SKILL.md](../.claude/skills/ship-release/SKILL.md).

Installed as a formula by
[scripts/install-brew.sh](../scripts/install-brew.sh).

### 3. `gemini` (first run)

The Gemini CLI doesn't have a dedicated `login` subcommand — the first
invocation kicks off Google oauth in your browser. Just run `gemini` at
a prompt and follow the redirect.

Installed as an npm global (`@google/gemini-cli`) by
[scripts/install-clis.sh](../scripts/install-clis.sh).

### 4. `codex login` *(only if installed with `--with-codex`)*

Signs you in to the OpenAI Codex CLI. Opens a browser for OpenAI oauth
or accepts a pasted API key. Skip this step entirely if you didn't pass
`--with-codex` to `setup.sh` (Codex is opt-in; default off).

Installed as an npm global (`@openai/codex`) by
[scripts/install-clis.sh](../scripts/install-clis.sh) when
`WITH_CODEX=1`.

### 5. `open -a Antigravity`

Launches the Antigravity app and walks you through sign-in with the
Google account you want it tied to. First launch also writes
`~/.antigravity/argv.json` (our captured version is seeded only if
absent, since Antigravity rewrites it in place — see
[scripts/link-configs.sh](../scripts/link-configs.sh)).

Installed via the browser-assisted installer
[scripts/install-gui-apps.sh](../scripts/install-gui-apps.sh) — you
dragged the `.app` into `/Applications` yourself.

### 6. `open -a Claude`

Launches Claude Desktop for Anthropic account sign-in. Preferences
persist under `~/Library/Application Support/Claude/`; MCP extensions
and their settings live in the same directory.

Installed via the browser-assisted installer
[scripts/install-gui-apps.sh](../scripts/install-gui-apps.sh).

---

## Debian / Ubuntu

CLI-only scope: no GUI apps (Antigravity, Claude Desktop, Gemini Desktop)
are installed on Debian. The first-run list is the same as Mac steps 1–4
minus the GUI sign-ins.

### 1. `claude login`

Same as Mac. Installed by
[scripts/install-clis.sh](../scripts/install-clis.sh) via Anthropic's
curl installer (lands at `~/.local/bin/claude`); the installer detects
Linux and drops the same binary.

### 2. `gh auth login`

Same as Mac. On Debian, `gh` is installed via the official GitHub CLI
apt repo configured by
[scripts/install-apt.sh](../scripts/install-apt.sh) — not as a brew
formula.

### 3. `gemini` (first run)

Same as Mac. First `gemini` invocation triggers Google oauth in your
browser. Installed via the same `npm install -g @google/gemini-cli`
path; the npm prefix on Debian is `~/.npm-global` (configured by
[scripts/install-clis.sh](../scripts/install-clis.sh)).

### 4. `codex login` *(only if installed with `--with-codex`)*

Same as Mac. Opt-in via the `--with-codex` flag.

---

## What `setup.sh` leaves behind

After the checklist is done:

- `~/.claude/CLAUDE.md` → symlinked into
  [configs/claude/CLAUDE.md](../configs/claude/CLAUDE.md) (edits sync
  both ways).
- `~/.claude/settings.json`, **Mac-only** Claude Desktop config, Gemini
  settings, Antigravity `argv.json` → seeded once from `configs/` on a
  fresh machine, then owned by the tools themselves (they rewrite in
  place). Re-run [scripts/capture.sh](../scripts/capture.sh) to pull the
  current state back into the repo. The Claude Desktop config is the
  only Mac-only path; everything else seeds on both platforms.
- `~/.zshrc` (Mac and Debian-with-zsh) or `~/.bashrc` (Debian-with-bash)
  → a marker block appends the PATH lines the tools need (`~/.local/bin`
  for claude; `~/.npm-global/bin` on Debian for npm globals;
  `~/.antigravity/antigravity/bin` for antigravity-cli on Mac). Safe to
  edit above or below the marker.
- `~/.gitconfig` → `user.name` + `user.email` set via
  `git config --global`. Other gitconfig state (includes, credential
  helpers, signing config) is untouched.
- `~/.dev-machine-setup-backup/<utc-timestamp>/` → any pre-existing
  config files that `link-configs.sh` displaced. Safe to delete once
  you've confirmed nothing was lost.
