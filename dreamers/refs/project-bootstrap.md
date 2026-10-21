# Project Bootstrap

## Bootstrap checklist for new repos
1. Ensure `.dreamers/` is in the project's `.gitignore`
2. Create project-level `AGENTS.md`, or extend the project's existing instruction file.
3. Create `.dreamers/plans/` directory
4. Copy `dreamers/instructions/dreamers.comment-rules.instructions.md` into the project's `.github/instructions/` and reference it from `AGENTS.md`. Codex must be directed to read compatibility instruction files.
5. **Optional but recommended. (Ask user if they want this created or not):** create `.github/instructions/build.instructions.md` if the project has a defined build/distribution flow for test builds. The file is the authoritative playbook the orchestrator follows during user-testing pauses. It should specify:
   - Which commands (if any) the orchestrator is authorised to run itself
   - Which steps must be performed by the user (install on device, launch app, version/build number to verify, etc.)
   - Where the build artifact lives (link, path, store listing) and how to fetch it
   - How to recover from a failed build/distribution
   If this file is absent, the orchestrator will pause user-testing rounds and ask the user to build/distribute manually.
