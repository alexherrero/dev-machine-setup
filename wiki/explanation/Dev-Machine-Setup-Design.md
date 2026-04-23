# Dev-machine setup — design

> [!NOTE]
> **Status:** pending
> **Plan:** [.harness/PLAN.md](../../.harness/PLAN.md) — feature `feat-mac-one-shot-setup`

_Filled by /work once the task ships. Placeholder reserves the page shape per harness/agents/documenter.md §/plan._

## Intent

Why this project exists: reproduce a minimal, opinionated AI-first dev environment on any new Mac (and eventually Windows) with a single command, keeping configuration as literal files in git so the setup is auditable, portable, and diffable over time.

## Shape

High-level architecture of the setup system:
- `configs/` — literal captured application configs, committed to the repo.
- `scripts/` — per-concern install stages (brew, Claude CLI, GUI apps, config-linking, auth checklist).
- `setup.sh` / `setup.ps1` — top-level orchestrator, runs stages in order.
- `docs/` — first-run guide and Windows deferral note.

## Trade-offs

_Populated as real decisions land — symlink vs copy for configs, installer-URL stability, Gatekeeper handling._

## Related

- [Bootstrap a new Mac](../how-to/Bootstrap-A-New-Mac) — the user-facing recipe.
