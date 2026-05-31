---
name: dreamers-plan
description: "Planning skill — 3-phase requirements conversation (Hash-out / Write / Review). Produces plan file(s) under .dreamers/plans/feature-<slug>/ and optional manifest. Hard-stops at the review gate; never implements. Use when the user asks for dreamers-plan, plan a feature, write a plan."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Skill input: use the user's message, including any paths or flags.

If no task description was provided, halt + ask.

Template read at runtime by reading the local file:
- `dreamers/templates/plan-writing-guide.md` — plan structure, naming, ACs, decomposition, manifest, ship-strategy heuristics.

## Codex todo - Before you begin
- Call `update_plan` with a todo list marking all steps at entry: Step 1 / Step 2 / Step 3.

## Step 1 — Hash out
- Write a one-paragraph understanding summary of the goal.
- Identify ambiguities, gaps, open decisions. Ask all clarifying questions in ONE ask the user round.
- Draft the proposal, then enter proposal review before approval. Present the proposal + critique together by asking the user.
- Proposal review stress-tests the proposal for pitfalls, weak spots, tradeoffs, hidden assumptions, likely failure modes, scope risks, and simpler counter-proposals. Approval is valid only after this critique is shown.
- If the user responds with questions, challenges, partial answers, corrections, or counter-proposals, fully review and answer them with reasoning, implications, and a recommended next move. Fold the result into the proposal, re-critique, and re-present proposal review until approved.
- Decide plan count + manifest per `plan-writing-guide.md`. Manifest backfill check: existing `feature-<slug>/` + `plan-01-*.md` + no `manifest.md` → manifest MUST be produced in Step 2.

## Step 2 — Write plans
- Read `plan-writing-guide.md` in full by reading the local file.
- `mkdir -p .dreamers/plans/feature-<slug>/`.
- Write each `plan-NN-<name>.md` + manifest if Step 1 decided yes.
- Component-usage check: for shared components, grep the project source root for callers; include them in scope.
- Citation accuracy: verify every cited artifact exists; mark unverifiable citations as "assumption pending verification."
- Self-check the written plans against the guide before exit. Hard fail on any structural rule violation → halt + fix + re-check.
- Plan coverage review: compare the written plan(s) against the approved proposal, proposal critique, and all user-discussed questions, corrections, decisions, and constraints. Every accepted item MUST appear in Goal, Context, ACs, Out of Scope, Constraints, Design Decisions, UI, or Verification. If any item is missing, ambiguous, contradicted, or weakened, fix the plan(s), then re-run citation accuracy + structural self-check + coverage review before Step 3.

## Step 3 — Review gate
- Present plan paths by asking the user with: `Approved` / `Minor edit` / `Major rewrite` / `Halt` / `Other`.
- Minor edits applied inline + re-run Step 2 self-check + re-present.
- Major rewrite → loop back to Step 1 with the correction as new context.

## Exit
- Surface plan paths. Hard stop — never invokes implementation.

## Dreamers Kernel
<dreamers-kernel>
# Dreamers Kernel

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
