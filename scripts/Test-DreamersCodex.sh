#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Test-DreamersCodex.sh [--root <path>]

Validates inlined refs, Codex package layout, catalog paths, JSON files,
frontmatter, and stale Copilot/runtime tokens using Bash + Python.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd -- "$script_dir/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      root="$(cd -- "$2" && pwd)"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

"$script_dir/sync-refs.sh" -Verify

python3 - "$root" <<'PY'
from pathlib import Path
import json
import re
import sys
import tomllib

root = Path(sys.argv[1])
errors: list[str] = []


def add_error(message: str) -> None:
    errors.append(message)


def assert_exact(label: str, expected: list[str], actual: list[str]) -> None:
    expected_set = set(expected)
    actual_set = set(actual)
    for item in sorted(expected_set - actual_set):
        add_error(f"Missing {label} item: {item}")
    for item in sorted(actual_set - expected_set):
        add_error(f"Unexpected {label} item: {item}")


def assert_path(path: Path, label: str) -> None:
    if not path.exists():
        add_error(f"Missing {label}: {path}")


def assert_patterns(path: Path, patterns: dict[str, str]) -> None:
    if not path.exists():
        add_error(f"Missing contract file: {path}")
        return
    content = path.read_text(encoding="utf-8")
    for label, pattern in patterns.items():
        if not re.search(pattern, content, re.IGNORECASE | re.MULTILINE | re.DOTALL):
            add_error(f"Missing {label} contract in {path}")


def assert_no_patterns(path: Path, patterns: dict[str, str]) -> None:
    if not path.exists():
        add_error(f"Missing contract file: {path}")
        return
    content = path.read_text(encoding="utf-8")
    for label, pattern in patterns.items():
        if re.search(pattern, content, re.IGNORECASE | re.MULTILINE | re.DOTALL):
            add_error(f"Unexpected {label} contract in {path}")


expected_agents = ["echo", "forge", "hone", "nova", "probe", "sage", "sentinel", "vigil"]
expected_skills = [
    "dreamers",
    "dreamers-add-logging",
    "dreamers-clean-work",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-docs",
    "dreamers-lite",
    "dreamers-find-refactors",
    "dreamers-implement",
    "dreamers-issue",
    "dreamers-new-project",
    "dreamers-plan",
    "dreamers-plan-verify",
    "dreamers-pr",
    "dreamers-pr-resolve",
    "dreamers-research",
    "dreamers-review",
    "dreamers-simplify",
    "dreamers-test",
    "dreamers-update",
]
expected_refs = [
    "agent-recovery.md",
    "codex-runtime.md",
    "comment-rules.md",
    "dreamers-kernel.md",
    "git-workflow.md",
    "hone-architecture-rubric.md",
    "logging-discipline.md",
    "planning-grill.md",
    "project-bootstrap.md",
    "reviewer-findings-format.md",
    "testing-mandate.md",
]
expected_templates = [
    "discovery-questions.md",
    "github-issue.md",
    "logging-standards.md",
    "manifest.md",
    "plan-guide-complex.md",
    "plan-guide-lite.md",
    "plan-guide-selector.md",
    "plan-guide-standard.md",
    "plan.md",
    "pr-description.md",
    "project-brief.md",
    "shell-plan.md",
    "test-benchmarks.md",
    "user-testing-gate.md",
]
expected_instructions = [
    "dreamers.comment-rules.instructions.md",
    "dreamers.instructions.md",
    "dreamers.laws.md",
]
expected_skill_readmes = [
    "dreamers",
    "dreamers-add-logging",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-lite",
    "dreamers-find-refactors",
    "dreamers-implement",
    "dreamers-new-project",
    "dreamers-plan",
    "dreamers-pr-resolve",
    "dreamers-research",
    "dreamers-review",
]

agent_root = root / "agents"
skill_root = root / "skills"
dreamers_root = root / "dreamers"

assert_path(agent_root, "agents directory")
assert_path(skill_root, "skills directory")
assert_path(dreamers_root, "dreamers directory")

