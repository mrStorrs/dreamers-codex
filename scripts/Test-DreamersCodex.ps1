[CmdletBinding()]
param(
    [string]$Root = $(if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Get-Location }),
    [switch]$SkipInstallSmoke
)

$ErrorActionPreference = "Stop"
& (Join-Path $Root "scripts/sync-refs.ps1") -Verify
if ($LASTEXITCODE -ne 0) { throw "Inlined ref verification failed." }
$errors = New-Object System.Collections.Generic.List[string]

function Add-Error {
    param([string]$Message)
    $script:errors.Add($Message)
}

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath((Resolve-Path $Root).Path, (Resolve-Path $Path).Path).Replace('\', '/')
}

function Assert-ExactSet {
    param(
        [string]$Label,
        [string[]]$Expected,
        [string[]]$Actual
    )
    $missing = $Expected | Where-Object { $_ -notin $Actual }
    $extra = $Actual | Where-Object { $_ -notin $Expected }
    foreach ($item in $missing) { Add-Error "Missing $Label item: $item" }
    foreach ($item in $extra) { Add-Error "Unexpected $Label item: $item" }
}

function Assert-Path {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { Add-Error "Missing ${Label}: $Path" }
}

function Assert-Patterns {
    param(
        [string]$Path,
        [hashtable]$Patterns
    )
    if (-not (Test-Path $Path)) {
        Add-Error "Missing contract file: $Path"
        return
    }
    $content = Get-Content -Raw $Path
    foreach ($entry in $Patterns.GetEnumerator()) {
        if ($content -notmatch ("(?ms)" + $entry.Value)) {
            Add-Error "Missing $($entry.Key) contract in $Path"
        }
    }
}

function Assert-NoPatterns {
    param(
        [string]$Path,
        [hashtable]$Patterns
    )
    if (-not (Test-Path $Path)) {
        Add-Error "Missing contract file: $Path"
        return
    }
    $content = Get-Content -Raw $Path
    foreach ($entry in $Patterns.GetEnumerator()) {
        if ($content -match ("(?ms)" + $entry.Value)) {
            Add-Error "Unexpected $($entry.Key) contract in $Path"
        }
    }
}

$expectedAgents = @(
    "echo",
    "hone",
    "probe",
    "sentinel",
    "vigil"
)
$expectedSkills = @(
    "dreamers",
    "dreamers-add-logging",
    "dreamers-clean-work",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-docs",
    "dreamers-explain",
    "dreamers-find-refactors",
    "dreamers-help",
    "dreamers-implement",
    "dreamers-issue",
    "dreamers-lite",
    "dreamers-new-project",
    "dreamers-plan",
    "dreamers-plan-verify",
    "dreamers-pr",
    "dreamers-pr-resolve",
    "dreamers-review",
    "dreamers-simplify",
    "dreamers-test",
    "dreamers-update"
)
$expectedRefs = @(
    "agent-recovery.md",
    "codex-runtime.md",
    "comment-rules.md",
    "dreamers-kernel.md",
    "git-workflow.md",
    "logging-discipline.md",
    "manifest-format.md",
    "plan-format.md",
    "planning-grill.md",
    "project-bootstrap.md",
    "reviewer-findings-format.md",
    "shell-plan.md",
    "testing-mandate.md",
    "user-testing-gate.md"
)
$expectedTemplates = @(
    "discovery-questions.md",
    "github-issue.md",
    "logging-standards.md",
    "manifest.md",
    "plan.md",
    "pr-description.md",
    "project-brief.md",
    "shell-plan.md",
    "test-benchmarks.md",
    "user-testing-gate.md"
)
$expectedInstructions = @(
    "dreamers.comment-rules.instructions.md",
    "dreamers.instructions.md",
    "dreamers.laws.md"
)
$expectedSkillReadmes = @(
    "dreamers",
    "dreamers-add-logging",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-explain",
    "dreamers-find-refactors",
    "dreamers-implement",
    "dreamers-lite",
    "dreamers-new-project",
    "dreamers-plan",
    "dreamers-pr-resolve",
    "dreamers-review"
)

$agentRoot = Join-Path $Root "agents"
$skillRoot = Join-Path $Root "skills"
$dreamersRoot = Join-Path $Root "dreamers"

