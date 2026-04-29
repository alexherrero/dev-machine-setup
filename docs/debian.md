# Debian / Ubuntu setup

CLI-only scope: `setup.sh` on a Debian or Ubuntu host installs Claude
Code, Gemini CLI, and (optionally, via `--with-codex`) the OpenAI Codex
CLI, plus the supporting toolchain (`node` 22 LTS via NodeSource, `gh`
via GitHub's apt repo, `jq`, `ripgrep`, `shellcheck`, `shfmt`). No GUI
apps — see [Why Antigravity isn't supported on Linux](#why-antigravity-isnt-supported-on-linux)
below.

## Quick start

```bash
git clone git@github.com:alexherrero/dev-machine-setup.git
cd dev-machine-setup
./setup.sh                            # Claude + Gemini
./setup.sh --with-codex               # also Codex CLI
source ~/.zshrc || source ~/.bashrc   # whichever rc file matches your $SHELL
```

Then complete the auth checklist printed at the end of the run, or read
[first-run.md](first-run.md#debian--ubuntu).

## Supported distros

| Distro | Status | shfmt source |
|---|---|---|
| **Debian 13 (Trixie)** | supported | apt |
| **Debian 12 (Bookworm)** | supported | apt |
| **Debian 11 (Bullseye)** | supported | GitHub release fallback |
| **Ubuntu 24.04 LTS (Noble)** | supported | apt |
| **Ubuntu 22.04 LTS (Jammy)** | supported | GitHub release fallback |
| **Ubuntu 20.04 LTS (Focal)** | supported | GitHub release fallback |

Both **amd64** and **arm64** architectures work — `dpkg --print-architecture`
resolves the right NodeSource and GitHub-CLI repo lines, and the shfmt
fallback URL picks the matching binary. Other apt-based distros (Mint,
Pop!_OS, etc.) should work via the same code path but aren't routinely
verified.

Detection: `setup.sh` sources [`scripts/lib/os.sh`](../scripts/lib/os.sh),
which checks `/etc/debian_version` and falls back to `lsb_release -i`.
Anything that's not Darwin or Debian-derived exits 2 with a descriptive
error. You can force the Debian path on a Mac for testing with
`OS=debian ./setup.sh --dry-run`.

## Stage list (Debian)

```
apt              Install apt formulae (NodeSource node 22, gh, jq, ripgrep, shellcheck, shfmt)
clis             Install Claude Code CLI (curl) + Gemini CLI + Codex CLI (npm globals)
link-configs     Place captured configs from configs/ into their OS locations
verify-install   Health-check the install (warn-only — tools, configs, agents, skills)
auth-checklist   Print the manual auth steps (claude login, gh auth login, etc.)
```

The Mac stage list adds a `gui-apps` stage between `clis` and
`link-configs`. On Debian that stage is filtered out at the orchestrator
level — there's nothing to install. `--skip-apps` is therefore a no-op
on Debian.

## What's omitted vs Mac

- **GUI apps**: Antigravity, Claude Desktop, Gemini Desktop. Not
  installed; the `gui-apps` stage is dropped from the Debian stage
  list.
- **Claude Desktop config**: `~/Library/Application Support/Claude/claude_desktop_config.json`
  is Mac-only and never created on Linux.
- **Homebrew**: replaced by apt + NodeSource for Node, with a small
  GitHub-release fallback for `shfmt` on older distros.
- **rc-file destination**: Mac always writes to `~/.zshrc` (the
  captured shell). Debian inspects `$SHELL`: zsh → `~/.zshrc`, anything
  else → `~/.bashrc`. The same `rc_file()` helper drives both
  `install-clis.sh` (Claude PATH, npm globals PATH) and
  `link-configs.sh` (zshrc-additions block).

## Why Antigravity isn't supported on Linux

> Antigravity (Google's agentic IDE) ships an `agy` command-line
> utility, but per the [official command-line docs](https://antigravity.google/docs/command),
> `agy` is **a launcher for the desktop IDE** — it opens windows; there
> is no headless / API-only mode. Google's [own guidance](https://cloud.google.com/blog/topics/developers-practitioners/choosing-antigravity-or-gemini-cli)
> says to use Gemini CLI for terminal/agent workflows.

Including a `.deb` install of the Antigravity desktop app would
contradict the CLI-only scope of the Debian path. If you want the GUI
on Linux later, that's a separate plan (see
[future work](#future-work)).

## Toolchain detail

### Node.js 22 LTS via NodeSource

apt's `nodejs` package lags upstream — Gemini CLI requires Node ≥ 20.
[`scripts/install-apt.sh`](../scripts/install-apt.sh) configures
NodeSource with an explicit keyring under `/etc/apt/keyrings/` and
pins the `node_22.x` channel using NodeSource's `nodistro` codename, so
the same line works across all supported Debian and Ubuntu releases.
Bump the channel to `node_24.x` in the script if you want current
instead of LTS.

### GitHub CLI via official apt repo

The same script adds `cli.github.com/packages stable main` with
`arch=$(dpkg --print-architecture)` so amd64 and arm64 hosts pick the
right binaries.

### npm globals without sudo

`install-clis.sh` configures a user-local npm prefix at `~/.npm-global`
(via `npm config set prefix`) and idempotently appends a PATH marker
to the rc file. This avoids `sudo npm install -g` (which has a long
history of permission-related footguns) while still letting `gemini`
and `codex` resolve as plain commands.

### shfmt fallback

`shfmt` is in apt on Debian 12+ / Ubuntu 24.04+. On older releases
`install-apt.sh` falls back to fetching the matching GitHub-release
binary into `/usr/local/bin/shfmt` — the release tag is resolved via
the `/releases/latest` HTTP redirect (no `jq` dependency, since `jq`
itself may be installing in the same run).

## Future work

- **CI verification** *(scheduled — `feat-ci-verification` plan in
  flight)*. Replaces the original "reference Debian VM" idea: the
  [`ci-tests.yml`](../.github/workflows/ci-tests.yml) workflow runs
  `setup.sh` end-to-end on a fresh `ubuntu-latest` runner whenever
  manually dispatched. When that job passes (alongside the macOS and
  Windows-smoke jobs), `feat-debian-cli-support.passes` flips to
  `true` and v1.0.0 ships. Until then this Debian path is "feature-
  complete via static analysis but not VM-verified".
- **Other Ubuntu / Debian releases.** CI runs on `ubuntu-latest` only
  (currently 24.04 Noble). The shfmt-from-GitHub-release fallback path
  (Debian 11 / Ubuntu 22.04) is not exercised in CI; would need a
  matrix runner. Acceptable gap for now.
- **GUI apps on Linux** (Claude Desktop AppImage / `.deb`, Gemini
  Desktop, etc.) — out of scope here. Open as a separate plan if
  desired.
- **Other distros** (Fedora `dnf`, Arch `pacman`, openSUSE `zypper`,
  Alpine `apk`, NixOS). Out of scope; the os.sh helper exits 2 with
  a clear error on anything that's not Debian-derived.

## Reference

- [first-run.md](first-run.md) — auth checklist for both platforms.
- [windows.md](windows.md) — Windows deferral note.
- [.harness/PLAN.md](../.harness/PLAN.md) — the plan that produced
  Debian support (`feat-debian-cli-support`).
- [scripts/install-apt.sh](../scripts/install-apt.sh) — the apt
  install stage.
- [scripts/lib/os.sh](../scripts/lib/os.sh) — OS detection helper +
  shared `rc_file()`.
