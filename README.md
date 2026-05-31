# Dreamers Codex

Dreamers Codex is a Codex-native conversion of the Dreamers orchestration package. It keeps the original planning -> tests-first implementation -> reviewer triad -> docs -> PR flow, but exposes it as Codex skills instead of slash commands.

## Layout

```text
.codex-plugin/plugin.json      # local Codex plugin manifest
agents/*.toml                  # Codex-native Dreamers role definitions
skills/dreamers-*/SKILL.md     # Codex skill entry points
dreamers/refs/*.md             # shared workflow rules and runtime mapping
dreamers/templates/*.md        # plan, PR, issue, and project templates
dreamers/instructions/*.md     # compatibility instruction files
```

## Install For Direct Skill Discovery

```powershell
.\Install-DreamersCodex.ps1
```

By default the installer targets `$env:CODEX_HOME` when set, otherwise `~/.codex`. It copies Codex agent definitions to `agents/`, skills to `skills/`, and shared Dreamers refs/templates/instructions to `dreamers/` under that home. It also removes the legacy deployed `dreamers/agents/` prompt copies from earlier conversions. Use `-Force` to overwrite existing Dreamers files.

## Use

Mention the skill name in a Codex request:

- `dreamers-plan` for interactive planning with proposal review before approval.
- `dreamers-implement` for one approved plan.
- `dreamers-review` for full-triad, selected-lens, or single-lens review lanes.
- `dreamers-full` for the complete pipeline, with gates inline at plan approval, implementation start, templated user testing when triggered, and final pre-PR approval.
- `dreamers-docs`, `dreamers-pr`, `dreamers-fix`, and the utility skills for narrower flows.

The converted skills apply `dreamers/refs/codex-runtime.md` to translate the former command, delegation, and approval-gate concepts into Codex tool usage. Dreamers roles are spawned by Codex agent type (`forge`, `sentinel`, `probe`, `hone`, `echo`, `sage`, `nova`) from the top-level `agents/*.toml` definitions.

## Validation

Use `scripts/sync-refs.ps1 -Verify` or `scripts/sync-refs.sh -Verify` to check inlined ref drift. Use `scripts/Test-DreamersCodex.ps1` or `scripts/Test-DreamersCodex.sh` for Codex package structure, catalog, and stale-token validation.

## Maintaining Dreamers

Use `dreamers-update` for changes to Dreamers system files. The Copilot repo (`C:\projects\dreamers-copilot`) remains the upstream source of truth; the skill branches, applies, validates, commits, pushes, and opens the Copilot PR first. It then stops for user approval, supports repeated Copilot PR revisions, and transfers to Codex only after approval.