Assert-Path $agentRoot "agents directory"
Assert-Path $skillRoot "skills directory"
Assert-Path $dreamersRoot "dreamers directory"

if (Test-Path (Join-Path $dreamersRoot "agents")) {
    Add-Error "Legacy role prompt directory should not exist: $(Join-Path $dreamersRoot "agents")"
}

if (Test-Path $agentRoot) {
    $actualAgents = Get-ChildItem $agentRoot -Filter '*.toml' -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
    Assert-ExactSet -Label "agent" -Expected $expectedAgents -Actual $actualAgents
    foreach ($name in $expectedAgents) {
        $file = Join-Path $agentRoot "$name.toml"
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content -Raw $file
        $header = ($content -split "(?m)^developer_instructions\s*=", 2)[0]
        $topLevelKeys = [regex]::Matches($header, "(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*=") | ForEach-Object { $_.Groups[1].Value }
        $duplicateKeys = $topLevelKeys | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
        foreach ($key in $duplicateKeys) {
            Add-Error "Duplicate top-level agent TOML key '$key': $file"
        }
        if ($content -notmatch "(?m)^name\s*=\s*`"$name`"\s*$") {
            Add-Error "Agent name does not match basename: $file"
        }
        if ($content -notmatch "(?m)^description\s*=\s*`".+`"\s*$") {
            Add-Error "Agent missing non-empty description: $file"
        }
        if ($content -notmatch "(?s)developer_instructions\s*=\s*'''(.+)'''") {
            Add-Error "Agent missing developer_instructions literal block: $file"
        }
        if ($name -in @("sentinel", "probe", "hone", "vigil") -and $content -match "(?m)^model(?:_reasoning_effort)?\s*=") {
            Add-Error "Reviewer agent pins model configuration: $file"
        }
    }
}

if (Test-Path $skillRoot) {
    $actualSkills = Get-ChildItem $skillRoot -Directory | ForEach-Object { $_.Name }
    Assert-ExactSet -Label "skill" -Expected $expectedSkills -Actual $actualSkills
    foreach ($skillName in $expectedSkills) {
        $file = Join-Path (Join-Path $skillRoot $skillName) "SKILL.md"
        if (-not (Test-Path $file)) {
            Add-Error "Missing SKILL.md: $file"
            continue
        }
        $content = Get-Content -Raw $file
        if ($content -notmatch "(?s)^---\s*\nname:\s*([^\n]+)\ndescription:\s*([^\n]+)\n---") {
            Add-Error "Invalid frontmatter: $file"
        }
        if ($content -match "argument-hint:") {
            Add-Error "Copilot argument-hint remains: $file"
        }
    }
    foreach ($skillName in $expectedSkillReadmes) {
        $readme = Join-Path (Join-Path $skillRoot $skillName) "readme.md"
        if (-not (Test-Path $readme)) { Add-Error "Missing skill readme copied from source: $readme" }
    }
}

foreach ($entry in @(
    @{ Label = "ref"; Path = (Join-Path $dreamersRoot "refs"); Expected = $expectedRefs },
    @{ Label = "template"; Path = (Join-Path $dreamersRoot "templates"); Expected = $expectedTemplates },
    @{ Label = "instruction"; Path = (Join-Path $dreamersRoot "instructions"); Expected = $expectedInstructions }
)) {
    if (-not (Test-Path $entry.Path)) {
        Add-Error "Missing $($entry.Label) directory: $($entry.Path)"
        continue
    }
    $actual = Get-ChildItem $entry.Path -File | ForEach-Object { $_.Name }
    Assert-ExactSet -Label $entry.Label -Expected $entry.Expected -Actual $actual
}

foreach ($file in @(
    (Join-Path $Root ".codex-plugin\plugin.json"),
    (Join-Path $Root ".github\catalog.json")
)) {
    if (-not (Test-Path $file)) {
        Add-Error "Missing JSON file: $file"
        continue
    }
    try { Get-Content -Raw $file | ConvertFrom-Json | Out-Null }
    catch { Add-Error "Invalid JSON: $file ($($_.Exception.Message))" }
}