if (dreamers_root / "agents").exists():
    add_error(f"Legacy role prompt directory should not exist: {dreamers_root / 'agents'}")

if agent_root.exists():
    actual_agents = [path.stem for path in agent_root.glob("*.toml")]
    assert_exact("agent", expected_agents, actual_agents)
    for name in expected_agents:
        path = agent_root / f"{name}.toml"
        if not path.exists():
            continue
        content = path.read_text(encoding="utf-8")
        try:
            tomllib.loads(content)
        except Exception as exc:
            add_error(f"Invalid agent TOML: {path} ({exc})")
        if not re.search(rf'(?m)^name\s*=\s*"{re.escape(name)}"\s*$', content):
            add_error(f"Agent name does not match basename: {path}")
        if not re.search(r'(?m)^description\s*=\s*".+"\s*$', content):
            add_error(f"Agent missing non-empty description: {path}")
        if not re.search(r"(?s)developer_instructions\s*=\s*'''(.+)'''", content):
            add_error(f"Agent missing developer_instructions literal block: {path}")
        if name in {"sentinel", "probe", "hone", "vigil"} and re.search(
            r"(?m)^model(?:_reasoning_effort)?\s*=", content
        ):
            add_error(f"Reviewer agent pins model configuration: {path}")

if skill_root.exists():
    actual_skills = [path.name for path in skill_root.iterdir() if path.is_dir()]
    assert_exact("skill", expected_skills, actual_skills)
    for skill_name in expected_skills:
        path = skill_root / skill_name / "SKILL.md"
        if not path.exists():
            add_error(f"Missing SKILL.md: {path}")
            continue
        content = path.read_text(encoding="utf-8")
        if not re.search(r"(?s)^---\s*\nname:\s*([^\n]+)\ndescription:\s*([^\n]+)\n---", content):
            add_error(f"Invalid frontmatter: {path}")
        if "argument-hint:" in content:
            add_error(f"Copilot argument-hint remains: {path}")
    for skill_name in expected_skill_readmes:
        path = skill_root / skill_name / "readme.md"
        if not path.exists():
            add_error(f"Missing skill readme copied from source: {path}")

for label, directory, expected in [
    ("ref", dreamers_root / "refs", expected_refs),
    ("template", dreamers_root / "templates", expected_templates),
    ("instruction", dreamers_root / "instructions", expected_instructions),
]:
    if not directory.exists():
        add_error(f"Missing {label} directory: {directory}")
        continue
    assert_exact(label, expected, [path.name for path in directory.iterdir() if path.is_file()])

for rel in [".codex-plugin/plugin.json", ".github/catalog.json"]:
    path = root / rel
    if not path.exists():
        add_error(f"Missing JSON file: {path}")
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        add_error(f"Invalid JSON: {path} ({exc})")

catalog_path = root / ".github/catalog.json"
if catalog_path.exists():
    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        items = {f"{item.get('type')}:{item.get('slug')}" for item in catalog.get("items", [])}
        if "skill:dreamers" not in items:
            add_error("Catalog missing item: skill:dreamers")
        for retired in ["skill:dreamers-full"]:
            if retired in items:
                add_error(f"Catalog retains retired item: {retired}")
        for item in catalog.get("items", []):
            item_path = item.get("path")
            if not item_path:
                continue
            if item_path.startswith(".github/") or item_path.startswith("skillsdreamers-"):
                add_error(f"Catalog path is not Codex-layout: {item_path}")
                continue
            if not (root / item_path).exists():
                add_error(f"Catalog item path does not exist: {item_path}")
        for collection in catalog.get("collections", []):
            readme_path = collection.get("readmePath")
            if readme_path and not (root / readme_path).exists():
                add_error(f"Catalog readmePath does not exist: {readme_path}")
            members = {
                f"{member.get('type')}:{member.get('slug')}"
                for member in collection.get("members", [])
            }
            if "skill:dreamers" not in members:
                add_error("Collection missing member: skill:dreamers")
            for retired in ["skill:dreamers-full"]:
                if retired in members:
                    add_error(f"Collection retains retired member: {retired}")
        for folder in catalog.get("folderTargets", []):
            source_path = folder.get("sourcePath")
            if not source_path:
                continue
            if source_path.startswith(".github/"):
                add_error(f"Catalog folder sourcePath is not Codex-layout: {source_path}")
                continue
            if not (root / source_path).exists():
                add_error(f"Catalog folder sourcePath does not exist: {source_path}")
    except Exception as exc:
        add_error(f"Unable to validate catalog paths: {exc}")

