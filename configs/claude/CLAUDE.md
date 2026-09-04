# Global Claude Code Instructions

> [!NOTE]
> Symlinked into `~/.claude/CLAUDE.md` by `dev-setup/scripts/link-configs.sh`. Edits here apply globally — every Claude Code session, every project on this machine.

## Worktrees

Git worktrees are a first-class workflow, but **operator authority is required** — never spawn one without it. Authority = an explicit operator command **or** a durable `isolation.mode: worktree-per-plan` config opt-in in `.harness/project.json`; once authority exists, the spawn itself runs through whatever the installed host provides natively (Claude Code's `EnterWorktree`; Antigravity's New-Worktree-Mode / `invoke_subagent`) rather than a bespoke script. Silent authority-free auto-spawn stays forbidden (not as cleanup, not as a convenience for another task, not as a side effect). Absent operator authority, work directly on the current branch (typically `main`), and do not call `EnterWorktree` on your own initiative. The line is authority, not the worktree itself. (ADR 0028, 2026-06-14, refines ADR 0022.)

**Per-repo carve-out — `agentm` + `crickets` carry a durable opt-in (worktree-native flow, 2026-07-06).** Both repos ship a local, gitignored `.harness/project.json` with `isolation.mode: worktree-per-plan` — the durable authority this doctrine already names, now actually exercised. In those two repos, `/work` auto-spawns a worktree per plan and integrates via an auto-merged PR; every other repo on this machine (and every non-`/work` session in agentm/crickets) keeps the default above — no config, no authority, no auto-spawn. See the vault's `projects/agentm/_harness/designs/architecture-governance/worktree-native-verdict-draft.md` memo for the full adjudication; the landed decision lives in crickets' `development-lifecycle` / `developer-safety` / `conventions` designs.

## Commit messages

Do not append a `Co-Authored-By: Claude …` trailer to git commit messages. The user is the sole author of intent — Claude is the tool, not a co-author. Plain commit message only. Applies to every repo and every commit unless the user explicitly opts in for a specific commit.

## Push and confirmation

The stop-gate on a push is **recoverability, not destructiveness or blast-radius** — the same doctrine the developer-workflows execution commands (`/work`, `/bugfix`, `/release`) inline verbatim. A recoverable push proceeds (announced); only a genuinely unrecoverable one stops for confirmation. The `~/.claude/settings.json` allowlist encodes the mechanical floor: `git push`, `git push origin`, `git push -u:*`, `git push --set-upstream:*`, `git push origin HEAD:*` are auto-allowed; force / delete / branch-delete refspecs route through `ask`. Adding extra "is this OK?" ceremony in conversation on top of that gate is redundant.

**Recoverable → announce + proceed** (no confirmation wait, no conversational pre-confirm): standard `git push` / `-u` / `HEAD:`; create + push a tag; force-push to your **own un-shared** branch (you can force-push back); delete a branch whose tip is still reachable; in `agentm` + `crickets` only, a required-checks-green merge of a `/work`-opened plan PR (worktree-native flow, 2026-07-06 — see the Worktrees carve-out above) — named explicitly as a deliberate one-notch loosening of this doctrine's usual posture (a merge is less trivially undone than a push), not a reinterpretation of it.

**Unrecoverable → pre-announce + let the harness gate stop you** (state what's about to happen so the `ask` prompt isn't surprising; don't ask permission in conversation, but don't slip it past either):

- `git push --force` / `-f` / `--force-with-lease` that **rewrites published, shared** history
- sole-ref delete of unmerged work — `git push --delete <branch>`, `git push origin --delete <branch>`, or `git push origin :<branch>` (refspec-deletion form) — when the tip is no longer reachable
- `git push --tags` that would **overwrite a published tag**
- any immutable publish / deploy / migration reached through a push

When in doubt about a **routine** push, push — the operator can always reset or force-push back, and forcing them to micromanage routine pushes is the bigger cost. When uncertain whether a **destructive** push is recoverable, treat it as unrecoverable (the conservative default the doctrine names). Applies to every repo on this device.

## Refreshing a stale branch — rebase, never back-merge

