# Dreamers Codex

Dreamers Codex is a Codex-native conversion of the Dreamers orchestration package. It keeps the original planning -> tests-first implementation -> reviewer triad -> docs -> PR flow, but exposes it as Codex skills instead of slash commands.

## Layout

```text
.codex-plugin/plugin.json      # local Codex plugin manifest
skills/dreamers-*/SKILL.md     # Codex skill entry points
dreamers/agents/*.md           # role prompts for delegated reviewers/docs/research
dreamers/refs/*.md             # shared workflow rules and runtime mapping
dreamers/templates/*.md        # plan, PR, issue, and project templates
dreamers/instructions/*.md     # compatibility instruction files
```

## Install For Direct Skill Discovery

```powershell
.\Install-DreamersCodex.ps1
```

By default the installer targets `$env:CODEX_HOME` when set, otherwise `~/.codex`. It copies skills to `skills/` and shared Dreamers resources to `dreamers/` under that home. Use `-Force` to overwrite existing Dreamers files.

## Use

Mention the skill name in a Codex request:

- `dreamers-plan` for planning only.
- `dreamers-implement` for one approved plan.
- `dreamers-review` for the Sentinel + Probe + Hone review lenses.
- `dreamers-full` for the complete pipeline.
- `dreamers-docs`, `dreamers-pr`, `dreamers-fix`, and the utility skills for narrower flows.

The converted skills apply `dreamers/refs/codex-runtime.md` to translate the former command, delegation, and approval-gate concepts into Codex tool usage.