assert_patterns(
    skill_root / "dreamers/SKILL.md",
    {
        "missing-input halt": r"If no task description, plan path, or manifest was provided, halt \+ ask",
        "three input modes": r"## Modes.*Task description.*Plan path\(s\).*manifest\.md",
        "planning delegation": r"## Phase 1.*Invoke `dreamers-plan`",
        "implementation then review": r"### Steps 1.3.*Invoke `dreamers-implement.*### Step 4.*Invoke `dreamers-review",
        "complexity-selected review": r"selects Vigil, Sentinel \+ Probe, or Sentinel \+ Probe \+ Hone from plan complexity or explicit plan/user direction",
        "major-refactor gate": r"Major-refactor gate.*Apply now.*Defer — save to defered\.md.*Other",
        "deferred findings ledger": r"Defer.*do NOT apply or create a follow-up plan.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`",
        "major-change rerun gate": r"Run Vigil.*Run full triad.*Run selected dreamers-review lane.*Skip reviewer rerun.*Other",
        "templated user testing": r"user-testing-gate\.md.*Testing steps.*Notes.*Approved.*Bug found \(enter text\).*Other \(enter text\)",
        "full close-out": r"Phase 3.*improvements\.md.*dreamers-docs --branch.*Write retro.*Final commit.*User approval gate.*dreamers-pr",
    },
)
assert_patterns(
    skill_root / "dreamers-pr-resolve/SKILL.md",
    {
        "deferred Vigil findings ledger": r"Defer — save to defered\.md.*do NOT apply.*create a follow-up plan.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`",
        "deferred ledger commit": r"If any fixes landed or Step 5 added deferred entries",
        "deferred ledger report": r"Deferred Vigil findings recorded in `defered\.md`",
    },
)
assert_no_patterns(
    skill_root / "dreamers/SKILL.md",
    {
        "retired pipeline name": r"dreamers-(?:full|lite)",
        "help route": r"--help|dreamers-help",
        "Grill opt-out": r"--no-grill|do not grill|skip the interview",
        "inline implementation refs": r"<(?:planning-grill|testing-mandate|comment-rules|logging-discipline|reviewer-findings-format|agent-recovery)>",
    },
)
assert_patterns(
    skill_root / "dreamers-implement/SKILL.md",
    {
        "tests-first implementation": r"failing tests.*implement|tests.first",
        "green exit": r"Return the AC coverage matrix at green tests.*invokes `dreamers-review` immediately",
        "phase boundary": r"Do not invoke reviewers.*user testing.*commit.*push.*PR creation",
        "conditional plan ownership": r"When standalone.*update_plan.*When invoked by an outer delivery skill.*existing plan",
    },
)
assert_patterns(
    skill_root / "dreamers-review/SKILL.md",
    {
        "Vigil mode": r"--vigil.*Vigil|Vigil.*--vigil",
        "full mode": r"--full.*Sentinel \+ Probe \+ Hone",
        "selection precedence": r"explicit lane flag or explicit user direction.*explicit reviewer requirement.*Plan-type",
        "lite selection": r"lite` = Vigil",
        "standard selection": r"standard` = Sentinel \+ Probe",
        "complex selection": r"complex` = Sentinel \+ Probe \+ Hone",
        "planless intent inference": r"infer the intended behavior.*explicit user direction.*PR title/body.*commits and diff.*changed tests.*changed code",
        "planless ambiguity question": r"one reliable interpretation.*ask the user one concise question",
        "planless reviewer basis": r"review basis.*absolute plan path.*inferred-intent summary",
        "parallel spawning": r"launch every selected reviewer concurrently.*Never spawn or await reviewers sequentially",
        "caller owns fix loop": r"caller owns all finding disposition, gates, fixes, revalidation, and user testing",
        "artifact-only reviewer writes": r"sole write is exactly one.*artifact",
    },
)
assert_patterns(
    agent_root / "vigil.toml",
    {
        "planless Vigil review basis": r"If no plan is bound.*inferred-intent summary.*evidence",
        "planless Vigil requirements": r"plan AC or inferred requirement",
    },
)
assert_patterns(
    agent_root / "probe.toml",
    {
        "planless Probe review basis": r"no plan is bound.*inferred requirements",
        "planless Probe findings": r"report missing or weak coverage as findings",
    },
)
assert_patterns(
    skill_root / "dreamers-new-project/SKILL.md",
    {
        "existing-solutions opt-in gate": r"Phase 1\.5.*ask the user.*Research similar existing solutions.*Skip research",
        "research blocked before approval": r"Do not perform research before the user explicitly approves it",
        "research remains conversation-only": r"Keep this phase conversation-only: no subagent and no disk writes",
        "research informs downstream artifacts": r"existing-solutions research.*stack recommendation.*project brief",
    },
)
assert_patterns(
    dreamers_root / "instructions/dreamers.instructions.md",
    {
        "same-context skill invocation": r"skill.*same orchestrator context|same orchestrator context.*skill",
        "outermost plan ownership": r"outermost skill.*owns.*(?:todo|plan)|(?:todo|plan).*owned by.*outermost skill",
        "global deferred suggestions ledger": r"Deferred suggestions.*explicitly chooses `Defer`.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`",
    },
)
assert_patterns(
    dreamers_root / "refs/codex-runtime.md",
    {
        "same-context composition": r"invoke it in the same orchestrator context",
        "parallel reviewer runtime": r"launch every selected reviewer concurrently.*Never spawn and await reviewers sequentially",
    },
)
assert_no_patterns(
    skill_root / "dreamers-update/SKILL.md",
    {"implementation mirror rule": r"dreamers-implement mirror"},
)
assert_patterns(
    root / ".codex-plugin/plugin.json",
    {"unified default prompt": r"Use dreamers to plan and ship"},
)

