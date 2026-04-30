# How to install via the one-liner bootstrap

> [!NOTE]
> **Status:** implemented
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — `feat-curl-bash-installer`, tasks 5–6.
> **Goal:** Bootstrap a fresh Mac, Debian/Ubuntu host, or Windows machine from zero to a fully configured AI-first dev environment with a single command — no `git clone` required.
> **Prereqs:** `curl` (or `wget`) on POSIX; PowerShell 7+ recommended on Windows (5.1 likely works for the bootstrap itself but isn't routinely tested); admin / sudo on the target host; internet access.

The one-liner pulls the latest tagged release, extracts it to a tempdir, and execs the same `setup.sh` / `setup.ps1` orchestrator the `git clone` flow uses. The `git clone` flow keeps working — see [Bootstrap a new Mac](Bootstrap-A-New-Mac) / [Bootstrap a new Debian or Ubuntu host](Bootstrap-A-New-Debian-Or-Ubuntu).

## Steps

1. **Run the one-liner for your platform.** macOS / Debian / Ubuntu:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh | bash
   ```

   Windows (recommended — supports flags):

   ```powershell
   $tmp = "$env:TEMP\install.ps1"
   Invoke-WebRequest -UseBasicParsing `
       -Uri 'https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.ps1' `
       -OutFile $tmp
   & $tmp
   ```

2. **Reload your shell** so PATH and rc-file additions take effect (`exec $SHELL -l` on POSIX; open a new PowerShell window on Windows).

3. **Complete the auth checklist** printed at the end of the run (`claude login`, `gh auth login`, etc.). The orchestrator's `auth-checklist` stage is the last thing it prints before exiting.

The bootstrap prints the extract dir on exit (e.g. `/tmp/dev-machine-setup.XXXXXX/dev-machine-setup-3.0.0/` or `%TEMP%\dev-machine-setup-bootstrap-<id>\dev-machine-setup-3.0.0\`). Re-running `setup.sh` / `setup.ps1` from that dir skips the download.

## Variants

### macOS / Linux — with `--with-codex`

```bash
curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh \
  | bash -s -- --with-codex
```

The `-s --` is the standard `bash` idiom for forwarding args to a script read from stdin. Other supported flags pass through the same way: `--skip-apps`, `--dry-run`, `--only <stage>`. See [Scripts reference](../reference/Scripts) for the full list.

### Windows — with `-WithCodex` (recommended temp-file pattern)

```powershell
$tmp = "$env:TEMP\install.ps1"
Invoke-WebRequest -UseBasicParsing `
    -Uri 'https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.ps1' `
    -OutFile $tmp
& $tmp -WithCodex
```

The temp-file pattern is the only form that lets PowerShell bind named parameters correctly. Use this whenever you need flags (`-WithCodex`, `-SkipApps`, `-DryRun`, `-Only <stage>`).

### Windows — simple form (no args)

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.ps1 | iex
```

`iwr | iex` works for default installs but cannot forward flags — PowerShell parses params from the script's own command line, which `iex` doesn't expose. Reach for the temp-file pattern as soon as you need any flag.

### Inspect-before-run (recommended security posture)

Don't pipe code from the internet straight to a shell unless you've read it. The audit-then-execute form mirrors Homebrew's stance:

```bash
# POSIX
curl -fsSL https://raw.githubusercontent.com/alexherrero/dev-machine-setup/main/install.sh -o /tmp/install.sh
less /tmp/install.sh   # read it
bash /tmp/install.sh --with-codex
```

```powershell
# Windows — same pattern as the recommended flag-forwarding form
$tmp = "$env:TEMP\install.ps1"
Invoke-WebRequest -UseBasicParsing -Uri '…/install.ps1' -OutFile $tmp
notepad $tmp           # read it
& $tmp -WithCodex
```

Trust model details: see [Public curl|bash installer — design](../explanation/Public-Curl-Bash-Installer#trust-model).

## Verify

The bootstrap prints the extract dir on exit and execs the orchestrator. The orchestrator runs `verify-install.sh` (POSIX) / `verify-install.ps1` (Windows) as the penultimate stage and emits a summary like `30 ok / 0 warn / 0 skip` (Mac baseline). If any line warns, the script tells you the exact remediation.

To re-run verification later without redoing the install:

```bash
cd /tmp/dev-machine-setup.XXXXXX/dev-machine-setup-3.0.0   # path printed by install.sh
./scripts/verify-install.sh
```

```powershell
cd $env:TEMP\dev-machine-setup-bootstrap-<id>\dev-machine-setup-3.0.0
.\scripts\verify-install.ps1
```

See [Scripts reference](../reference/Scripts) for the canonical entry-point table.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `install.sh: neither curl nor wget is on PATH — install one and retry` | The bootstrap exits early with this message on hosts where neither downloader is present (rare — both ship in default macOS and Debian/Ubuntu images). Install via your package manager (`apt-get install -y curl`) and retry. |
| `install.sh: could not parse tag from /releases/latest redirect` | GitHub returned an unexpected response (network blocked, repo renamed, or no releases yet). Visit `https://github.com/alexherrero/dev-machine-setup/releases/latest` in a browser to confirm a release exists; if so, retry. |
| Windows: `Expected 302 redirect from …/releases/latest` | Same root cause as the POSIX tag-parse failure — confirm a release exists and the redirect is reachable from your network. |
| Windows: `iwr … \| iex` ignored my `-WithCodex` flag | Expected — `iex` doesn't forward params. Use the temp-file pattern under Variants → Windows recommended. |
| `setup.sh: unsupported OS` (exit 2) | The orchestrator only supports macOS (Darwin) and Debian-family Linux. Other distros: clone the repo and adapt the stage scripts manually. |
| Re-running fails with permission errors on `/tmp/dev-machine-setup.XXXXXX/` | The OS reaped the tempdir between runs. Re-run the one-liner — the new tempdir has fresh permissions. |

## Related

- [Public curl|bash installer — design](../explanation/Public-Curl-Bash-Installer) — why the bootstrap looks the way it does, and the trust model.
- [Scripts reference](../reference/Scripts) — flags, exit codes, files written.
- [Bootstrap a new Mac](Bootstrap-A-New-Mac) — the equivalent flow via `git clone`.
- [Bootstrap a new Debian or Ubuntu host](Bootstrap-A-New-Debian-Or-Ubuntu) — Linux equivalent via `git clone`.
