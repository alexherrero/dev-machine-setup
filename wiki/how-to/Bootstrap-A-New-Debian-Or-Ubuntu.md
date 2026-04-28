# How to bootstrap a new Debian or Ubuntu host

> [!NOTE]
> **Status:** implemented (v0.6.0) — code + docs complete; full pass pending verification on a real Debian VM.
> **Goal:** Take a fresh Debian or Ubuntu host from zero to a working CLI-only AI dev environment — Claude Code, Gemini CLI, optionally OpenAI Codex CLI, plus the `node` / `gh` / `jq` / `ripgrep` / `shellcheck` / `shfmt` toolchain.
> **Prereqs:** `sudo` on the target host; internet access; a supported distro (see the matrix in [`docs/debian.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/debian.md#supported-distros)).

`setup.sh` detects Linux via `scripts/lib/os.sh` and runs a CLI-only plan: `apt → clis → link-configs → verify-install → auth-checklist`. There is no `gui-apps` stage — see [why](#why-no-gui-apps-on-linux) below.

## Steps

1. Clone the repo:
   ```bash
   git clone git@github.com:alexherrero/dev-machine-setup.git
   cd dev-machine-setup
   ```
2. Run the orchestrator:
   ```bash
   ./setup.sh                  # Claude Code + Gemini CLI
   ./setup.sh --with-codex     # also installs the OpenAI Codex CLI
   ```
3. Reload your shell. The script appends to `~/.zshrc` if your `$SHELL` is zsh, otherwise to `~/.bashrc`:
   ```bash
   source ~/.zshrc || source ~/.bashrc
   ```
4. Complete the auth checklist printed at the end (`claude login`, `gemini`, `gh auth login`, optionally `codex login`).

For the in-repo reference — supported-distro matrix, apt-key handling, npm-global prefix rationale, troubleshooting — see [`docs/debian.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/debian.md). This how-to intentionally does not duplicate that content.

## Why no GUI apps on Linux

Antigravity Desktop, Claude Desktop, and Gemini Desktop are macOS / Windows binaries — there is no Linux build. Antigravity is explicitly documented as GUI-first by Google: <https://antigravity.google/docs/command>. The CLI-only scope on Debian is deliberate, not an omission.

## Verify

`scripts/verify-install.sh` runs as the penultimate stage. On Debian, GUI-app and macOS-only-JSON checks emit a single consolidated SKIP; the Codex check is conditional on `--with-codex`. Node must be ≥ 20 — the script hard-fails otherwise.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `npm install -g …` fails with `EACCES` | `install-clis.sh` configures `~/.npm-global` as the npm prefix on Debian to avoid sudo-for-globals. If you ran `npm` as root before this script, re-own `~/.npm` and `~/.npm-global` to your user. |
| `node --version` reports < 20 after `install-apt.sh` | The NodeSource repo install failed silently or your distro is older than the supported matrix. See [`docs/debian.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/debian.md). |
| `shfmt: command not found` after install | The apt package is missing on your distro; `install-apt.sh` falls back to the GitHub-release binary, but the fallback may have failed. Install manually from <https://github.com/mvdan/sh/releases>. |
| `setup.sh` exits 2 with `unsupported OS` | Your platform isn't macOS or Debian-family. Windows is deferred (see `docs/windows.md`); other distros aren't on the roadmap. |

## Related

- [Bootstrap a new Mac](Bootstrap-A-New-Mac) — the GUI + CLI counterpart.
- [Dev-machine setup — design](../explanation/Dev-Machine-Setup-Design) — why the OS-dispatch architecture looks the way it does.
