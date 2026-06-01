---
name: dreamers-clean-work
description: "Between-milestone maintenance pass: prune stale files, audit improvements.md, scan for project-state drift. All inline — no subagents. Use when the user asks for dreamers-clean-work, clean up, maintenance pass, between milestones."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Run a between-milestone maintenance pass. No implementation, no planning, no subagents — do all of this directly.

Follow the Dreamers Kernel and output discipline from `Codex global instructions, if configured`.

Skill input: use the user's message, including any paths or flags.

---

## User overrides

- Explicit user instructions can skip or alter phases/actions.

## Todo list

At skill entry, declare via `update_plan`:
- [ ] Step 1 — improvements audit
- [ ] Step 2 — legacy workspace cleanup (recommend only)
- [ ] Step 3 — project state contradiction scan
- [ ] Step 4 — report

Mark each item `in_progress` when starting, `completed` when done. Never batch completions at the end.

---

## Step 1 — Improvements audit

Read `.dreamers/improvements.md` (repo-local). For each open item:
- Decide: action now, defer with a reason, or close as no longer relevant.
- If actionable as a direct text edit to an agent file or ref (meta work): make the edit now.
- If it requires a full pipeline (`dreamers-full`): defer it — add a note with why and which skill to use.
- Remove actioned/closed items. Leave only open deferred items with defer reasons.

## Step 2 — Legacy workspace cleanup (one-time)

The legacy multi-agent pipeline wrote per-cycle workspace artifacts under `.dreamers/{forge,probe,hone,sentinel,echo}/`. The current pipeline writes none of those — Sentinel, Probe, Hone, and Echo do not maintain workspace files.

If any of those directories exist, the user is welcome to delete them:

```bash
# Unix / macOS
rm -rf .dreamers/{forge,probe,hone,sentinel,echo}
```

```powershell
# Windows PowerShell
Remove-Item -Recurse -Force .dreamers\forge, .dreamers\probe, .dreamers\hone, .dreamers\sentinel, .dreamers\echo
```

Do NOT auto-delete — surface as a recommendation. The user may want to keep historical workspace files for reference.

## Step 3 — Project state contradiction scan

Read these durable surfaces and check for drift / contradictions:
- `.dreamers/improvements.md` — open items still relevant?
- `.dreamers/retros/` — anything stale or contradicted by recent work?
- Project-level `AGENTS.md, CODEX.md, or .github/copilot-instructions.md when present` Echo-owned sections (Tech stack, Repo structure, Conventions, Key files) — match the actual codebase?
- Recent `git log` on the default branch — major shifts (tech stack, architecture, tooling) reflected in instruction files?

**Propose** all changes to the user — do not auto-apply. Present a numbered list of proposed updates, then ask the user (multi-select) with one option per proposed change plus `"Apply none"` and `"Other"` for freeform direction. Apply only the items the user selects. Exception: clearly stale entries pointing to nonexistent files can be removed without asking.

## Step 4 — Report

Summarise in chat:
- Improvements actioned / deferred / closed (one line each)
- Legacy workspace recommendations (if any)
- Proposed memory updates (if any)
