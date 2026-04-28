# Dev-machine setup — design

> [!NOTE]
> **Status:** implemented — Mac stable at v0.1.0; Debian feature-complete at v0.6.0 (full pass pending verification on a real Debian VM).
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — features `feat-mac-one-shot-setup`, `feat-debian-cli-support`.

## Intent

Reproduce a minimal, opinionated AI-first dev environment on any new machine with a single command, keeping configuration as literal files in git so the setup is auditable, portable, and diffable over time. The project ships a *machine-shaped artifact*, not a config-management framework — `./setup.sh` and the files in `configs/` are the contract.

## Shape

The orchestrator dispatches on OS, then runs an ordered list of per-concern stages. There is no plugin system and no DAG — just a flat list per platform.

```
setup.sh
   │
   ├── scripts/lib/os.sh   →  detect_os()  →  macos | debian   (exit 2 otherwise)
   │
   ├── macOS plan:    xcode → brew → clis → gui-apps → link-configs → verify-install → auth-checklist
   ├── Debian plan:   apt        → clis →            link-configs → verify-install → auth-checklist
   └── Windows:       deferred — see docs/windows.md
```

| Component | Mac | Debian | Notes |
|---|---|---|---|
| Package manager bootstrap | `install-brew.sh` | `install-apt.sh` | Debian adds NodeSource (node 22 LTS) and GitHub CLI apt repos with explicit keyrings. |
| CLI installer | `install-clis.sh` | same script, OS-dispatched internally | Picks rc file via `rc_file()` (Mac and Debian-with-zsh → `~/.zshrc`; Debian-with-bash → `~/.bashrc`). Sets `~/.npm-global` prefix on Debian. Hard-fails on node < 20 there. |
| GUI apps | `install-gui-apps.sh` | _(skipped)_ | Antigravity / Claude Desktop / Gemini Desktop are macOS-only binaries. |
| Config linking | `link-configs.sh` | same | Skips Mac-only Claude Desktop config path on Debian. |
| Verifier | `verify-install.sh` | same | Mac baseline 30 ok / 0 warn; on Debian, GUI + Mac-only-JSON checks emit a single consolidated SKIP. |
| Codex CLI | opt-in via `--with-codex` | opt-in via `--with-codex` | Off by default on both platforms. Flag exports `WITH_CODEX=1` to subprocesses. |

## Trade-offs

- **No GUI on Linux.** Antigravity Desktop is a GUI-first product per Google's own docs (<https://antigravity.google/docs/command>) and ships as macOS / Windows binaries only. The Debian plan is CLI-only by design, not by oversight. Adding a Linux GUI stage would be unfounded surface area.
- **Single shared scripts, OS-dispatched at the top.** The alternative — parallel `scripts-mac/` and `scripts-debian/` trees — was rejected. Keeping `install-clis.sh`, `link-configs.sh`, `verify-install.sh`, and `auth-checklist.sh` shared keeps cross-platform drift visible at review time. The cost is a handful of `case "$OS"` blocks.
- **`rc_file()` over hard-coding `~/.zshrc`.** Mac always has zsh; Debian users may run bash. A single helper keeps the rc-target consistent across linker, verifier, and checklist — flipping it in one place flips it everywhere.
- **Codex opt-in.** Codex is the only CLI a user might actively *not* want (paid OpenAI account, separate auth). Default-off keeps the baseline run frictionless.

## Related

- [Bootstrap a new Mac](../how-to/Bootstrap-A-New-Mac) — Mac recipe.
- [Bootstrap a new Debian or Ubuntu host](../how-to/Bootstrap-A-New-Debian-Or-Ubuntu) — Linux recipe.
- [`docs/debian.md`](https://github.com/alexherrero/dev-machine-setup/blob/main/docs/debian.md) — in-repo Debian reference (supported-distro matrix, toolchain detail, future work).
