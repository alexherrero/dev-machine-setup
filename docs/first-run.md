# First-run auth checklist

`setup.sh` (POSIX) and `setup.ps1` (Windows) install the tooling and
place configs, but a few things require a human: browser-based oauth
flows and (on Mac and Windows) GUI sign-ins. Complete these in any
order on a freshly-bootstrapped machine.

This page has three sections — pick the one matching your platform:

- [Mac](#mac) — 5 steps (or 6 with `--with-codex`)
- [Debian / Ubuntu](#debian--ubuntu) — 3 steps (or 4 with `--with-codex`).
  No GUI sign-ins; CLI-only scope.
- [Windows](#windows) — 5 steps. Codex is currently not installed on
  Windows even with `-WithCodex` (upstream npm package broken — see
  `docs/windows.md`).

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

## Windows

Full GUI + CLI scope, mirroring Mac. `setup.ps1` installs Antigravity
Desktop, Claude Desktop (via `winget`), the Claude Code / Gemini CLIs,
and the captured config files; the steps below cover the manual auth
that follows. Codex on Windows is currently skip-with-warn (the
`@openai/codex` npm package is broken — see
[`docs/windows.md`](windows.md#codex-on-windows)).

### 1. `claude login`

Same as Mac. Installed by [scripts/install-clis.ps1](../scripts/install-clis.ps1)
via `winget install Anthropic.ClaudeCode` (the system-managed install
path; doesn't auto-update — `winget upgrade Anthropic.ClaudeCode`
periodically). Opens a browser for Anthropic oauth.

### 2. `gh auth login`

Same as Mac. On Windows, `gh` is installed via
[scripts/install-tooling.ps1](../scripts/install-tooling.ps1)
(`winget install GitHub.cli`) — not Homebrew.

### 3. `gemini` (first run)

Same as Mac. Installed via `npm install -g @google/gemini-cli`. The
default Windows npm prefix is `%APPDATA%\npm`; the script ensures it's
on user PATH so `gemini` resolves in any new shell.

### 4. Open Antigravity from the Start menu

Launches Antigravity Desktop and walks you through Google-account
sign-in. Installed by
[scripts/install-gui-apps.ps1](../scripts/install-gui-apps.ps1) via
`winget install Google.Antigravity`. Settings persist under
`%APPDATA%\Antigravity\` (per
[`docs/windows.md`](windows.md#what-this-script-does-not-do)).

### 5. Open Claude from the Start menu

Launches Claude Desktop for Anthropic-account sign-in. Installed via
`winget install Anthropic.Claude` (distinct from the CLI's
`Anthropic.ClaudeCode`). MCP-server configuration is managed via the
desktop app's UI, not via a hand-edited
`claude_desktop_config.json` — see
[`docs/windows.md`](windows.md#what-this-script-does-not-do) for the
MSIX-redirect rationale.

### Codex on Windows *(no checklist step)*

Codex is **not** installed on Windows in this scope, even when
`-WithCodex` is passed — the `@openai/codex` npm package is currently
broken on Windows (cites
[openai/codex#18648](https://github.com/openai/codex/issues/18648),
[#11744](https://github.com/openai/codex/issues/11744)). Mac and Linux
still install Codex normally. Revisit when upstream fixes the package.

---

## What setup leaves behind

After the checklist is done:

- **`CLAUDE.md`** → on Mac/Linux, `~/.claude/CLAUDE.md` is a symlink to
  [configs/claude/CLAUDE.md](../configs/claude/CLAUDE.md) so edits sync
  both ways. On Windows the same holds when Developer Mode (or admin)
  is on; otherwise the script falls back to a plain copy and prints a
  warning — repo edits then need a re-run to propagate.
- **App-managed JSON configs** (`~/.claude/settings.json`,
  `~/.gemini/settings.json`, `~/.antigravity/argv.json`,
  **Mac-only** Claude Desktop config) → seeded once from `configs/` on
  a fresh machine, then owned by the tools themselves (they rewrite in
  place). Re-run [scripts/capture.sh](../scripts/capture.sh) to pull
  current state back into the repo. The Claude Desktop config is
  Mac-only; everything else seeds on Mac, Linux, and Windows. On
  Windows, Claude Desktop's MSIX redirect makes its config effectively
  unmanageable from outside the app (see
  [`docs/windows.md`](windows.md#what-this-script-does-not-do)).
- **PATH** is appended differently per platform:
  - Mac and Debian-with-zsh: `~/.zshrc` marker block
    (`~/.local/bin` for claude; `~/.antigravity/antigravity/bin` for
    antigravity-cli on Mac).
  - Debian-with-bash: `~/.bashrc` (same marker; adds `~/.npm-global/bin`
    for npm globals).
  - Windows: persistent user PATH entries via
    `[Environment]::SetEnvironmentVariable(... 'User')` — no rc-file
    equivalent. New shells inherit automatically.
  - All marker blocks are safe to edit above or below the marker line.
- **`~/.gitconfig`** → `user.name` + `user.email` set via
  `git config --global`. Other gitconfig state (includes, credential
  helpers, signing config) is untouched.
- **Backup directory** → `~/.dev-machine-setup-backup/<utc-timestamp>/`
  (Mac/Linux) or `%USERPROFILE%\.dev-machine-setup-backup\<utc>\`
  (Windows) holds any pre-existing config files that `link-configs`
  displaced. Safe to delete once you've confirmed nothing was lost.
