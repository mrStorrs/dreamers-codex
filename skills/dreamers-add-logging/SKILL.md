---
name: dreamers-add-logging
description: "Phased pass to add or improve project logging per logging-standards.md. Audit current state → propose changes → user approval → implement inline → optional Sentinel review. Use when the user asks for dreamers-add-logging, add logging, improve logging, audit log calls."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Also load at runtime (not inlined — these are templates / project files):
- `dreamers/templates/logging-standards.md` — the binding spec
- `AGENTS.md, CODEX.md, or .github/copilot-instructions.md when present` (project, if present) — project-specific logging conventions (logger library, format)

<dreamers-kernel>
# Dreamers Kernel

## Subagent allowlist (HARD RULE)

Do not use any non-Dreamers agent unless explicitly authorized by user.

## Subagent prompt — required content

Every `multi_agent_v1.spawn_agent` invocation MUST include in the prompt:
- **Context** — what this agent is being asked to do and why
- **Prior work** — what was done previously, with absolute paths to any output files
- **What is needed** — specific deliverable
- **Constraints** — hard rules the agent must not violate
- **Definition of Done** — how to know the work is complete
- **Plan file path** — absolute path to the relevant plan file (if applicable)
- **Mandatory line:** `Do NOT call update_plan. The parent Dreamers skill owns the plan.`

After spawning a required Dreamers role, call `multi_agent_v1.wait_agent` when that result is needed before continuing.

## Continuation principle

At every natural pause between phases — where the skill has produced a meaningful result and the user could redirect — ask the user with three choices: `Continue` / `Halt for now` / `Other` (freeform). Never silently advance; never silently stop. On `Halt`, emit a one-line resume command and stop.

## Implementation discipline

- **Plan adherence:** edit only files in the plan's scope. No while-I'm-here cleanup, no unrelated refactors mixed with feature work.
- **No spec-arguing comments:** never add a code comment that argues the spec permits a pattern.
- **Branch identity check:** before the first edit, `git log --oneline -3`. Confirm the branch and recent commits match the expected feature. If not, halt and surface.
- **No dependency installs without permission.** Don't run `npm install`, `pip install`, etc. without explicit user approval.
- **Type-check before declaring implementation done.** Run the project's type-check command from `AGENTS.md, CODEX.md, or .github/copilot-instructions.md when present` and fix errors before moving on.

## Commit trailer

Every commit body includes:

```
Co-authored-by: The Dreamers System
```
</dreamers-kernel>

Skill input: use the user's message, including any paths or flags.

---

## Todo list

At skill entry, declare via `update_plan`:
- [ ] Phase 1 — audit current logging state
- [ ] Phase 2 — proposal + user approval
- [ ] Phase 3 — implement approved changes
- [ ] Phase 4 — optional Sentinel review
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

## Phase 4 — Optional Sentinel review

Ask the user with `["Yes — review before commit", "No — skip review", "Other"]`.

- Yes → spawn a sub-agent with `dreamers/agents/sentinel.md` and the changed-files scope. Sentinel reviews under correctness/security/maintainability lenses; comment-rules + logging-standards violations surface here. Apply findings inline.
- No → proceed to commit.

## Phase 5 — Commit

`git status` to confirm staged content. Commit message: `chore: improve logging per logging-standards.md` (or appropriate). Do NOT push (user pushes when ready, or invokes `dreamers-pr` to push + open the PR).

