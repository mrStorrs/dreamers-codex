---
name: dreamers-test
description: "Standalone Probe review (test coverage audit). Read-only — reads Probe's `.dreamers/reviews/` artifact for AC coverage, layer audit, edge cases, and regression risks. No auto-fix. Use when the user asks for dreamers-test, test coverage audit, audit tests, check test gaps."
---

## Codex runtime
Before executing this skill, apply the Codex runtime mapping from `../dreamers/refs/codex-runtime.md` when this package is used as a plugin, or from `$CODEX_HOME/dreamers/refs/codex-runtime.md` when installed directly. Treat the user's message as the former command arguments. Use normal Codex tools, `update_plan` for parent progress tracking, direct user questions for approval gates, and `multi_agent_v1.spawn_agent` only for Dreamers workflows that explicitly call for delegated reviewer, documentarian, or researcher roles.

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

<testing-mandate>
# Testing Coverage Mandate (MANDATORY)

Every plan must express its test coverage intent through the Acceptance Criteria's Layer annotations. The planner specifies *what observable outcome* the AC requires and *which test layer* covers it. The implementer (orchestrator at `dreamers-implement` Step 1) writes the actual tests from each AC's Given/When/Then.

## How test coverage is expressed in plans (new format)

Plan ACs are numbered Given/When/Then statements with a Layer annotation per AC. See `plan-writing-guide.md` § "Acceptance Criteria format" for the canonical spec.

```
<acceptance_criteria>
1. Given <state>, when <trigger>, then <observable outcome>.
   *Layer: unit.*
2. Given <state>, when <trigger>, then <observable outcome>.
   *Layer: integration.*
3. Given <state>, when <trigger>, then <observable outcome>.
   *Layer: E2E.*
</acceptance_criteria>
```

Layer label set (closed): `unit` / `integration` / `E2E` / `perf`. Compound labels allowed when one assertion serves two purposes (e.g., `*Layer: integration / perf.*`).

**Test coverage intent is expressed via the `*Layer: ...*` annotation on each Acceptance Criterion — not via a standalone Test Cases section.** Do not write a separate Test Cases section in a plan; embed the test layer directly in the AC. This keeps ACs and test specification in one place so they never drift.

## Coverage requirement (every plan)

Across all of a plan's ACs, the layer mix must cover the following whenever applicable to the work — think through each layer explicitly:

**Unit layer**
- Each significant function, method, or class in isolation.
- All branches: happy path, edge cases (boundary values, empty/null/max), negative cases (invalid input, error states).
- Any pure logic that does not require a real device, network, or database.

**Integration layer**
- Interactions between layers: repository ↔ data source, ViewModel ↔ repository, service ↔ external API.
- Database reads/writes (real or in-memory, not mocked).
- Auth flows end-to-end within the backend.
- Cloud function triggers and side-effects.

**UI / E2E layer**
- Full user journeys through the UI: screen load → interaction → outcome visible on screen.
- Navigation flows between screens.
- Error and empty states rendered correctly in the UI.
- Any flow that requires a real device or emulator.
- **Navigation change rule (mandatory):** When a plan changes how a nav element behaves (tab tap, modal open, screen transition), the plan must include at least one AC with `*Layer: E2E.*` — not just unit/integration. Probe enforces this in the layer audit and blocks if missing.

**Regression risks**
- Anything touching existing behavior that could break — call out the specific existing test or flow at risk in the plan's Context section.

If a layer cannot be covered automatically (e.g., camera permission flows), flag it explicitly as a manual-verification requirement in the plan's Verification section with a reason.

## Probe's layer audit (consumes the new format)

In `dreamers-implement` Step 4 (coverage sweep) and Step 5 (parallel review with Probe), the layer audit reads each AC's `*Layer: ...*` annotation to verify coverage at each layer was implemented. Probe blocks the cycle if any AC's annotated layer lacks a corresponding green test.

## Test benchmarks

Each project that uses `dreamers-implement` maintains a `./test-benchmarks.md` file at the project root. The file records measured run times per test command so the orchestrator can set realistic timeouts.

- **File path:** `./test-benchmarks.md` at the project root (committed to version control).
- **Recommended-timeout formula:** `max(last_run_time × 2, 30s)` — the 2× multiplier accounts for machine variance; 30s is a non-negotiable floor.
- **Orchestrator updates** the row for each test command after every successful test run. **Humans may edit** the `Notes` column to capture CI environment factors or known flakiness.
- Template: `dreamers/templates/test-benchmarks.md` (catalog-relative; resolves to `$CODEX_HOME/dreamers/templates/test-benchmarks.md` or `~/.codex/dreamers/templates/test-benchmarks.md` at install).
</testing-mandate>

Skill input: use the user's message, including any paths or flags.

---

## Argument parsing

Default scope (no flags): staged + unstaged changes.

- `--branch` — scope to feature-branch diff vs default:
  ```bash
  DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  [ -z "$DEFAULT" ] && DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
  ```
- `--paths <glob>` — scope to files matching the glob.
- `--all` — entire codebase. Emit a chat warning before invoking; rare.

---

## Spawn Probe

Invoke via the runtime's subagent-spawn mechanism:

```
agent_type: `probe`
wait: use `multi_agent_v1.wait_agent` for the result
prompt:
  Context: Standalone test-coverage audit via dreamers-test. No plan binding (ad-hoc audit).
  Scope: <list of files from arg parsing above>
  Branch: <current feature branch>
  Default branch: <detected default>
  Lens: test coverage (AC matrix is N/A here — no plan binding; focus on layer audit + edge cases + regression risks for the scope).
  Write: exactly one .dreamers/reviews/probe-*.md artifact.
  Return: status + counts + artifact path + blocked reason + open questions only.
```

## Output

Read the artifact path returned by Probe and pass the artifact contents through to the user verbatim. Do NOT write any tests — this is a read-only audit. Surface any `Blocked` status or open questions for user follow-up.

If the user wants missing tests written from the findings, suggest: "Run `dreamers-implement` with a plan that addresses these coverage gaps."