$catalogPath = Join-Path $Root ".github\catalog.json"
if (Test-Path $catalogPath) {
    try {
        $catalog = Get-Content -Raw $catalogPath | ConvertFrom-Json
        $items = @($catalog.items | ForEach-Object { "$($_.type):$($_.slug)" })
        foreach ($required in @("skill:dreamers", "skill:dreamers-help")) {
            if ($required -notin $items) { Add-Error "Catalog missing item: $required" }
        }
        foreach ($retired in @("skill:dreamers-full", "skill:dreamers-research", "agent:forge", "agent:nova", "agent:sage")) {
            if ($retired -in $items) { Add-Error "Catalog retains retired item: $retired" }
        }
        foreach ($item in $catalog.items) {
            if (-not $item.path) { continue }
            if ($item.path -match "^skillsdreamers-" -or $item.path -match "^\.github/(agents|skills|dreamers|instructions)/") {
                Add-Error "Catalog path is not Codex-layout: $($item.path)"
                continue
            }
            $itemPath = Join-Path $Root ($item.path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path $itemPath)) { Add-Error "Catalog item path does not exist: $($item.path)" }
        }
        foreach ($collection in $catalog.collections) {
            if (-not $collection.readmePath) { continue }
            $readmePath = Join-Path $Root ($collection.readmePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path $readmePath)) { Add-Error "Catalog readmePath does not exist: $($collection.readmePath)" }
            $members = @($collection.members | ForEach-Object { "$($_.type):$($_.slug)" })
            foreach ($required in @("skill:dreamers", "skill:dreamers-help")) {
                if ($required -notin $members) { Add-Error "Collection missing member: $required" }
            }
            foreach ($retired in @("skill:dreamers-full", "skill:dreamers-research", "agent:forge", "agent:nova", "agent:sage")) {
                if ($retired -in $members) { Add-Error "Collection retains retired member: $retired" }
            }
        }
        foreach ($folder in $catalog.folderTargets) {
            if ($folder.sourcePath -match "^\.github/(agents|skills|dreamers|instructions)") {
                Add-Error "Catalog folder sourcePath is not Codex-layout: $($folder.sourcePath)"
                continue
            }
            $sourcePath = Join-Path $Root ($folder.sourcePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path $sourcePath)) { Add-Error "Catalog folder sourcePath does not exist: $($folder.sourcePath)" }
        }
    }
    catch {
        Add-Error "Unable to validate catalog paths: $($_.Exception.Message)"
    }
}

