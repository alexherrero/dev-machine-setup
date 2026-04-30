# Public curl|bash installer — design

> [!NOTE]
> **Status:** implemented
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — `feat-curl-bash-installer`, tasks 4–6.

The intent, trust model, and shape of the public one-liner bootstrap (`curl … | bash` on macOS / Linux, `iwr … | iex` or temp-file pattern on Windows) that pins to the latest GitHub release tag and then hands off to the existing `setup.sh` / `setup.ps1` orchestrators.

## Intent

The repo went public to enable a true zero-prereq bootstrap: a fresh Mac or Debian/Ubuntu host (or Windows machine) needs neither `git` nor an SSH key to land in a fully configured AI-first dev environment. The `git clone` flow keeps working — see [Bootstrap a new Mac](../how-to/Bootstrap-A-New-Mac) — but the curl|bash flow removes the bootstrap-the-bootstrap problem.

Two architectural choices anchor the design:

- **Bootstrap pulls a tagged release, not `main`.** `install.sh` / `install.ps1` themselves live at `main` (so the canonical URL never breaks), but they download the source archive for the latest *release tag*. Releases are reviewed and tested; `main` HEAD is not. A user piping `install.sh` to bash gets the same code another user got an hour ago — reproducibility matters more than freshness for a bootstrap.
- **Bootstraps are thin.** They do exactly four things: resolve the latest tag, download the archive, extract to a tempdir, exec the existing `setup.sh` / `setup.ps1` with all user args forwarded. No new install logic — the orchestrators stay the single source of truth.

## Shape

```
  user @ fresh box
        │
        │  curl -fsSL …/install.sh | bash -s -- --with-codex
        │  (or iwr -OutFile $tmp …/install.ps1 ; & $tmp -WithCodex)
        ▼
  ┌──────────────────────────────┐
  │ install.sh / install.ps1     │  served from main on raw.githubusercontent.com
  │  1. HEAD /releases/latest    │  → 302 Location: …/releases/tag/vX.Y.Z
  │  2. parse Tag from Location  │  no JSON API, no jq, no rate-limit (see below)
  │  3. download tag .tar.gz/.zip│  github.com/<repo>/archive/refs/tags/<tag>
  │  4. extract → mktemp -d      │  per-invocation tempdir, not auto-cleaned
  │  5. exec setup.sh "$@"       │  (PowerShell: & $setup.ps1 @PSBoundParameters)
  └──────────────────────────────┘
        │
        ▼
  setup.sh / setup.ps1 — unchanged orchestrator runs the per-OS stage list
```

POSIX picks the first available downloader (`curl` preferred, `wget` fallback for stripped-down container images). Windows uses `Invoke-WebRequest -UseBasicParsing` for both the redirect HEAD and the archive download, then `Expand-Archive` to unpack. The redirect-Location parse on POSIX is a `grep -i '^location:' | sed -E 's|.*/releases/tag/||'` chain — no `jq`, mirroring the no-jq stance already established in `install-apt.sh`'s shfmt fallback. On Windows the equivalent is `try { Invoke-WebRequest -MaximumRedirection 0 } catch { $_.Exception.Response.Headers.Location }` — PowerShell raises on a 302 when redirects are disabled, and the response object is reachable from the exception.

## Trust model

Same posture as Homebrew's `install.sh`: the trust boundary is GitHub's TLS cert plus the repo owner's release-signing discipline. A user piping `install.sh` to `bash` is implicitly trusting (a) GitHub serves the file the repo owner pushed, (b) the repo owner only tags releases they're willing to stand behind. Read the script before piping if you don't trust either — both `install.sh` and `install.ps1` are short and self-contained for exactly that reason.

The bootstrap pulls a tagged release rather than `main` HEAD: tags go through the `/release` gate (changelog, version bump, manual smoke-tests), `main` does not. Someone who lands a bad commit on `main` does not blow up users mid-`curl | bash`.

Forks, mirrors, and cached copies of `install.sh` / `install.ps1` after the visibility flip are out of our control — that's why the pre-flip audit (task 1 of the feature plan) was exhaustive on `git log`, `.harness/`, and embedded paths.

## Trade-offs

- **No `--version vX.Y.Z` pin in v1 (deferred).** Latest-only is the simpler default and matches what 99% of users want from a one-liner. Adding a version flag is non-breaking when we need it.
- **No Homebrew tap / winget repo / apt repo in v1 (deferred).** Each adds a release surface to maintain (Bottle CI, manifest PRs, GPG-signed apt index). The curl|bash bootstrap covers the same zero-clone goal at zero ongoing cost.
- **Redirect-Location over the JSON Releases API.** The `/repos/<owner>/<repo>/releases/latest` API endpoint is rate-limited to 60 unauthenticated requests/hr per IP. CI runners on shared NATs hit that limit routinely (HTTP 403). The HTML redirect on `github.com/<owner>/<repo>/releases/latest` has no such limit and returns a stable `302 Location: …/releases/tag/vX.Y.Z`. Anthropic's `claude.ai/install.sh` uses the same pattern.
- **The `git clone` flow stays supported forever.** It's what existing users already wired into onboarding docs, and it's the only flow that exercises `main` HEAD. Removing it would break backwards compat for zero gain.
- **MIT over Apache-2.0.** Matches the converge reference and the "personal tool, no warranty" posture; a contributor patent grant is overhead this repo doesn't need.

## Related

- [Install via one-liner](../how-to/Install-Via-One-Liner) — the user-facing recipe.
- [Scripts reference](../reference/Scripts) — flags, exit codes, file layout.
- [Dev-machine setup — design](Dev-Machine-Setup-Design) — the orchestrator that the bootstrap hands off to.
- [.harness/PLAN.md](../../.harness/PLAN.md) — full task list, constraints, and verification strategy.
