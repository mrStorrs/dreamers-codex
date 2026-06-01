---
name: dreamers-cleanup-comments-branch
description: "Branch-scoped comment cleanup. Same as dreamers-cleanup-comments but scoped to the current feature-branch diff. Standalone pre-PR comment sweep. Use when the user asks for dreamers-cleanup-comments-branch, comment cleanup branch scope, pre-PR comment sweep."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

<comment-rules>
# Comment Rules

## Core principle
Comments must add value that the code cannot express itself. Concise, no fluff, no separators — value only.

## When to comment
- Non-obvious logic: why a non-obvious approach was chosen, constraints, gotchas
- Public API documentation callers need to use the interface correctly
- TODO/FIXME with specific, actionable notes
- License headers

## When NOT to comment
- Code that reads naturally from well-named functions and variables
- Anything that restates what the code obviously does (`const isRunning` does not need `// tracks whether running`)

## Strict prohibitions
- **No plan/ticket references** — never mention plan files, milestone names (D25, plan-3), ticket numbers, or agent names in source code
- **No separator comments** — never use `// ---`, `// ===`, `// ###`, blank-comment lines, or visual dividers
- **No spec rationalization** — never write comments arguing a spec permits a pattern; implement cleanly and let review judge
- **No redundant JSDoc/KDoc** that only repeats the function signature
- **No em dashes. no exceptions**

## Style
- One line when possible; never exceed two lines for inline comments
- Write *why*, never *what*
- If a comment requires more than two lines to be useful, the code needs refactoring, not more words
</comment-rules>

<dreamers-kernel>
# Dreamers Kernel

## User overrides

Explicit user instructions can skip or alter phases/actions.

## Subagent allowlist (HARD RULE)

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

After spawning a required Dreamers role, call `multi_agent_v1.wait_agent` when the result is needed before continuing.

## Implementation discipline

- **Plan adherence:** edit only files in the plan's scope. No while-I'm-here cleanup, no unrelated refactors mixed with feature work.
- **No spec-arguing comments:** never add a code comment that argues the spec permits a pattern.
- **Branch identity check:** before the first edit, `git log --oneline -3`. Confirm the branch and recent commits match the expected feature. If not, halt and surface.
- **No dependency installs without permission.** Don't run `npm install`, `pip install`, etc. without explicit user approval.
- **Type-check before declaring implementation done.** Run the project's type-check command from `AGENTS.md`, `CODEX.md`, or `.github/copilot-instructions.md` when present, and fix errors before moving on.

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
- [ ] Phase 1 — audit branch-diff scope for comment-rules violations
- [ ] Phase 2 — proposal + user approval
- [ ] Phase 3 — apply cleanup inline
- [ ] Phase 4 — optional Sentinel review (if requested)
- [ ] Phase 5 — commit

Mark each item `in_progress` when starting, `completed` when done. Never batch completions at the end.

---

## Scope detection

Detect default branch (canonical two-step):
```bash
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$DEFAULT" ] && DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
```

Fetch the remote before computing the diff (otherwise a stale local `origin/$DEFAULT` will produce a wrong or empty file list):
```bash
git fetch origin
```

If `git rev-parse origin/$DEFAULT` fails after the fetch, halt with: "Could not resolve `origin/$DEFAULT`. Check your remote configuration."

Scope = files in `git diff origin/$DEFAULT...HEAD --name-only`.

If the working tree is on the default branch (no feature-branch diff), halt with an error: "This skill operates on a feature branch's diff. Use `dreamers-cleanup-comments` for project-wide cleanup."

---

## Phases

Phases 1–5 are identical to `dreamers-cleanup-comments`, scoped to the branch-diff file list:

1. **Audit** the branch-diff scope; categorize comment-rules violations.
2. **Propose** changes; ask the user for approval.
3. **Apply** changes inline; stage with `git add`.
4. **Optional Sentinel review** of changed files.
5. **Commit** with message `chore: comment cleanup on feature branch`. Do NOT push.

## When this skill is the right tool

- Pre-PR polish — after a feature is done, before opening the PR, when you want the branch's comments inspected before they ship.
- Targeted clean-up scoped to the changes a single feature branch introduced, without auditing the entire project.

For project-wide cleanup (not branch-scoped), use `dreamers-cleanup-comments`.