Assert-Patterns (Join-Path $skillRoot "dreamers/SKILL.md") @{
    "help route before inspection" = '(?ms)Empty input.*`help`.*`--help`.*`-h`.*dreamers-help.*stop before inspecting'
    "artifact authorization" = '(?ms)Supplied artifacts are implementation authorization.*do not re-plan.*ask to start'
    "task planning and start gate" = '(?ms)Phase 1:.*Invoke `dreamers-plan.*Approved — start implementation.*start INCREMENTAL.*start ATOMIC'
    "implementation then selected review" = '(?ms)### Implement and review.*dreamers-implement.*dreamers-review --branch'
    "capped Vigil fixes" = '(?ms)dreamers-review --vigil --branch.*up to 3 times.*Ask before major refactors.*defered\.md'
    "blocked or unresolved review stops" = '(?ms)Halt.*blocked review or unresolved findings at the cap'
    "triggered user testing" = '(?ms)### User testing.*manual verification.*user-testing-gate.*staged \+ unstaged.*review cap'
    "ship strategies" = '(?ms)ATOMIC.*commit.*do not push.*INCREMENTAL.*dreamers-docs --branch.*confirm merge'
    "close-out order" = '(?ms)Phase 3.*dreamers-docs --branch.*commit remaining changes.*Approved.*dreamers-pr'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-help/SKILL.md") @{
    "Codex runtime preamble" = '## Codex runtime.*codex-runtime\.md.*user''s message as skill input'
    "read-only boundary" = '## Boundary.*read-only guidance.*Do not inspect or change'
    "primary examples" = 'dreamers add offline export.*dreamers feature-search/plan-01-indexing\.md.*dreamers feature-search/manifest\.md'
    "review lanes" = 'lite plans use Vigil.*standard plans use Sentinel \+ Probe.*complex plans use Sentinel \+ Probe \+ Hone'
    "specialized choices" = 'dreamers-plan.* dreamers-implement.* dreamers-review.* dreamers-lite'
    "mandatory gates" = 'plan approval.*major scope expansion.*triggered user testing.*final pre-PR approval'
    "invitation" = 'Describe your goal and I can suggest the next command'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-pr-resolve/SKILL.md") @{
    "deferred Vigil findings ledger" = '(?s)Defer — save to defered\.md.*do NOT apply.*create a follow-up plan.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`'
    "deferred ledger commit" = 'If any fixes landed or Step 5 added deferred entries'
    "deferred ledger report" = 'Deferred Vigil findings recorded in `defered\.md`'
}
Assert-NoPatterns (Join-Path $skillRoot "dreamers/SKILL.md") @{
    "retired pipeline name" = 'dreamers-full'
    "Grill opt-out" = '--no-grill|do not grill|skip the interview'
    "inline implementation refs" = '<(?:planning-grill|testing-mandate|comment-rules|logging-discipline|reviewer-findings-format|agent-recovery)>'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-implement/SKILL.md") @{
    "task or plan implementation" = '(?ms)Implement the task or approved plan.*stated requirements as acceptance criteria; no plan file is needed'
    "bounded validation" = '(?ms)Type-check \+ run tests.*max 3 attempts.*halt'
    "green coverage handoff" = '(?ms)Return requirement/AC coverage and validation results at green tests'
    "optional standalone progress" = '(?ms)When standalone, a todo is optional.*outer delivery skill.*existing todo'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-review/SKILL.md") @{
    "Vigil mode" = '(?s)--vigil.*Vigil|Vigil.*--vigil'
    "full mode" = '(?s)--full.*Sentinel \+ Probe \+ Hone'
    "selection precedence" = '(?s)explicit lane flag or explicit user direction.*explicit reviewer requirement.*Plan-type'
    "lite selection" = 'lite` = Vigil'
    "standard selection" = 'standard` = Sentinel \+ Probe'
    "complex selection" = 'complex` = Sentinel \+ Probe \+ Hone'
    "planless intent inference" = "infer the intended behavior.*explicit user direction.*PR title/body.*commits and diff.*changed tests.*changed code"
    "planless ambiguity question" = "one reliable interpretation.*ask the user one concise question"
    "planless reviewer basis" = "review basis.*absolute plan path.*inferred-intent summary"
    "Grill transcript resolution" = 'Grilling transcript:.*sibling `grilling-transcript\.md`.*read it in full'
    "Grill transcript reviewer context" = "absolute path and full verbatim contents.*plan/transcript conflict"
    "parallel spawning" = '(?s)launch every selected reviewer concurrently.*Never spawn or await reviewers sequentially'
    "caller owns fix loop" = 'caller owns all finding disposition, gates, fixes, revalidation, and user testing'
    "artifact-only reviewer writes" = '(?s)sole write is exactly one.*artifact'
}
Assert-Patterns (Join-Path $dreamersRoot "refs/planning-grill.md") @{
    "explore before asking" = '(?ms)Explore the codebase for answers before asking the user'
    "single blocking question" = '(?ms)one blocking question at a time'
    "verbatim transcript" = '(?ms)every question and response verbatim.*complete tool questions, choice labels, and descriptions.*never summarize, paraphrase, normalize, or omit'
    "transcript storage" = '(?ms)\.dreamers/plans/feature-<slug>/grilling-transcript\.md.*Do not create an empty transcript'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-plan/SKILL.md") @{
    "planning write boundary" = '(?ms)write only `\.dreamers/plans/` artifacts; do not change project files or git state'
    "proposal before writing" = '(?ms)Propose to user.*until approved.*Write plan'
    "review gate" = '(?ms)Review gate.*Approved.*Minor edit.*Major rewrite.*Halt'
}
Assert-Patterns (Join-Path $agentRoot "vigil.toml") @{
    "planless Vigil review basis" = "If no plan is bound.*inferred-intent summary.*evidence"
    "planless Vigil requirements" = "plan AC or inferred requirement"
}
Assert-Patterns (Join-Path $agentRoot "probe.toml") @{
    "planless Probe review basis" = "no plan is bound.*inferred requirements"
    "planless Probe findings" = "report missing or weak coverage as findings"
}
Assert-Patterns (Join-Path $skillRoot "dreamers-new-project/SKILL.md") @{
    "existing-solutions opt-in gate" = '(?s)Phase 1\.5.*ask the user.*Research similar existing solutions.*Skip research'
    "research blocked before approval" = 'Do not perform research before the user explicitly approves it'
    "research remains conversation-only" = 'Keep this phase conversation-only: no subagent and no disk writes'
    "research informs downstream artifacts" = '(?s)existing-solutions research.*stack recommendation.*project brief'
}
Assert-Patterns (Join-Path $dreamersRoot "instructions/dreamers.instructions.md") @{
    "same-context composition" = '(?ms)skill.*same orchestrator context'
    "outermost progress ownership" = '(?ms)outermost skill.*owns.*todo'
    "durable delivery state" = '(?ms)Delivery continuation.*goal, owning skill, branch/PR, next phase, and review count.*confirmed outcomes'
    "follow-ups preserve caps" = '(?ms)resume the pending phase.*detours do not reset an active review count'
    "open PR corrections" = '(?ms)open PR, reuse its branch.*dreamers-review --vigil.*staged \+ unstaged.*dreamers-docs --staged.*approval for the current changes before committing and pushing.*Reuse approval already given'
    "global deferred ledger" = '(?ms)explicitly chooses `Defer`.*defered\.md.*never overwrite existing entries'
}
Assert-Patterns (Join-Path $dreamersRoot "refs/codex-runtime.md") @{
    "same-context composition" = 'invoke it in the same orchestrator context'
    "parallel reviewer runtime" = '(?s)launch every selected reviewer concurrently.*Never spawn and await reviewers sequentially'
}
Assert-NoPatterns (Join-Path $skillRoot "dreamers-update/SKILL.md") @{
    "implementation mirror rule" = 'dreamers-implement mirror'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-explain/SKILL.md") @{
    "Codex runtime preamble" = '(?s)## Codex runtime.*codex-runtime\.md.*user''s message as skill input'
    "read-only boundary" = '(?s)Default to read-only work.*do not modify the subject'
    "conditional source retrieval" = '(?s)Search or retrieve external sources when:.*facts may have changed.*niche, disputed, uncertain, or high-stakes'
    "source priority" = '(?s)Source priority:.*repository evidence.*First-party documentation.*High-quality secondary sources'
    "layered explanation" = '(?s)Direct answer.*Orientation.*Mental model.*Mechanics.*Concrete example.*Edges and alternatives.*Takeaway'
    "optional comprehension" = 'Do not force a quiz or Socratic exchange'
}
Assert-Patterns (Join-Path $Root ".codex-plugin/plugin.json") @{
    "unified default prompt" = 'Use dreamers to plan and ship'
}

