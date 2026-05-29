---
name: dreamers-issue
description: "Create a structured GitHub issue with acceptance criteria from a task description. Use when the user asks for dreamers-issue, create an issue, open a GitHub issue, file an issue."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Create a GitHub issue for the following request:

Skill input: use the user's message, including any paths or flags.

---

**Routing — check for `#` prefix**

If the arguments start with `#`, enter **discussion mode**:
- Strip the `#` and treat the rest as the topic.
- Ask focused questions to clarify scope, intent, and acceptance criteria.
- Continue the conversation until you have enough to write concrete, testable ACs.
- Then proceed to Step 1 below. ACs produced this way are **real** — no "potential" qualifier.

If the arguments do NOT start with `#`, enter **direct mode**:
- Do NOT ask questions.
- Proceed immediately to Step 1. ACs produced this way are **potential** — prefix each with `[potential]`.

---

**Step 1 — Repo detection**
Run `gh repo view --json nameWithOwner` to confirm the current repo. If not in a git repo or no remote is set, ask the user asking the user which repo to target (`OWNER/REPO` format) before proceeding.

**Step 2 — Label check**
Run `gh label list` to see available labels. Pick the most appropriate existing label(s) — do not invent labels. Common mappings:
- New capability → `feature`
- Something broken → `bug`
- Docs gap → `documentation`
- Unclear ownership → `question`

**Step 3 — Minimal exploration (optional)**
Light exploration is allowed — e.g. confirm a feature exists, glance at a config, check a directory structure. Keep it to 1-3 lookups max. Deep codebase analysis belongs in `dreamers-plan`, not here.

**Step 4 — Draft the issue**
Write a focused, minimal issue from the user's input (and any brief exploration from Step 3).

Use the template at `dreamers/templates/github-issue.md` as the structure. Keep the body concise — no padding, no restatement of the title.

ACs must be written from a **product owner perspective** — user-facing outcomes, not technical implementation. "User can filter by date" not "Add dateFilter param to query handler".

**Step 5 — Create**
Run `gh issue create` with the drafted title, body, and label(s). Report the issue URL when done.

