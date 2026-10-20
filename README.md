# Dreamers Codex

Dreamers Codex converts the Dreamers Copilot package into Codex skills: planning → implementation and tests → selected review → Vigil follow-up review → docs → PR. It tracks the upstream refactor merged in [Copilot PR #72](https://github.com/mrStorrs/dreamers-copilot/pull/72).

## Layout

```text
.codex-plugin/plugin.json      # local Codex plugin manifest
agents/*.toml                  # Codex-native Dreamers role definitions
skills/dreamers{,-*}/SKILL.md  # Codex skill entry points
dreamers/refs/*.md             # shared workflow rules and runtime mapping
dreamers/templates/*.md        # plan, manifest, PR, issue, and project templates
dreamers/instructions/*.md     # compatibility instruction files
```

## Install For Direct Skill Discovery

Linux:

```bash
./Install-DreamersCodex.sh
```

Windows:

```powershell
.\Install-DreamersCodex.ps1
```

By default the installer targets `CODEX_HOME` when set, otherwise `~/.codex`. It copies the five Codex agents to `agents/`, exact `dreamers` plus `dreamers-*` skills to `skills/`, and shared refs/templates/instructions to `dreamers/`. Use `--force` in bash or `-Force` in PowerShell to overwrite existing Dreamers files.

Installation and removal prune only known managed files from retired Forge, Nova, Sage, `dreamers-full`, and `dreamers-research` installations, obsolete plan guides and refs, and legacy `dreamers/agents/` prompt copies. User-owned files are preserved; retired skill directories are removed only when empty. `dreamers-lite` remains active for task delivery without planning.

## Use

Explicit user instructions can skip or alter skill phases/actions.

Across Dreamers skills, an explicit user choice to defer a suggested change appends a structured entry to project-root `defered.md` without overwriting prior entries.

Mention the skill name in a Codex request:

- `dreamers-help` for read-only orientation, examples, reviewer lanes, gates, specialized choices, and migration guidance. Empty or help-like `dreamers` input routes here before repository or external inspection.
- `dreamers-plan` for interactive Grill planning that stores every question and response word for word in `grilling-transcript.md`, links it from each right-sized plan, and verifies plan coverage before the review gate.
- `dreamers-implement` for implementing a task or approved plan with tests. Tasks use stated requirements as acceptance criteria. It returns requirement coverage at green validation and does not review or ship.
- `dreamers-review` for artifact-backed review selected from plan complexity or explicit plan/user direction. For plan-bound reviews, it reads the linked or sibling verbatim Grill transcript when present and supplies it as intent context. Without a plan, it infers intent from code and context, asking if unclear. Multi-reviewer lanes spawn concurrently.
- `dreamers` for delivering plans. Task input invokes `dreamers-plan` and the implementation-start gate; supplied plan paths or manifests authorize implementation and skip planning and that gate. Each plan goes through implementation, selected review, and up to 3 Vigil fix cycles, followed by triggered user testing, docs, commit, PR approval, and `dreamers-pr`.
- `dreamers-lite` for task delivery without planning: implementation and tests, Vigil review with up to 2 fix cycles, docs from the uncommitted diff, commit, and PR approval. Both delivery skills halt on blocked review or unresolved findings at the cap.
- `dreamers-find-refactors` for refactor discovery: select lenses, section the repo, run section-scoped Hone audits, synthesize findings, write Dreamers plan files, then stop.
- `dreamers-new-project` for project bootstrap: discovery, optional user-approved existing-solutions research, stack selection, brief, and shell plans.
- `dreamers-explain` for thorough, read-only explanations of topics, code, documents, systems, and decisions, with authoritative sources when needed.
- `dreamers-pr-resolve` for PR feedback resolution; Vigil reviews accepted changes and deferred Vigil findings are appended to project-root `defered.md`.
- `dreamers-docs`, `dreamers-pr`, and the utility skills for narrower flows. `dreamers-pr` also archives shipped Dreamers plan artifacts after PR creation.

All plans use Goal, Scope and context, and Acceptance Criteria. Validation checks belong with their ACs. Lite, standard, and complex select review lanes: Vigil; Sentinel + Probe; or Sentinel + Probe + Hone. Explicit plan or user direction overrides that mapping. Useful flow diagrams or UI wireframes belong in Scope and context.

The converted skills apply `dreamers/refs/codex-runtime.md` for Codex resource resolution, delegation, and gates. Specialized skills run in the same orchestrator context. Planning, research, implementation, tests, and git operations stay inline. The only subagents are Sentinel, Probe, Hone, Vigil, and Echo. Reviewers write one `.dreamers/reviews/` artifact each; Echo updates docs. Multi-reviewer lanes launch concurrently, and the caller reads all artifacts before applying findings.

Both delivery skills keep one progress record across conversational detours, including the active branch/PR, next phase, and review count. Related bug reports reopen implementation, validation, review, and docs as needed. Updates to an open PR require approval for the current changes before commit and push; existing authorization is reused. Short standalone helper skills have optional todos.

## Validation

Use `scripts/sync-refs.ps1 -Verify` or `scripts/sync-refs.sh -Verify` to check inlined ref drift. Run both `scripts/Test-DreamersCodex.sh` and `scripts/Test-DreamersCodex.ps1` for package structure, behavior contracts, catalog/plugin integrity, stale-token checks, and isolated-home installation migration.

## Maintaining Dreamers

Use `dreamers-update` for changes to Dreamers system files. The Copilot repo (`C:\projects\dreamers-copilot`) remains the upstream source of truth; the skill branches, applies, validates, commits, pushes, and opens the Copilot PR first. It then stops for user approval, supports repeated Copilot PR revisions, and transfers to Codex only after approval.
