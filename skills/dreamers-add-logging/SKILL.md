---
name: dreamers-add-logging
description: "Phased pass to add or improve project logging per logging-standards.md. Audit current state → propose changes → user approval → implement inline → optional Vigil review. Use when the user asks for dreamers-add-logging, add logging, improve logging, audit log calls."
---

## Codex runtime
Read `../../dreamers/refs/codex-runtime.md` relative to this skill directory for resource resolution, progress tracking, user gates, and delegation. Use the user's message as skill input, including paths and flags.

Also load at runtime (not inlined — these are templates / project files):
- `dreamers/templates/logging-standards.md` — the binding spec
- `AGENTS.md`, `CODEX.md`, or `.github/copilot-instructions.md` when present (project, if present) — project-specific logging conventions (logger library, format)

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

## Todo list

At skill entry, declare via `update_plan`:
- [ ] Phase 1 — audit current logging state
- [ ] Phase 2 — proposal + user approval
- [ ] Phase 3 — implement approved changes
- [ ] Phase 4 — optional Vigil review
- [ ] Phase 5 — commit

Mark each item `in_progress` when starting, `completed` when done. Never batch completions at the end.

---

## Phase 1 — Audit

Scope: project source root by default; `--scope <path>` to restrict.

Walk the scope and identify:
- Functions with no logging where DEBUG entry/exit would help.
- Branches without log statements that affect business outcomes.
- ERROR-level logs missing stack traces.
- INFO logs that include secrets, PII, or full request bodies (NEVER-LOG violations — high priority).
- DEBUG logs in high-frequency loops without `// high-freq` annotation.
- Log calls using the wrong level (e.g., ERROR for recoverable issues; INFO for incoming requests with full bodies).

Produce an audit summary in chat: file path → issues found.

## Phase 2 — Proposal + user approval

Present the proposed changes in chat:
- List of files to modify, with one-line summary per file.
- Net adds vs net changes (e.g., "12 new DEBUG calls, 3 ERROR-level fixes, 2 NEVER-LOG violations to remove").
- Any logger-library / format conventions detected from existing code (so additions are consistent).

Ask the user with `["Approved — apply changes", "Halt for now", "Other"]`. Freeform corrections go through Other.

- Approved → proceed to Phase 3.
- Halt for now → output "Audit complete. No changes applied. Resume by re-invoking `dreamers-add-logging`." and stop.
- Corrections → revise proposal; re-present. Loop until approved.

## Phase 3 — Implement

Apply the approved changes inline. Stage with `git add` as you go. Follow `dreamers-kernel.md` implementation discipline — only edit files in scope; no while-I'm-here cleanup.

Run the project's type-check command after edits. Fix any type errors.

## Phase 4 — Optional Vigil review

Ask the user with `["Yes — review before commit", "No — skip review", "Other"]`.

- Yes → invoke `agent_type: "vigil"` with the changed-files scope. Prompt Vigil to focus on logging-standards plus correctness/security/maintainability risks, while still reporting coverage or simplicity findings if they appear. Apply findings inline.
- Require Vigil to write one `.dreamers/reviews/vigil-*.md` artifact and return only status, counts, artifact path, blocked reason, and open questions. Read the artifact before applying findings.
- No → proceed to commit.

## Phase 5 — Commit

`git status` to confirm staged content. Commit message: `chore: improve logging per logging-standards.md` (or appropriate). Do NOT push (user pushes when ready, or invokes `dreamers-pr` to push + open the PR).
