---
name: dreamers-docs
description: "Docs skill — spawns Echo to update Echo-owned sections of AGENTS.md, CODEX.md, or .github/copilot-instructions.md when present plus other project docs (README, CHANGELOG) affected by recent changes. Echo stages edits; does not commit. Use when the user asks for dreamers-docs, update docs, echo docs update."
---

## Codex runtime
Read `../../dreamers/refs/codex-runtime.md` relative to this skill directory for resource resolution, progress tracking, user gates, and delegation. Use the user's message as skill input, including paths and flags.

## Todo - Before you begin.
- When standalone, a todo is optional. When invoked by an outer delivery skill, complete these steps under its existing todo.

## Step 1 — Resolve diff scope
- `--branch` (default): scope = `git diff --name-only origin/$DEFAULT...HEAD`.
- `--staged`: scope = union of `git diff --cached --name-only` and `git diff --name-only`.
- If the changed-files list is empty → output `No changes detected` and exit.

## Step 2 — Spawn Echo
- `multi_agent_v1.spawn_agent` with `agent_type: echo`. Prompt MUST include `Do NOT call update_plan.`
- Pass: context (ad-hoc or milestone close-out — caller-supplied), changed-files list, diff base, plan paths (if applicable), prior review summary (if applicable).
- Constraint to Echo: edits docs only — no production code, no tests. Stage with `git add`; do NOT commit.
- Wait for Echo to return its structured chat output.

## Step 3 — Handle output
- `Docs updated — N files changed` → surface doc-changes log to user.
- `No doc updates needed` → exit.
- Open questions → present each by asking the user; capture answers; re-spawn Echo with clarification if needed.

## Exit
- Files Echo touched. The caller commits (this skill does NOT commit, push, or open a PR).

## Dreamers Kernel
<dreamers-kernel>
## User overrides

Explicit user instructions can skip or alter phases/actions.

## Subagent allowlist

Do not use any non-Dreamers agent unless explicitly authorized by user.

## Subagent prompt — required content

Every delegated Dreamers role invocation with `multi_agent_v1.spawn_agent` MUST include in the prompt:
- **Context** — what this agent is being asked to do and why
- **Prior work** — what was done previously, with absolute paths to any output files
- **What is needed** — specific deliverable
- **Constraints** — hard rules the agent must not violate
- **Definition of Done** — how to know the work is complete
- **Plan file path** — absolute path to the relevant plan file (if applicable)
- **Mandatory line:** `Do NOT call update_plan. The parent Dreamers skill owns the plan.`

After spawning a required Dreamers role, wait for its result before continuing. Launch all selected reviewers before waiting in a parallel review lane.

## Implementation discipline

- **Scope adherence:** edit only files in the task or plan's scope. No while-I'm-here cleanup, no unrelated refactors mixed with feature work.
- **Branch identity check:** before the first edit, `git log --oneline -3`. Confirm the branch and recent commits match the expected feature. If not, halt and surface.
- **No dependency installs without permission.** Don't run `npm install`, `pip install`, etc. without explicit user approval.

## Commit trailer

Every commit body includes:

```
Co-authored-by: The Dreamers System
```
</dreamers-kernel>
