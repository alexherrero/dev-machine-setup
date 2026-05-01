# Dev-machine setup — design

> [!NOTE]
> **Status:** implemented — Mac, Debian/Ubuntu, and Windows all CI-verified end-to-end at v2.0.0.
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — features `feat-mac-one-shot-setup`, `feat-debian-cli-support`, `feat-ci-verification`, `feat-windows-cli-support`.

## Intent

Reproduce a minimal, opinionated AI-first dev environment on any new machine with a single command, keeping configuration as literal files in git so the setup is auditable, portable, and diffable over time. The project ships a *machine-shaped artifact*, not a config-management framework — `./setup.sh` and the files in `configs/` are the contract.

## Shape

Two layers: a thin **bootstrap** that resolves the latest release and hands off to the **orchestrator**, which dispatches on OS and runs an ordered list of per-concern stages. There is no plugin system and no DAG — just a flat list per platform.

```
install.sh / install.ps1   (curl|bash or irm|iex — fetches latest release tarball, exec's setup)
   │
setup.sh / setup.ps1
   │
   ├── scripts/lib/os.sh   →  detect_os()  →  macos | debian   (POSIX only; setup.ps1 is implicitly Windows)
   │
   ├── macOS plan:    brew    → clis → gui-apps → link-configs → verify-install → auth-checklist
   ├── Debian plan:   apt     → clis →            link-configs → verify-install → auth-checklist
   └── Windows plan:  tooling → clis → gui-apps → link-configs → verify-install → auth-checklist
```

| Component | macOS | Debian / Ubuntu | Windows | Notes |
|---|---|---|---|---|
| Bootstrap (no-`git` install) | `install.sh` | `install.sh` | `install.ps1` | Resolves latest release tag from the `/releases/latest` redirect Location header (no JSON API rate-limit), downloads source archive, exec's setup. |
| Package manager bootstrap | `install-brew.sh` | `install-apt.sh` | `install-tooling.ps1` | Debian adds NodeSource (node 22 LTS) and GitHub CLI apt repos with explicit keyrings. Windows uses winget (Git, Node LTS, gh, ripgrep). |
| CLI installer | `install-clis.sh` | same script, OS-dispatched | `install-clis.ps1` | POSIX picks rc file via `rc_file()` (zsh → `~/.zshrc`, else `~/.bashrc`); sets `~/.npm-global` prefix on Debian; hard-fails on node < 20. Windows uses `Anthropic.ClaudeCode` via winget for Claude, npm for Gemini. |
| GUI apps | `install-gui-apps.sh` | _(skipped — GUI-first products with no Linux build)_ | `install-gui-apps.ps1` | Mac uses browser-assisted DMGs. Windows uses winget for Antigravity Desktop + Claude Desktop. Gemini Desktop has no first-party Windows app. |
| Config linking | `link-configs.sh` | same | `link-configs.ps1` | Skips Mac-only Claude Desktop config path on Debian. Windows uses symlink-with-copy-fallback for `CLAUDE.md` (handles the no-Dev-Mode case). |
| Verifier | `verify-install.sh` | same | `verify-install.ps1` | Mac baseline 30 ok / 0 warn; Debian consolidates GUI + Mac-only-JSON checks to a single SKIP; Windows uses registry-uninstall-key search for installed app detection. |
| Codex CLI | opt-in via `--with-codex` | opt-in via `--with-codex` | skip-with-warn even with `-WithCodex` | The `@openai/codex` npm package is currently broken on Windows (cites `openai/codex#18648`). Off by default everywhere. |

## Trade-offs

- **No GUI on Linux.** Antigravity Desktop is a GUI-first product per Google's own docs (<https://antigravity.google/docs/command>) and ships as macOS / Windows binaries only. The Debian plan is CLI-only by design, not by oversight. Adding a Linux GUI stage would be unfounded surface area.
- **Single shared POSIX scripts, OS-dispatched at the top.** The alternative — parallel `scripts-mac/` and `scripts-debian/` trees — was rejected. Keeping `install-clis.sh`, `link-configs.sh`, `verify-install.sh`, and `auth-checklist.sh` shared keeps cross-platform drift visible at review time. The cost is a handful of `case "$OS"` blocks. Windows is a separate `*.ps1` file per stage because the language and tooling differ enough that one shared file would be unmaintainable.
- **`rc_file()` over hard-coding `~/.zshrc`.** Mac always has zsh; Debian users may run bash. A single helper keeps the rc-target consistent across linker, verifier, and checklist — flipping it in one place flips it everywhere. Windows has no rc-file equivalent; persistent PATH writes go through `[Environment]::SetEnvironmentVariable(... 'User')`.
- **Codex opt-in.** Codex is the only CLI a user might actively *not* want (paid OpenAI account, separate auth). Default-off keeps the baseline run frictionless. On Windows it's also currently skip-with-warn even when opted in, because the upstream npm package is broken.
- **Bootstrap pulls a tagged release, not `main`.** `install.sh` / `install.ps1` themselves live at `main` (so the canonical raw URL never breaks), but they download the source archive for the latest *release tag*. Releases are reviewed and tested; `main` HEAD is not. See [Public curl|bash installer — design](Public-Curl-Bash-Installer) for the full rationale.

## Related

- [Install via the one-liner](../how-to/Install-Via-One-Liner) — the curl|bash / irm|iex bootstrap recipe.
- [Public curl|bash installer — design](Public-Curl-Bash-Installer) — bootstrap layer's intent, trust model, trade-offs.
- [Bootstrap a new Mac](../how-to/Bootstrap-A-New-Mac) — Mac recipe via `git clone`.
- [Bootstrap a new Debian or Ubuntu host](../how-to/Bootstrap-A-New-Debian-Or-Ubuntu) — Linux recipe via `git clone`.
- [Scripts reference](../reference/Scripts) — flags, exit codes, files written.
- [`docs/architecture.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/architecture.md) — in-repo architecture overview (full repo layout tree).
- [`docs/debian.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/debian.md) — Debian reference (supported-distro matrix, toolchain detail).
- [`docs/windows.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/windows.md) — Windows reference (winget, MSIX redirect, Codex caveat).