scan_roots = [
    root / "agents",
    root / "skills",
    root / "dreamers",
    root / "README.md",
    root / "Install-DreamersCodex.ps1",
    root / "Remove-DreamersCodex.ps1",
    root / ".github/catalog.json",
]
scan_files: list[Path] = []
for path in scan_roots:
    if not path.exists():
        continue
    if path.is_dir():
        scan_files.extend(
            child
            for child in path.rglob("*")
            if child.is_file() and child.suffix in {".md", ".toml", ".ps1", ".json"}
        )
    else:
        scan_files.append(path)

stale_patterns = [
    r"Atlas",
    r"WebSearch",
    r"WebFetch",
    r"C:\\Users\\cjsto\\.Codex",
    r"~/.Codex",
    r"\.github/agents/",
    r"\.github/skills/",
    r"\.github/dreamers/",
    r"dreamers/agents/<role>",
    r"dreamers/agents/sentinel",
    r"dreamers/agents/probe",
    r"dreamers/agents/hone",
    r"manage_todo_list",
    r"request_information",
    r"task\(",
]

for path in scan_files:
    rel = path.relative_to(root).as_posix()
    if rel in {"dreamers/refs/codex-runtime.md", "skills/dreamers-update/SKILL.md"}:
        continue
    content = path.read_text(encoding="utf-8", errors="ignore")
    for pattern in stale_patterns:
        if re.search(pattern, content):
            add_error(f"Stale Copilot/legacy token '{pattern}' remains in {rel}")

