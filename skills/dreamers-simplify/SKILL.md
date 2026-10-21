---
name: dreamers-simplify
description: "Standalone focused Vigil review (architectural quality). Read-only — reads Vigil's `.dreamers/reviews/` artifact for over-engineering, premature abstractions, redundancy, and bad architecture. May recommend full refactors. No auto-fix. Use when the user asks for dreamers-simplify, simplify this, audit for over-engineering, architectural review."
---

## Codex runtime
Read `../../dreamers/refs/codex-runtime.md` relative to this skill directory for resource resolution, progress tracking, user gates, and delegation. Use the user's message as skill input, including paths and flags.

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

---

## Argument parsing

Default scope (no flags): staged + unstaged changes.

- `--branch` — scope to feature-branch diff vs default:
  ```bash
  DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  [ -z "$DEFAULT" ] && DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
  ```
- `--paths <glob>` — scope to files matching the glob.
- `--all` — entire codebase. Vigil's simplicity lens (over-engineering, architectural quality) is well-suited to full-codebase audits; less of a warning here than for review / test.

---

## Spawn Vigil

Invoke `multi_agent_v1.spawn_agent` with the following context and wait for the result:

```
agent_type: "vigil"
message:
  Context: Standalone focused Vigil audit via dreamers-simplify. No plan binding (ad-hoc audit).
  Scope: <list of files from arg parsing above>
  Branch: <current feature branch>
  Default branch: <detected default>
  Focus: simplicity / over-engineering / redundancy / bad architecture. Recommend full refactors when warranted, while still reporting critical correctness/security/maintainability/test-coverage findings if they appear.
  Write: exactly one .dreamers/reviews/vigil-*.md artifact.
  Return: status + counts + artifact path + blocked reason + open questions only.
```

## Output

Read the artifact path returned by Vigil and pass the artifact contents through to the user verbatim. Do NOT apply any of the suggested fixes / refactors — this is a read-only audit. Surface any `Blocked` status or open questions for user follow-up.

If Vigil recommends a large refactor, suggest: "Run `dreamers-plan` to scope the refactor, then `dreamers` to execute it."
