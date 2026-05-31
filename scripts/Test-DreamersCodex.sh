#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Test-DreamersCodex.sh [--root <path>]

Validates the Codex package layout, catalog paths, JSON files, frontmatter,
and stale Copilot/runtime tokens using Bash + Python.
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

python3 - "$root" <<'PY'
from pathlib import Path
import json
import re
import sys

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


expected_agents = ["echo", "forge", "hone", "nova", "probe", "sage", "sentinel"]
expected_skills = [
    "dreamers-add-logging",
    "dreamers-clean-work",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-docs",
    "dreamers-fix",
    "dreamers-full",
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
    "logging-discipline.md",
    "project-bootstrap.md",
    "reviewer-findings-format.md",
    "testing-mandate.md",
]
expected_templates = [
    "discovery-questions.md",
    "github-issue.md",
    "logging-standards.md",
    "manifest.md",
    "plan-writing-guide.md",
    "plan.md",
    "pr-description.md",
    "project-brief.md",
    "shell-plan.md",
    "test-benchmarks.md",
]
expected_instructions = [
    "comment-rules.instructions.md",
    "dreamers.instructions.md",
    "git.instructions.md",
]
expected_skill_readmes = [
    "dreamers-add-logging",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-fix",
    "dreamers-full",
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
        if not re.search(rf'(?m)^name\s*=\s*"{re.escape(name)}"\s*$', content):
            add_error(f"Agent name does not match basename: {path}")
        if not re.search(r'(?m)^description\s*=\s*".+"\s*$', content):
            add_error(f"Agent missing non-empty description: {path}")
        if not re.search(r"(?s)developer_instructions\s*=\s*'''(.+)'''", content):
            add_error(f"Agent missing developer_instructions literal block: {path}")

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

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

print("Dreamers Codex validation passed.")
PY