Assert-Patterns (Join-Path $skillRoot "dreamers-lite/SKILL.md") @{
    "direct task implementation" = '(?ms)dreamers-implement <task description and agreed scope>'
    "capped Vigil fixes" = '(?ms)dreamers-review --vigil --branch.*up to 2 times.*Ask before major refactors.*defered\.md'
    "blocked or unresolved review stops" = '(?ms)Halt on a blocked review or unresolved findings at the cap'
    "uncommitted docs before commit" = '(?ms)Phase 3.*dreamers-docs --staged.*commit remaining changes.*Approved.*dreamers-pr'
    "continuation routing" = '(?ms)Delivery continuation.*resume the pending phase'
}

Assert-Patterns (Join-Path $dreamersRoot "refs/plan-format.md") @{
    "unified plan body" = '(?ms)## Goal.*## Scope and context.*## Acceptance Criteria'
    "complexity metadata" = '(?ms)Plan-type:.*lite\|standard\|complex'
    "optional transcript link" = '(?ms)Grilling transcript:.*grilling-transcript\.md.*Include the transcript link only when the sibling artifact exists'
    "checks with ACs" = '(?ms)Under the relevant AC, add a test command or check.*manual checks.*steps, expected result.*User-testing-required: yes'
    "useful visuals" = '(?ms)Mermaid diagrams.*UI layouts/wireframes'
}

