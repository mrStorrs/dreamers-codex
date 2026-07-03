---
name: dreamers-plan
description: "Planning skill — 3-phase requirements conversation (Hash-out / Write / Review). Runs the Grill phase, selects lite / standard / complex planning, produces right-sized plan file(s) under .dreamers/plans/feature-<slug>/ and optional manifest, then hard-stops at the review gate; never implements. Use when the user asks for dreamers-plan, plan a feature, write a plan."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

Skill input: use the user's message, including any paths or flags.

If no task description was provided, halt + ask.

Template read at runtime by reading the local file:
- `dreamers/templates/plan-guide-selector.md` — plan-type selection, override rule, manifest trigger, ship-strategy heuristics.
- One selected guide only after classification: `plan-guide-lite.md`, `plan-guide-standard.md`, or `plan-guide-complex.md`.

## Codex todo - Before you begin
- Call `update_plan` with a todo list marking all steps at entry: Step 1 / Step 2 / Step 3.

## Step 1 — Hash out
- Write a one-paragraph understanding summary of the goal.

<planning-grill>
### Phase 1A — Grill

```
Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design
tree resolving dependencies between decisions one by one.

If a question can be answered by exploring the codebase, explore
the codebase instead.

When a decision still needs user input, use the structured question
tool (`request_user_input`) if available; otherwise ask directly.
Ask one blocking question at a time; do not dump a batch of questions
in chat. Each question must include or allow exactly these choices:

1. Your recommended answer, labeled as recommended.
2. The strongest viable alternate.
3. `Other` for freeform direction.

After each answer, fold the decision into the shared understanding,
then continue to the next unresolved branch.
```
</planning-grill>

- Identify ambiguities, gaps, open decisions. Ask the user about unresolved decision branches. Do not draft the proposal while required decisions are still open.

### Phase 1B — Proposal review

- Draft the proposal, then enter proposal review before approval. Present the proposal + critique together by asking the user.
- Proposal review stress-tests the proposal for pitfalls, weak spots, tradeoffs, hidden assumptions, likely failure modes, scope risks, and simpler counter-proposals. Approval is valid only after this critique is shown.
- If the user responds with questions, challenges, partial answers, corrections, or counter-proposals, fully review and answer them with reasoning, implications, and a recommended next move. Fold the result into the proposal, re-critique, and re-present proposal review until approved.
- Read `plan-guide-selector.md`. Classify plan type as `lite`, `standard`, or `complex`; explicit user plan-type override wins. Decide plan count + manifest per the selector. Manifest backfill check: existing `feature-<slug>/` + `plan-01-*.md` + no `manifest.md` → manifest MUST be produced in Step 2.

## Step 2 — Write plans
- Read only the selected guide in full by reading the local file: `plan-guide-lite.md`, `plan-guide-standard.md`, or `plan-guide-complex.md`.
- `mkdir -p .dreamers/plans/feature-<slug>/`.
- Write each `plan-NN-<name>.md` + manifest if Step 1 decided yes. Each plan MUST include `**Plan-type:** <lite|standard|complex>` and follow the selected guide. Keep the smallest plan that preserves quality.
- Component-usage check: for shared components, grep the project source root for callers; include them in scope.
- Citation accuracy: verify every cited artifact exists; mark unverifiable citations as "assumption pending verification."
- Self-check the written plans against the selected guide + selector mandatory checks before exit. Hard fail on any structural rule violation → halt + fix + re-check.
- Plan coverage review: compare the written plan(s) against the approved proposal, proposal critique, and all user-discussed questions, corrections, decisions, and constraints. Every accepted item MUST appear in the smallest selected-guide section that preserves meaning. If any item is missing, ambiguous, contradicted, or weakened, fix the plan(s), then re-run citation accuracy + structural self-check + coverage review before Step 3.

## Step 3 — Review gate
- Present plan paths by asking the user with: `Approved` / `Minor edit` / `Major rewrite` / `Halt` / `Other`.
- Minor edits applied inline + re-run Step 2 self-check + re-present.
- Major rewrite → loop back to Step 1 with the correction as new context.

## Exit
- Surface plan paths. Hard stop — never invokes implementation.

## Dreamers Kernel
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