**In a squash-merge repo, never merge `main` backwards into a branch. Rebase.** Applies to every repo on this device that squash-merges — today `agentm` and `crickets`, whose `main` protection sets `required_status_checks.strict = true` (a branch **must** be up to date before it can merge) and `required_linear_history` (merge commits are barred from `main` outright).

**Why it is not a style preference.** A squashed commit on `main` carries no ancestry link to the branch commits it was built from. Git therefore cannot tell that the squashed commit already contains work the branch has since reverted, and merging `main` backwards re-adds that work **with no conflict and no signal**. The revert is correct; git simply cannot see that the two touched the same change.

**The trap is the default.** `gh pr update-branch` merges the base branch into the PR branch unless told otherwise — its own help text says so. Because `strict` makes the refresh mandatory whenever `main` moves under an open PR, the dangerous command runs by policy rather than by mistake.

- **Refresh with** `gh pr update-branch --rebase <N>`, or `git fetch origin && git rebase origin/main`.
- **Force-pushing your own un-shared branch afterwards is recoverable** → announce + proceed, per the doctrine above.
- **Squash stays.** It gives one commit per plan on `main`, and merge commits are blocked by branch protection anyway.

Automated in crickets `development-lifecycle` v0.44.1 ([#230](https://github.com/alexherrero/crickets/pull/230)) — `shepherd_stalled_prs` now passes `--rebase`, with a regression test pinning the flag. **Installed plugin copies are separate from the repo**, so that fix is only live once the plugin is updated on this machine; until then the rule above is the operator's to hold by hand.

**A related consequence, unchanged by that fix:** commit-identity tests still lie about whether a branch has *landed* (`git merge-base --is-ancestor`, subject matching, `merge-tree`). When deciding whether a stale branch is safe to delete, file-level presence on `main` is the only reliable test.

## Merging from a worktree — arm auto-merge, never `--delete-branch`

**Never pass `--delete-branch` (`-d`) to `gh pr merge` from inside a worktree.** Applies to every repo on this device that uses worktrees — today `agentm` and `crickets`.

**What it does.** To delete the *local* branch, `gh` first has to leave it — so it runs `git checkout main && git pull --ff-only` **in the worktree you are standing in**, then deletes the branch you were on. The worktree now holds `refs/heads/main`; its feature branch is gone; the session that spawned it is on `main` without having chosen to be. Seen twice on 2026-09-04 alone, in two different sessions.

**The trap is the default.** `-d` is the obvious flag, and nothing in the flow needs it: both repos set `delete_branch_on_merge`, so GitHub deletes the remote branch itself the moment a PR merges. The only thing `-d` adds is the local `checkout main` — the harmful part.

- **Default: arm auto-merge at open time and walk away** — `gh pr merge --auto --squash <N>` right after `gh pr create`. GitHub merges on green, deletes the remote branch, touches nothing local. This is what `/work` already does, and it is what "auto-merge on green" in the chip-session doctrine below means.
- **A hand merge, when one is actually wanted now:** `gh pr merge --squash <N>`, no `-d`. The worktree and its local branch are cleaned up by worktree teardown, not by the merge.
- **If a worktree is already stranded on `main`:** `git -C <worktree> checkout --detach` frees the ref and loses nothing — the working tree stays put; the slot can then be removed normally.

Detected in crickets `development-lifecycle` v0.46.0 ([#235](https://github.com/alexherrero/crickets/pull/235)) — `doctor_worktrees.py` reports a linked worktree holding the integration branch as `stranded-on-main`, and `worktree_shepherd.py` detaches a clean one. **Installed plugin copies are separate from the repo**, so the detector is only live once the plugin is updated on this machine; until then the rule above is the operator's to hold by hand.

**Why the primary clone does not stop this.** `~/Antigravity/agentm` is deliberately kept detached at `origin/main` — release commits are made there detached and pushed `HEAD:main` — so local `main` is never held anywhere and is always free for a worktree to take. That is fine: a stolen ref never blocks the primary. It just means the guard has to be the rule above, not a failing checkout.

## Background-task chip sessions

A session spun off from a `spawn_task` chip (Claude Code Desktop's background-task feature) carries the same authority as an explicit operator command for the task it names — clicking the chip **is** the "yes, do this" the generic ask-before-every-commit default requires. In any harness-installed repo (signal: `.harness/PLAN.md` or `.harness/ROADMAP.md` present — today `agentm` + `crickets`), a chip-spawned session runs its task to completion under the same recoverable → proceed doctrine as `/work` / `/release` (see Push and confirmation, above): commit, push, open a PR, and — where the worktree-native carve-out already applies (agentm + crickets) — auto-merge on green required checks, then clean up the worktree/branch. Announce each step; don't wait for conversational confirmation on any of it.

Stop and ask only when the task itself hits something in the **Explicit permission required** / **Prohibited** action categories, or the push doctrine's unrecoverable bucket above — the same exceptions that gate `/work`, not a lower bar. When the run finishes, say so and stop; the operator archives the completed plan/PR on their own schedule — don't wait around for that or nudge for it.

Outside a harness-installed repo, a chip-spawned session has no plan/progress safety net to run against — keep the generic ask-before-commit default there.

## GitHub `claude` contributor chip

The user has accepted the residual `claude` entry in `mentionableUsers` / contributor sidebar on `alexherrero/agentm` and `alexherrero/sherwood` (the former from cache lag after a history rewrite, the latter anchored to immutable closed PR #23). Do not propose a GitHub Support ticket, PR deletion, or any further cleanup for this. If the topic comes up again, treat it as resolved unless the user explicitly reopens it.

## Token discipline

Token budget is a hard daily constraint — the standing goal is all-day-autonomous coding on a smaller Claude plan, so treat tokens as scarce in every session. Defaults:

- **`Edit`, not `Write`, for existing files.** Output is billed ~5× input, and `Write` re-emits the whole file as output tokens while `Edit` emits only the changed strings. Reserve `Write` for new files or a near-total rewrite.
- **Stay silent between tool calls.** Don't narrate each step — surface a line only when you find something load-bearing, change direction, or hit a blocker. (This trims inter-tool chatter only; it does *not* shrink the detailed end-of-task status report the dev-flow convention below asks for.)
- **`/clear`, not `/compact`, at phase boundaries.** State is on disk (`PLAN.md` / `progress.md`); a compaction summary is redundant work that also re-bills on every later turn. `/clear` after `progress.md` is written — never mid-task.
- **Stagger agents; don't multiply them.** Time-shift the per-repo sessions so their growing contexts don't co-exist in one 5-hour window, and `/clear` idle ones. Use subagents (prefer the cheap-floor `Explore`) to keep a session's own context small — but spinning up many parallel full sessions for throughput multiplies the per-agent floor (~15×).
- **Route the model to the work.** `opusplan` (Opus plans, Sonnet executes the long phase) for token-heavy build sessions; keep full Opus for planning and audit. Set it per session with `/model opusplan`, and flag it if you notice an expensive model doing cheap work.

## Development flow conventions

Apply by default in any project that uses a plan-driven workflow (signal: `.harness/PLAN.md` or `.harness/ROADMAP.md` present). The user will say so if a particular session wants a leaner style.

### Status reports

- **Lead with roadmap context** when `.harness/ROADMAP.md` exists: *"Currently building ROADMAP item #X — &lt;name&gt;. &lt;one-sentence framing&gt;."*
- **Include a plan-status chart** with ✅/⬜ symbols per task — greppable + scannable.
- **Include a link block** to local state files when relevant: absolute paths to `ROADMAP.md` / `PLAN.md` / `progress.md`. Note `.harness/` is gitignored.
- **End with an explicit handoff phrase**: *"Say 'let's do task N' to continue"* (or *"Ending loop"* if no follow-on action).
- After a task lands, also include: commit SHA, CI status with per-OS times, files changed count, key design calls or scope adjustments, manual verification scenarios when relevant, and negative-test results when relevant.

### `.harness/PLAN.md` shape

- **Locked design calls section** at the bottom of every plan — capture the resolutions to open design questions so they don't drift mid-plan.
- **Task `Status: [x]` annotations** include a paragraph-long narrative of what shipped, not just the checkmark. The next session's context is whatever this captures.
- **When a plan completes** (last task `[x]`), run the close-out in order as the final steps of the plan: flip plan-level `Status: done`, append end-of-plan summary to `progress.md`, move the corresponding ROADMAP item to Completed with a full narrative (release links + scope + what shipped + what's deferred), and **archive the active `PLAN.md` to `PLAN.archive.YYYYMMDD-<slug>.md` right then — as the final close-out step, not when the next plan starts.** (This matches the agentm harness's own `05-release.md`, which archives the completed plan at release time.)

### CHANGELOG + ADR shapes

- **CHANGELOG entries** (Keep-a-Changelog style): lead paragraph framing the release; Added / Changed / Internal sections; cross-references to paired releases when applicable (URL-link the sibling repo's release page).
- **ADRs**: `> [!NOTE]` block with `Status: accepted|superseded|rejected` + `Date`; sections Context (with open questions the decision resolves) / Decision (with rationale + "why not the alternative" per call) / Consequences (positive bullets / negative bullets / load-bearing assumptions with explicit re-audit triggers) / Related.
  - **Per-repo carve-out — ADR model retired in `agentm` + `crickets` (AG track, 2026-06-21), then `sherwood` + `dev-setup` (both 2026-06-30).** In those repos a new decision no longer adds an ADR: it amends the relevant **living design** (`wiki/designs/`) — body reconciled to current truth + a terse amendment-log entry at the bottom (date · what changed · why-not-the-alternative · re-audit trigger), the amendment and the body-update landing as **one atomic change**. The ADR *shape* above still governs **every other repo** until it migrates — this is a scoped opt-out, not a machine-wide flip. Rationale: the dominant drift is the chain-read (a superseding decision left pointing back through the superseded record); a living body collapses the chain, an immutable ADR + pointer re-creates it. See agentm `wiki/reference/Design-Governance.md` + the AG design-doc §5. Existing `agentm` / `crickets` ADRs fold into living designs script-driven (`migrate-adr.py`), per arc; `sherwood` and `dev-setup` had no standalone ADRs to fold — `sherwood` redirected the *planned* ADRs in its v2 system design into that design's amendment log, and `dev-setup` retired an ADR-*convention* stub (it kept no decision records) when it adopted the six-section model.

### Coordinated cross-repo releases

When a plan ships paired releases across sibling repos:

- **Lock the order** explicitly in the plan (which repo's release notes URL-link the other → that one ships second).
- Each release's GitHub release notes cross-link the sibling release.
- CI must be green on both release commits before plan-close.

### Wake-on-CI pattern

Don't mark tasks `[x]` speculatively. Push (or open/update a PR, whichever actually triggers the project's CI) → schedule a ~90s wake → close out with `[x]` + `progress.md` append only when the relevant check-suite confirms green across the OS matrix. In agentm + crickets specifically (per-plan CI, 2026-07-06), the full matrix triggers on `pull_request`, not on push to `main` — wake on the PR's check-suite there, not a bare push's.

### Documentation soft-warnings

When `check-wiki.py --strict` reports a soft length warning ("how-to page is N words, soft ceiling 600; consider splitting") and the content is genuinely load-bearing (worked scenarios, troubleshooting), it's acceptable to keep the page intact. Explicitly note the trade-off in the commit message / CHANGELOG.

## Harness + toolkit conventions (loaded per-project, not globally)

The `agentm` and `crickets` conventions are imported by each repo's own `CLAUDE.md`, not here: `@AGENTS.md` in `~/Antigravity/agentm/CLAUDE.md`, and `@AGENTS.md` + `@~/Antigravity/agentm/AGENTS.md` in `~/Antigravity/crickets/CLAUDE.md` (crickets runs on the agentm phase harness, so it loads both). This is the token-efficiency floor-trim (2026-06-13): a project that isn't agentm/crickets no longer re-reads either `AGENTS.md` on every tool call × every agent, and an agentm session no longer carries the crickets-only conventions. Do not re-add the global imports — that re-inflates the per-call floor for every project on the machine.