$scanRoots = @("agents", "skills", "dreamers", "README.md", "Install-DreamersCodex.ps1", "Remove-DreamersCodex.ps1", ".github/catalog.json") |
    ForEach-Object { Join-Path $Root $_ } |
    Where-Object { Test-Path $_ }
$scanFiles = foreach ($path in $scanRoots) {
    if ((Get-Item $path).PSIsContainer) {
        Get-ChildItem $path -File -Recurse | Where-Object { $_.Extension -in @(".md", ".toml", ".ps1", ".json") }
    } else {
        Get-Item $path
    }
}

$stalePatterns = @(
    "Atlas",
    "WebSearch",
    "WebFetch",
    "C:\\Users\\cjsto\\.Codex",
    "~/.Codex",
    "\.github/agents/",
    "\.github/skills/",
    "\.github/dreamers/",
    "dreamers/agents/<role>",
    "dreamers/agents/sentinel",
    "dreamers/agents/probe",
    "dreamers/agents/hone",
    "manage_todo_list",
    "request_information",
    "task\(",
    'mode:\s*["'']?sync'
)

foreach ($file in $scanFiles) {
    $rel = Get-RelativePath $file.FullName
    if ($rel -eq "dreamers/refs/codex-runtime.md") { continue }
    if ($rel -eq "skills/dreamers-update/SKILL.md") { continue }
    $content = Get-Content -Raw $file.FullName
    foreach ($pattern in $stalePatterns) {
        if ($content -cmatch $pattern) {
            Add-Error "Stale Copilot/legacy token '$pattern' remains in $rel"
        }
    }
}

$legacyPattern = "dreamers-full|dreamers-research|\b(?:forge|nova|sage)\b|plan-quality|plan-selection|plan-guide-(?:selector|lite|standard|complex)|hone-architecture-rubric"
$migrationPattern = "retir|remov|legacy|migrat|cleanup|clean up|previous|old command|no longer"
$legacyScanRoots = @("agents", "skills", "dreamers", "README.md", ".github/catalog.json", ".codex-plugin/plugin.json") |
    ForEach-Object { Join-Path $Root $_ } |
    Where-Object { Test-Path $_ }
foreach ($scanRoot in $legacyScanRoots) {
    $files = if ((Get-Item $scanRoot).PSIsContainer) {
        Get-ChildItem $scanRoot -File -Recurse
    } else {
        Get-Item $scanRoot
    }
    foreach ($file in $files) {
        $lineNumber = 0
        foreach ($line in Get-Content $file.FullName) {
            $lineNumber++
            if ($line -match $legacyPattern -and $line -notmatch $migrationPattern) {
                Add-Error "Active retired-pipeline reference in $($file.FullName):$lineNumber"
            }
        }
    }
}

