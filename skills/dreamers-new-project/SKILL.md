---
name: dreamers-new-project
description: "Bootstrap a brand new project from scratch: discovery questions, optional existing-solutions research, project brief, shell plans. Use when the user asks for dreamers-new-project, new project, bootstrap a project, start a new project."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Bootstrap a brand new project from scratch. Work through the phases in order. Do not skip ahead or write anything permanent until the user explicitly approves the brief.

Follow the Dreamers Kernel and output discipline from `Codex global instructions, if configured`.

## User overrides

- Explicit user instructions can skip or alter phases/actions.

<project-bootstrap>
# Project Bootstrap

## Bootstrap checklist for new repos
1. Ensure `.dreamers/` is in the project's `.gitignore`
2. Create the project-level `AGENTS.md`, `CODEX.md`, or `.github/copilot-instructions.md` (see ownership below)
3. Create `.dreamers/plans/` directory
4. Install optional compatibility instruction files only when the project uses `.github/instructions/`:
   - Copy `comment-rules.instructions.md` from the Dreamers Codex package's `dreamers/instructions/` directory into `.github/instructions/` at the project root. Codex projects should put binding project rules in `AGENTS.md` or `CODEX.md`; `.github/instructions/` remains a compatibility surface for projects that also use Copilot-style instruction loading.
5. **Optional but recommended. (Ask user if they want this created or not):** create `.github/instructions/build.instructions.md` if the project has a defined build/distribution flow for test builds. The file is the authoritative playbook the orchestrator follows during user-testing pauses. It should specify:
   - Which commands (if any) the orchestrator is authorised to run itself
   - Which steps must be performed by the user (install on device, launch app, version/build number to verify, etc.)
   - Where the build artifact lives (link, path, store listing) and how to fetch it
   - How to recover from a failed build/distribution
   If this file is absent, the orchestrator will pause user-testing rounds and ask the user to build/distribute manually.

## Project Instructions Ownership (Split)

The project-level `AGENTS.md`, `CODEX.md`, or `.github/copilot-instructions.md` is the shared briefing all agents read on startup.

**Skill/orchestrator owns (initial creation + ongoing):**
- **Constraints** — anything agents must never do (e.g., no direct DB writes, no breaking public API)
- **Distribution** — short pointer to `.github/instructions/build.instructions.md` if it exists (the authoritative playbook), or a brief note that the orchestrator should ask the user to build/distribute when no playbook is present
- **Links** — plan directory, global workspace, related repos

**Echo owns (updated after each cycle):**
- **Tech stack** — languages, frameworks, major dependencies
- **Repo structure** — key directories and what lives where
- **Conventions** — naming, formatting, branching, commit style, test commands
- **Key files** — entry points, config files, CI/CD definitions

Do not touch Echo-owned sections during orchestration — those updates come from Echo after each cycle.
</project-bootstrap>


Skill input: use the user's message, including any paths or flags.

---

## Todo list

At skill entry, declare via `update_plan`:
- [ ] Phase 1 — discovery questions
- [ ] Phase 1.5 — optional existing-solutions research
- [ ] Phase 2 — tech stack recommendation + iteration
- [ ] Phase 3 — project brief + approval
- [ ] Phase 4 — repo & workspace bootstrap
- [ ] Phase 5 — shell plans
- [ ] Phase 6 — review loop

Mark each item `in_progress` when starting, `completed` when done. Never batch completions at the end.

---

## Phase 1 — Discovery

Read `dreamers/templates/discovery-questions.md` and use those questions to grill the user. Conversation only — write nothing to disk yet. Follow the grilling rules in that file. Do not proceed to Phase 2 until every question has a concrete answer.

---

## Phase 1.5 — Existing-solutions research (optional)

Before using web search or fetching any source, ask the user with `["Research similar existing solutions", "Skip research", "Other"]`.

- `Research similar existing solutions` → run a focused landscape scan inline. Search for current products, open-source projects, and relevant technical or academic work that substantially overlap the proposed project. Prefer primary and official sources. Present a concise cited comparison covering each solution's overlap, meaningful differences, maturity, and remaining gaps or opportunities. No results is not proof that no similar solution exists.
- `Skip research` → continue to Phase 2 without research.
- `Other` → capture the requested scope or constraints, re-present the gate, and wait for explicit approval before researching.

Do not perform research before the user explicitly approves it. Keep this phase conversation-only: no subagent and no disk writes. Carry approved findings into the stack recommendation and project brief without silently redefining the user's project.

---

## Phase 2 — Tech stack recommendation

Based on the discovery answers and, when performed, the existing-solutions research, recommend a stack optimised for scale, fast deployment, AI-assisted development, and operational simplicity. Present it as:

- **Frontend** (if applicable)
- **Backend / API**
- **Database**
- **Auth**
- **Hosting / infra**
- **CI/CD**
- **Testing strategy**
- **AI integration** (if applicable)

For each choice: one-line rationale + rejected alternatives and why.

Ask the user with `["Stack approved — write the brief", "Adjust the stack", "Other"]`. On `Adjust` or `Other`, capture corrections, revise the recommendation, re-present. Loop until approved.

---

## Phase 3 — Project brief

Read `dreamers/templates/project-brief.md`. Fill it out using the discovery answers and agreed stack. Write it to `.dreamers/atlas/project-brief.md` (create the directory if it doesn't exist).

If existing-solutions research was performed, use its cited findings to sharpen the brief's problem framing, differentiation, and risks. Do not turn an absence of search results into a market-validation claim.

Present the brief to the user in chat, then ask the user with `["Brief approved — bootstrap the repo", "Revise the brief", "Other"]`. On `Revise` or `Other`, capture changes, update the brief on disk, re-present. Do not proceed to Phase 4 until explicit approval.

---

## Phase 4 — Repo & workspace bootstrap

Follow `refs/project-bootstrap.md` for checklist.

**Check for existing repo:**
```
git rev-parse --is-inside-work-tree 2>/dev/null
```

If not already a repo:
1. Ask the user with `["Public", "Private", "Other"]` to choose repo visibility.
2. Run the following commands inline (no subagent — this is mechanical setup the orchestrator does directly):
   - `git init`
   - `gh repo create [project-name] --[public|private] --source=. --remote=origin`
   - `git remote set-url origin git@github.com:[owner]/[project-name].git`
   - Create `.gitignore` with `.dreamers/` plus standard ignores for the agreed stack
   - Create `.dreamers/plans/` and `.dreamers/atlas/` directories

Then create the project-level `AGENTS.md, CODEX.md, or .github/copilot-instructions.md when present` per `project-bootstrap.md` ownership rules — this requires judgment and is done directly.
---

## Phase 5 — Shell plans

Read `dreamers/templates/shell-plan.md` and `dreamers/templates/plan-guide-selector.md`. For each milestone in the approved brief, create a shell plan in `.dreamers/plans/feature-<slug>/` using the smallest selected guide that preserves quality.

After writing all plans, list them in chat with file paths and one-line summaries.

---

## Phase 6 — Review loop

Ask the user with `["Shell plans look good — I'll take it from here", "Revise the milestones (split / merge / reorder / rescope)", "Other"]`.

- `Look good` → exit this skill; tell the user to invoke `dreamers-plan` on a specific milestone (or `dreamers` to plan + implement in one session).
- `Revise` or `Other` → capture changes, update affected plan files, re-list all plans, re-call the gate. Repeat until the user signs off.

This skill ends when the user is happy with the shell plans. From there the user invokes `dreamers-plan` on a specific milestone (or `dreamers` to plan + implement in one session).
