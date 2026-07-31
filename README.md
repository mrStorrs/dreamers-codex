# Dreamers Codex

Dreamers Codex is a Codex-native conversion of the Dreamers orchestration package. It keeps the original planning → tests-first implementation → selected review → Vigil follow-up review → docs → PR flow, but exposes it as Codex skills instead of slash commands.

## Layout

```text
.codex-plugin/plugin.json      # local Codex plugin manifest
agents/*.toml                  # Codex-native Dreamers role definitions
skills/dreamers{,-*}/SKILL.md  # Codex skill entry points
dreamers/refs/*.md             # shared workflow rules and runtime mapping
dreamers/templates/*.md        # plan guides, PR, issue, and project templates
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

By default the installer targets `CODEX_HOME` when set, otherwise `~/.codex`. It copies Codex agent definitions to `agents/`, exact `dreamers` plus `dreamers-*` skills to `skills/`, and shared Dreamers refs/templates/instructions to `dreamers/` under that home. It removes only known managed files from retired `dreamers-full` installations, preserves user-owned files in those directories, and removes a legacy directory only when empty. It also removes the legacy deployed `dreamers/agents/` prompt copies from earlier conversions. Use `--force` in bash or `-Force` in PowerShell to overwrite existing Dreamers files.

## Use

Explicit user instructions can skip or alter skill phases/actions.

Across Dreamers skills, an explicit user choice to defer a suggested change appends a structured entry to project-root `defered.md` without overwriting prior entries.

Mention the skill name in a Codex request:

- `dreamers-plan` for interactive Grill planning with one question-tool ask at a time, proposal review before approval, user-overridable lite / standard / complex plan type selection, and written-plan coverage review before the review gate.
- `dreamers-implement` for the tests-first implementation phase of one approved plan. It exits at green validation and does not review or ship.
- `dreamers-review` for artifact-backed review selected from plan complexity or explicit plan/user direction. Without a plan, it infers intent from code and context, asking if unclear. Lite plans use Vigil, standard plans use Sentinel + Probe, and complex plans use Sentinel + Probe + Hone. Multi-reviewer lanes spawn concurrently.
- `dreamers` for the complete pipeline. It accepts a task description, existing plan path(s), or a manifest. Task mode invokes `dreamers-plan`, then runs the plan review / implementation-start gate; plan path and manifest modes skip both after plan-quality checks. Per plan it invokes `dreamers-implement`, then `dreamers-review`. The orchestrator applies findings, appends deferred findings to project-root `defered.md`, and owns the major-refactor gate, review-rerun gate, user-testing fix loop, full close-out, final approval, and `dreamers-pr` invocation.
- `dreamers-find-refactors` for refactor discovery: select lenses, section the repo, run section-scoped Hone audits, synthesize findings, write Dreamers plan files, then stop.
- `dreamers-new-project` for project bootstrap: discovery, optional user-approved existing-solutions research, stack selection, brief, and shell plans.
- `dreamers-pr-resolve` for PR feedback resolution; Vigil reviews accepted changes and deferred Vigil findings are appended to project-root `defered.md`.
- `dreamers-docs`, `dreamers-pr`, `dreamers-lite`, and the utility skills for narrower flows. `dreamers-pr` also archives shipped Dreamers plan artifacts after PR creation.

The converted skills apply `dreamers/refs/codex-runtime.md` to translate composition, delegation, and approval gates into Codex tool usage. Specialized skills invoked by `dreamers` run in the same orchestrator context; only reviewer, documentarian, and researcher roles are spawned as subagents. Sentinel, Probe, Hone, and Vigil are read-only for project files and each writes one durable `.dreamers/reviews/` artifact. `dreamers-review` launches every reviewer in a multi-reviewer lane concurrently, reads all artifacts, and returns findings without applying them. `dreamers` applies those findings and uses `dreamers-review --vigil` for normal follow-up review reruns.

## Validation

Use `scripts/sync-refs.ps1 -Verify` or `scripts/sync-refs.sh -Verify` to check inlined ref drift. Run both `scripts/Test-DreamersCodex.sh` and `scripts/Test-DreamersCodex.ps1` for package structure, behavior contracts, catalog/plugin integrity, stale-token checks, and isolated-home installation migration.

## Maintaining Dreamers

Use `dreamers-update` for changes to Dreamers system files. The Copilot repo (`C:\projects\dreamers-copilot`) remains the upstream source of truth; the skill branches, applies, validates, commits, pushes, and opens the Copilot PR first. It then stops for user approval, supports repeated Copilot PR revisions, and transfers to Codex only after approval.