if (-not $SkipInstallSmoke) {
    $retiredFiles = @(
        "agents/bolt.toml",
        "agents/forge.toml",
        "agents/nova.toml",
        "agents/sage.toml",
        "dreamers/agents/echo.md",
        "dreamers/agents/forge.md",
        "dreamers/agents/hone.md",
        "dreamers/agents/nova.md",
        "dreamers/agents/probe.md",
        "dreamers/agents/sage.md",
        "dreamers/agents/sentinel.md",
        "skills/dreamers-full/SKILL.md",
        "skills/dreamers-full/readme.md",
        "skills/dreamers-research/SKILL.md",
        "skills/dreamers-research/readme.md",
        "dreamers/refs/hone-architecture-rubric.md",
        "dreamers/refs/plan-quality.md",
        "dreamers/refs/plan-selection.md",
        "dreamers/templates/plan-guide-selector.md",
        "dreamers/templates/plan-guide-lite.md",
        "dreamers/templates/plan-guide-standard.md",
        "dreamers/templates/plan-guide-complex.md",
        "dreamers/templates/plan-writing-guide.md",
        "dreamers/instructions/comment-rules.instructions.md",
        "dreamers/instructions/git.instructions.md"
    )
    $userFiles = @(
        "agents/user-owned.toml",
        "dreamers/agents/user-owned.md",
        "dreamers/refs/user-owned.md",
        "dreamers/templates/user-owned.md",
        "dreamers/instructions/user-owned.md",
        "skills/dreamers-lite/user-owned.md",
        "skills/dreamers-research/.user-owned.md"
    )
    $managedFiles = @("agents", "skills", "dreamers") | ForEach-Object {
        Get-ChildItem (Join-Path $Root $_) -File -Recurse | ForEach-Object { Get-RelativePath $_.FullName }
    }
    $tmpBase = Join-Path $Root ".tmp"
    New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null
    foreach ($forceInstall in @($false, $true)) {
        $tmpHome = Join-Path $tmpBase ("dreamers-codex-test-" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        try {
            foreach ($rel in ($retiredFiles + $userFiles)) {
                $path = Join-Path $tmpHome $rel
                New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
                Set-Content -Path $path -Value "preserve fixture" -NoNewline -Encoding utf8NoBOM
            }
            $existingSkill = "skills/dreamers-lite/SKILL.md"
            Set-Content -Path (Join-Path $tmpHome $existingSkill) -Value "existing active skill" -NoNewline -Encoding utf8NoBOM
            & (Join-Path $Root "Install-DreamersCodex.ps1") -CodexHome $tmpHome -Force:$forceInstall | Out-Null

            foreach ($rel in $retiredFiles) {
                if (Test-Path (Join-Path $tmpHome $rel)) { Add-Error "Install (force=$forceInstall) retained retired managed file: $rel" }
            }
            foreach ($rel in $userFiles) {
                $path = Join-Path $tmpHome $rel
                if (-not (Test-Path $path) -or (Get-Content -Raw $path) -cne "preserve fixture") {
                    Add-Error "Install (force=$forceInstall) changed user-owned file: $rel"
                }
            }
            foreach ($rel in $managedFiles) {
                $installed = Join-Path $tmpHome $rel
                $expected = Get-Content -Raw (Join-Path $Root $rel)
                if ($rel -eq $existingSkill -and -not $forceInstall) { $expected = "existing active skill" }
                if (-not (Test-Path $installed) -or (Get-Content -Raw $installed) -cne $expected) {
                    Add-Error "Install (force=$forceInstall) has incorrect managed file: $rel"
                }
            }
            if (Test-Path (Join-Path $tmpHome "skills/dreamers-full")) { Add-Error "Install did not prune empty retired skill directory" }

            foreach ($rel in $retiredFiles) {
                $path = Join-Path $tmpHome $rel
                New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
                Set-Content -Path $path -Value "retired fixture" -NoNewline -Encoding utf8NoBOM
            }
            $beforeDryRun = @{}
            Get-ChildItem $tmpHome -File -Recurse -Force | ForEach-Object {
                $beforeDryRun[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash
            }
            & (Join-Path $Root "Remove-DreamersCodex.ps1") -CodexHome $tmpHome -DryRun | Out-Null
            foreach ($path in $beforeDryRun.Keys) {
                if (-not (Test-Path $path) -or (Get-FileHash -LiteralPath $path).Hash -ne $beforeDryRun[$path]) {
                    Add-Error "Removal dry run changed file: $path"
                }
            }

            & (Join-Path $Root "Remove-DreamersCodex.ps1") -CodexHome $tmpHome | Out-Null
            foreach ($rel in ($managedFiles + $retiredFiles)) {
                if (Test-Path (Join-Path $tmpHome $rel)) { Add-Error "Removal retained managed file: $rel" }
            }
            foreach ($rel in $userFiles) {
                $path = Join-Path $tmpHome $rel
                if (-not (Test-Path $path) -or (Get-Content -Raw $path) -cne "preserve fixture") {
                    Add-Error "Removal changed user-owned file: $rel"
                }
            }
            if (Test-Path (Join-Path $tmpHome "skills/dreamers-full")) { Add-Error "Removal did not prune empty retired skill directory" }
        }
        finally {
            if (Test-Path $tmpHome) { Remove-Item -LiteralPath $tmpHome -Recurse -Force }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Dreamers Codex validation passed." -ForegroundColor Green
