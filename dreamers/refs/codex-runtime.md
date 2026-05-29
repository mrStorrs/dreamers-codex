# Codex Runtime Mapping

Use this reference when executing Dreamers skills that were converted from the Copilot CLI package.

## Inputs
- Treat the user's prompt as the skill input. Former slash commands such as `dreamers-plan` are now Codex skill names such as `dreamers-plan`.
- If a skill names another Dreamers skill, use that skill when it is available. If it is not available, execute the named steps inline.

## Resource Resolution
Resolve Dreamers shared files in this order:
1. Plugin-local files next to the skill: `../dreamers/refs`, `../dreamers/templates`, `../dreamers/agents`.
2. Direct-install files under `$CODEX_HOME/dreamers` or `~/.codex/dreamers`.
3. Project-local compatibility files under `.github/dreamers` when working in a repository that still carries the Copilot layout.

Project instructions may live in `AGENTS.md`, `CODEX.md`, `AGENTS.md`, `CODEX.md`, or `.github/copilot-instructions.md`, or project-specific docs. Read whichever exist and let more local project instructions override general Dreamers defaults.

## User Gates
- A gate is mandatory when the skill asks for approval, ship strategy, major-refactor disposition, user testing, PR approval, or continuation.
- Ask the user directly and wait. If a structured input tool is available, it may be used, but do not silently continue past a gate.
- On halt, provide the exact skill name and input needed to resume.

## Planning And Progress
- The parent Dreamers skill owns `update_plan`.
- Spawned reviewer, documentarian, or researcher roles must not call `update_plan`; their output is the handoff.

## Delegation
- Use `tool_search` to discover `multi_agent_v1` if multi-agent tools are not visible.
- Use `multi_agent_v1.spawn_agent` only when the user invoked a Dreamers workflow that explicitly includes delegated reviewer, documentarian, or researcher roles, such as `dreamers-review`, `dreamers-docs`, `dreamers-research`, or `dreamers-full`.
- Pass the relevant role prompt from `dreamers/agents/<role>.md` as the sub-agent task context.
- If multi-agent tools are unavailable, run the requested lens inline and label the output with the role name.

## Tool Translation
- Former `request_information`: ask the user in the conversation and wait.
- Former `task()`: `multi_agent_v1.spawn_agent`, followed by `wait_agent` when the result is needed.
- Former `view`: read the local file with available file tools.
- Former `manage_todo_list`: `update_plan` in the parent conversation only.
- Former Copilot global home `~/.copilot`: `$CODEX_HOME` when set, otherwise `~/.codex`.

## Git And Shell Safety
Follow Codex's current shell, sandbox, approval, and git-worktree rules. Do not install dependencies, push, open PRs, or run destructive commands without the approvals required by the active Codex environment.
