# Scripts reference

> [!NOTE]
> **Status:** implemented
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — `feat-curl-bash-installer`, tasks 5–6.

The canonical lookup surface for the repo-root entry-point scripts — the curl|bash bootstrap (`install.sh` / `install.ps1`) and the orchestrators they hand off to (`setup.sh` / `setup.ps1`). Per-stage scripts under `scripts/` are documented inline in the source; this page only covers the public entry points users invoke directly.

## Quick reference

| Script | Platform | Purpose | Entry point for |
|---|---|---|---|
| `install.sh` | macOS / Linux | curl\|bash bootstrap. Resolves the latest release tag from the `/releases/latest` redirect Location header, downloads the source tarball, extracts to `mktemp -d`, execs `setup.sh "$@"`. | `curl -fsSL …/install.sh \| bash` |
| `install.ps1` | Windows | PowerShell bootstrap. Mirror of `install.sh`. Same redirect-Location parse, downloads `.zip`, `Expand-Archive` to `$env:TEMP`, execs `setup.ps1 @PSBoundParameters`. | `iwr …/install.ps1 -OutFile $tmp; & $tmp` (recommended) or `iwr … \| iex` |
| `setup.sh` | macOS / Linux | OS-dispatching orchestrator. Detects `macos` / `debian` via `scripts/lib/os.sh`, runs the per-platform stage list. | `git clone` flow + `install.sh` hand-off. |
| `setup.ps1` | Windows | Windows orchestrator. Implicitly platform-locked (no OS detection needed). | `git clone` flow + `install.ps1` hand-off. |

## Flags

### `install.sh` (POSIX bootstrap)

`install.sh` does not have flags of its own. Every argument after `bash -s --` is forwarded verbatim to `setup.sh`. Examples:

| Invocation | Effect |
|---|---|
| `curl … \| bash` | Default install, latest release. |
| `curl … \| bash -s -- --with-codex` | Install + Codex CLI. |
| `curl … \| bash -s -- --skip-apps --dry-run` | Skip GUI apps, print the stage list without executing. |
| `curl … \| bash -s -- --only verify-install` | Re-run only the verify stage. |

### `install.ps1` (Windows bootstrap)

`install.ps1` declares a `param()` block matching `setup.ps1`'s surface and forwards every bound parameter via `@PSBoundParameters`. Only params the user explicitly supplied are forwarded.

| Flag | Effect |
|---|---|
| `-WithCodex` | Forwards to `setup.ps1 -WithCodex`. (Codex on Windows is currently skip-with-warn — the flag still flows through and changes downstream messages.) |
| `-SkipApps` | Forwards to `setup.ps1 -SkipApps` — skips the `gui-apps` stage. |
| `-DryRun` | Forwards to `setup.ps1 -DryRun` — print the stage list and exit. |
| `-Only <stage>` | Forwards to `setup.ps1 -Only <stage>` — run only the named stage. |
| `-Help` | Forwards to `setup.ps1 -Help`. |

Forwarding only works with the temp-file invocation pattern. `iwr … \| iex` cannot bind named params — see [Install via the one-liner](../how-to/Install-Via-One-Liner#variants).

### `setup.sh` (POSIX orchestrator)

| Flag | Effect |
|---|---|
| `--with-codex` | Also installs the OpenAI Codex CLI (`@openai/codex` via npm). Off by default. Exports `WITH_CODEX=1` to sub-stages. |
| `--skip-apps` | Skips the `gui-apps` stage on macOS (no-op on Debian — no GUI stage). Exports `SKIP_APPS=1`. |
| `--dry-run` | Prints the ordered stage list and exits — no scripts run. |
| `--only <stage>` | Runs only the named stage. Valid: `brew` / `apt`, `clis`, `gui-apps` (macOS only), `link-configs`, `verify-install`, `auth-checklist`. |
| `-h`, `--help` | Prints usage and exits 0. |

`OS=debian ./setup.sh` forces the Debian path on a Mac for testing.

### `setup.ps1` (Windows orchestrator)

| Flag | Effect |
|---|---|
| `-WithCodex` | Sets `$env:WITH_CODEX=1`. Codex on Windows is currently skip-with-warn (cites `openai/codex#18648`, `#11744`); the flag signals user intent and changes the downstream message. |
| `-SkipApps` | Sets `$env:SKIP_APPS=1` and skips the `gui-apps` stage. |
| `-DryRun` | Prints the ordered stage list and exits. |
| `-Only <stage>` | Runs only the named stage. Valid: `tooling`, `clis`, `gui-apps`, `link-configs`, `verify-install`, `auth-checklist`. |
| `-Help` | Prints usage and exits 0. |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | `install.sh` / `install.ps1`: bootstrap failure (download error, missing downloader, archive extraction failure, expected `setup.sh` / `setup.ps1` not found in extracted archive). Message printed to stderr. |
| `2` | `setup.sh`: unsupported OS (not macOS, not Debian-family) or unknown flag / stage name. |
| non-zero | Stage failure — `install.sh` / `install.ps1` propagates the orchestrator's exit code via `exec` (POSIX) / `exit $LASTEXITCODE` (PowerShell). Inspect stderr, the printed extract dir, or `verify-install` output. |

## Files written

| Path | When | Purpose |
|---|---|---|
| `$(mktemp -d -t dev-machine-setup.XXXXXX)/` | `install.sh` run | Per-invocation tempdir. Holds `<tag>.tar.gz` + extracted `dev-machine-setup-<version>/` source tree. Not auto-cleaned — re-run `setup.sh` from there to skip the download. The OS reaps `/tmp` on next reboot. |
| `$env:TEMP\dev-machine-setup-bootstrap-<id>\` | `install.ps1` run | Per-invocation tempdir. Holds `<tag>.zip` + extracted `dev-machine-setup-<version>\` source tree. Not auto-cleaned. `<id>` is an 8-char GUID prefix. |
| `~/.config/...`, `~/Library/Application Support/...`, `%APPDATA%\...` | `link-configs` stage | Captured configs from `configs/` placed at OS-specific config paths. See `scripts/link-configs.{sh,ps1}` for the exact mapping. |

## Source layout

| Path | Purpose |
|---|---|
| `install.sh` | POSIX bootstrap — repo-root, served via `raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh`. |
| `install.ps1` | Windows bootstrap — repo-root, served via `raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.ps1`. |
| `setup.sh` | OS-dispatching orchestrator. |
| `setup.ps1` | Windows orchestrator. |
| `scripts/lib/os.sh` | `detect_os()` — single source of truth for `macos` / `debian` / unsupported. |
| `scripts/install-*.sh` / `scripts/install-*.ps1` | Per-stage installers. |
| `scripts/link-configs.{sh,ps1}` | Place captured configs from `configs/` at their OS locations. |
| `scripts/verify-install.{sh,ps1}` | Penultimate stage; emits the `N ok / N warn / N skip` summary the bootstrap and `git clone` flows both rely on. |
| `scripts/auth-checklist.{sh,ps1}` | Final stage; prints the manual auth steps. |

## Related

- [Install via the one-liner](../how-to/Install-Via-One-Liner) — task-level recipe.
- [Public curl\|bash installer — design](../explanation/Public-Curl-Bash-Installer) — intent, trust model, trade-offs.
- [Bootstrap a new Mac](../how-to/Bootstrap-A-New-Mac) — `git clone` flow on macOS.
- [Bootstrap a new Debian or Ubuntu host](../how-to/Bootstrap-A-New-Debian-Or-Ubuntu) — `git clone` flow on Linux.