legacy_pattern = re.compile(r"dreamers-full", re.IGNORECASE)
migration_pattern = re.compile(
    r"retir|remov|legacy|migrat|cleanup|clean up|previous|old command|no longer",
    re.IGNORECASE,
)
for path in [agent_root, skill_root, dreamers_root, root / "README.md", catalog_path, root / ".codex-plugin/plugin.json"]:
    if not path.exists():
        continue
    files = (
        [child for child in path.rglob("*") if child.is_file()]
        if path.is_dir()
        else [path]
    )
    for file in files:
        if file.name.startswith("Test-DreamersCodex"):
            continue
        for line_number, line in enumerate(
            file.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1
        ):
            if legacy_pattern.search(line) and not migration_pattern.search(line):
                add_error(f"Active retired-pipeline reference in {file}:{line_number}")

tmp_base = root / ".tmp"
tmp_home = tmp_base / "dreamers-codex-test-sh"
if tmp_home.exists():
    import shutil
    shutil.rmtree(tmp_home)
try:
    user_instruction = tmp_home / "dreamers/instructions/user-owned.md"
    user_instruction.parent.mkdir(parents=True, exist_ok=True)
    user_instruction.write_text("preserve\n", encoding="utf-8")
    stale_comment_rules = tmp_home / "dreamers/instructions/comment-rules.instructions.md"
    stale_comment_rules.write_text("obsolete managed file\n", encoding="utf-8")
    stale_git_instructions = tmp_home / "dreamers/instructions/git.instructions.md"
    stale_git_instructions.write_text("obsolete managed file\n", encoding="utf-8")
    stale_plan_guide = tmp_home / "dreamers/templates/plan-writing-guide.md"
    stale_plan_guide.parent.mkdir(parents=True, exist_ok=True)
    stale_plan_guide.write_text("obsolete managed file\n", encoding="utf-8")
    active_lite = tmp_home / "skills/dreamers-lite"
    legacy_full = tmp_home / "skills/dreamers-full"
    for directory in [active_lite, legacy_full]:
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "SKILL.md").write_text("managed\n", encoding="utf-8")
        (directory / "readme.md").write_text("managed\n", encoding="utf-8")
    (active_lite / "user-owned.md").write_text("preserve\n", encoding="utf-8")

    import subprocess
    subprocess.run(
        [str(root / "Install-DreamersCodex.sh"), "--codex-home", str(tmp_home), "--force"],
        cwd=root,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if stale_plan_guide.exists():
        add_error(f"Install smoke did not remove obsolete managed file: {stale_plan_guide}")
    if stale_comment_rules.exists():
        add_error(f"Install smoke did not remove obsolete managed file: {stale_comment_rules}")
    if stale_git_instructions.exists():
        add_error(f"Install smoke did not remove obsolete managed file: {stale_git_instructions}")
    if not (tmp_home / "skills/dreamers/SKILL.md").exists():
        add_error("Install smoke did not install exact dreamers skill")
    for managed in ["SKILL.md", "readme.md"]:
        if not (active_lite / managed).exists():
            add_error(f"Install smoke did not install active dreamers-lite file: {active_lite / managed}")
    if "name: dreamers-lite" not in (active_lite / "SKILL.md").read_text(encoding="utf-8"):
        add_error("Install smoke did not replace the active dreamers-lite skill")
    for managed_instruction in [
        "dreamers.comment-rules.instructions.md",
        "dreamers.laws.md",
    ]:
        path = tmp_home / "dreamers/instructions" / managed_instruction
        if not path.exists():
            add_error(f"Install smoke did not install managed instruction: {path}")
    if not user_instruction.exists():
        add_error(f"Install smoke removed user-owned instruction: {user_instruction}")
    for managed in ["SKILL.md", "readme.md"]:
        path = legacy_full / managed
        if path.exists():
            add_error(f"Install smoke retained legacy managed file: {path}")
    if not (active_lite / "user-owned.md").exists():
        add_error(f"Install smoke removed user-owned active file: {active_lite}")
    if legacy_full.exists():
        add_error(f"Install smoke did not prune empty legacy directory: {legacy_full}")
finally:
    if tmp_home.exists():
        import shutil
        shutil.rmtree(tmp_home)

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

print("Dreamers Codex validation passed.")
PY
