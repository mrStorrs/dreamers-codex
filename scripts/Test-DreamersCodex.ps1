[CmdletBinding()]
param(
    [string]$Root = $(if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Get-Location }),
    [switch]$SkipInstallSmoke
)

$ErrorActionPreference = "Stop"
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
        if ($content -notmatch $entry.Value) {
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
        if ($content -match $entry.Value) {
            Add-Error "Unexpected $($entry.Key) contract in $Path"
        }
    }
}

$expectedAgents = @("echo", "forge", "hone", "nova", "probe", "sage", "sentinel", "vigil")
$expectedSkills = @(
    "dreamers",
    "dreamers-add-logging",
    "dreamers-clean-work",
    "dreamers-cleanup-comments",
    "dreamers-cleanup-comments-branch",
    "dreamers-docs",
    "dreamers-explain",
    "dreamers-help",
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
    "dreamers-update"
)
$expectedRefs = @(
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
    "testing-mandate.md"
)
$expectedTemplates = @(
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
    "dreamers-lite",
    "dreamers-find-refactors",
    "dreamers-implement",
    "dreamers-new-project",
    "dreamers-plan",
    "dreamers-pr-resolve",
    "dreamers-research",
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
        foreach ($retired in @("skill:dreamers-full")) {
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
            foreach ($retired in @("skill:dreamers-full")) {
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
    "help route" = '## Route input.*Empty or whitespace-only input.*`help`.*`--help`.*`-h`.*invoke `dreamers-help`.*read-only'
    "unrecognized-input halt" = 'Otherwise halt and ask for a task, plan path, manifest, or help'
    "three input modes" = '(?s)## Modes.*Task description.*Plan path\(s\).*manifest\.md'
    "planning delegation" = '(?s)## Phase 1.*Invoke `dreamers-plan`'
    "implementation then review" = '(?s)### Steps 1.3.*Invoke `dreamers-implement.*### Step 4.*Invoke `dreamers-review'
    "complexity-selected review" = 'selects Vigil, Sentinel \+ Probe, or Sentinel \+ Probe \+ Hone from plan complexity or explicit plan/user direction'
    "major-refactor gate" = '(?s)Major-refactor gate.*Apply now.*Defer — save to defered\.md.*Other'
    "deferred findings ledger" = '(?s)Defer.*do NOT apply or create a follow-up plan.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`'
    "major-change rerun gate" = '(?s)Run Vigil.*Run full triad.*Run selected dreamers-review lane.*Skip reviewer rerun.*Other'
    "templated user testing" = '(?s)user-testing-gate\.md.*Testing steps.*Notes.*Approved.*Bug found \(enter text\).*Other \(enter text\)'
    "full close-out" = '(?s)Phase 3.*improvements\.md.*dreamers-docs --branch.*Write retro.*Final commit.*User approval gate.*dreamers-pr'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-help/SKILL.md") @{
    "Codex runtime preamble" = '## Codex runtime.*codex-runtime\.md.*Skill input: use the user''s message'
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
    "retired pipeline name" = 'dreamers-(?:full|lite)'
    "Grill opt-out" = '--no-grill|do not grill|skip the interview'
    "inline implementation refs" = '<(?:planning-grill|testing-mandate|comment-rules|logging-discipline|reviewer-findings-format|agent-recovery)>'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-implement/SKILL.md") @{
    "tests-first implementation" = '(?s)failing tests.*implement|tests.first'
    "green exit" = '(?s)Return the AC coverage matrix at green tests.*invokes `dreamers-review` immediately'
    "phase boundary" = '(?s)Do not invoke reviewers.*user testing.*commit.*push.*PR creation'
    "conditional plan ownership" = '(?s)When standalone.*update_plan.*When invoked by an outer delivery skill.*existing plan'
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
    "verbatim transcript" = "every planner.*question and every user response.*exactly as sent or.*received.*Do not summarize"
    "structured question detail" = "request_user_input.*complete presented question.*choice labels.*choice descriptions"
    "transcript path" = "\.dreamers/plans/feature-<slug>/grilling-transcript\.md"
}
Assert-Patterns (Join-Path $skillRoot "dreamers-plan/SKILL.md") @{
    "verbatim transcript write" = 'write `grilling-transcript\.md`.*Preserve every question and response word for word'
    "plan transcript link" = 'each plan MUST include `\*\*Grilling transcript:\*\* \[grilling-transcript\.md\]\(\./grilling-transcript\.md\)`'
}
foreach ($guideName in @("plan-guide-lite.md", "plan-guide-standard.md", "plan-guide-complex.md")) {
    Assert-Patterns (Join-Path $dreamersRoot "templates/$guideName") @{
        "optional Grill transcript metadata" = "\*\*Grilling transcript:\*\*.*grilling-transcript\.md.*when the sibling artifact exists"
    }
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
    "same-context skill invocation" = '(?s)skill.*same orchestrator context|same orchestrator context.*skill'
    "outermost plan ownership" = '(?s)outermost skill.*owns.*(?:todo|plan)|(?:todo|plan).*owned by.*outermost skill'
    "global deferred suggestions ledger" = '(?s)Deferred suggestions.*explicitly chooses `Defer`.*defered\.md.*# Deferred Suggestions.*never overwrite.*Stage `defered\.md`'
}
Assert-Patterns (Join-Path $dreamersRoot "refs/codex-runtime.md") @{
    "same-context composition" = 'invoke it in the same orchestrator context'
    "parallel reviewer runtime" = '(?s)launch every selected reviewer concurrently.*Never spawn and await reviewers sequentially'
}
Assert-NoPatterns (Join-Path $skillRoot "dreamers-update/SKILL.md") @{
    "implementation mirror rule" = 'dreamers-implement mirror'
}
Assert-Patterns (Join-Path $skillRoot "dreamers-explain/SKILL.md") @{
    "Codex runtime preamble" = '(?s)## Codex runtime.*codex-runtime\.md.*Skill input: use the user''s message'
    "read-only boundary" = '(?s)Default to read-only work.*do not modify the subject'
    "focused research boundary" = '(?s)Use `dreamers-research` instead.*durable, multi-perspective research report'
    "conditional source retrieval" = '(?s)Search or retrieve external sources when:.*facts may have changed.*niche, disputed, uncertain, or high-stakes'
    "source priority" = '(?s)Source priority:.*repository evidence.*First-party documentation.*High-quality secondary sources'
    "layered explanation" = '(?s)Direct answer.*Orientation.*Mental model.*Mechanics.*Concrete example.*Edges and alternatives.*Takeaway'
    "optional comprehension" = 'Do not force a quiz or Socratic exchange'
}
Assert-Patterns (Join-Path $Root ".codex-plugin/plugin.json") @{
    "unified default prompt" = 'Use dreamers to plan and ship'
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
    "task\("
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

$legacyPattern = "dreamers-full"
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
    $tmpBase = Join-Path $Root ".tmp"
    New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null
    $tmpHome = Join-Path $tmpBase ("dreamers-codex-test-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
    try {
        $userRef = Join-Path $tmpHome "dreamers\refs\user-owned.md"
        $userSkill = Join-Path $tmpHome "skills\dreamers-plan\user-owned.md"
        $userInstruction = Join-Path $tmpHome "dreamers\instructions\user-owned.md"
        $legacyAgent = Join-Path $tmpHome "dreamers\agents\echo.md"
        $legacyUser = Join-Path $tmpHome "dreamers\agents\user-owned.md"
        $legacyBolt = Join-Path $tmpHome "agents\bolt.toml"
        $staleCommentRules = Join-Path $tmpHome "dreamers\instructions\comment-rules.instructions.md"
        $staleGitInstructions = Join-Path $tmpHome "dreamers\instructions\git.instructions.md"
        $stalePlanGuide = Join-Path $tmpHome "dreamers\templates\plan-writing-guide.md"
        foreach ($path in @($userRef, $userSkill, $userInstruction, $legacyAgent, $legacyUser, $legacyBolt, $staleCommentRules, $staleGitInstructions, $stalePlanGuide)) {
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -Path $path -Value "user-owned" -Encoding utf8NoBOM
        }
        $activeLite = Join-Path $tmpHome "skills\dreamers-lite"
        $legacyFull = Join-Path $tmpHome "skills\dreamers-full"
        foreach ($directory in @($activeLite, $legacyFull)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Set-Content -Path (Join-Path $directory "SKILL.md") -Value "managed" -Encoding utf8NoBOM
            Set-Content -Path (Join-Path $directory "readme.md") -Value "managed" -Encoding utf8NoBOM
        }
        Set-Content -Path (Join-Path $activeLite "user-owned.md") -Value "preserve" -Encoding utf8NoBOM

        & (Join-Path $Root "Install-DreamersCodex.ps1") -CodexHome $tmpHome -Force | Out-Null

        foreach ($path in @($userRef, $userSkill, $userInstruction, $legacyUser)) {
            if (-not (Test-Path $path)) { Add-Error "Install smoke removed user-owned file: $path" }
        }
        if (Test-Path $legacyAgent) { Add-Error "Install smoke did not remove legacy agent file: $legacyAgent" }
        if (Test-Path $legacyBolt) { Add-Error "Install smoke did not remove legacy bolt agent: $legacyBolt" }
        if (Test-Path $staleCommentRules) { Add-Error "Install smoke did not remove obsolete managed file: $staleCommentRules" }
        if (Test-Path $staleGitInstructions) { Add-Error "Install smoke did not remove obsolete managed file: $staleGitInstructions" }
        if (Test-Path $stalePlanGuide) { Add-Error "Install smoke did not remove obsolete managed file: $stalePlanGuide" }
        if (Test-Path (Join-Path $tmpHome "dreamers\refs\refs")) { Add-Error "Install smoke created nested refs directory" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers-pr-resolve\dreamers-pr-resolve")) { Add-Error "Install smoke created nested skill directory" }
        if (-not (Test-Path (Join-Path $tmpHome "agents\sentinel.toml"))) { Add-Error "Install smoke did not install agent TOMLs" }
        if (Test-Path (Join-Path $tmpHome "agents\bolt.toml")) { Add-Error "Install smoke installed non-authoritative bolt agent" }
        if (-not (Test-Path (Join-Path $tmpHome "skills\dreamers\SKILL.md"))) { Add-Error "Install smoke did not install exact dreamers skill" }
        if (-not (Test-Path (Join-Path $tmpHome "skills\dreamers-help\SKILL.md"))) { Add-Error "Install smoke did not install dreamers-help skill" }
        foreach ($managed in @("SKILL.md", "readme.md")) {
            $path = Join-Path $activeLite $managed
            if (-not (Test-Path $path)) { Add-Error "Install smoke did not install active dreamers-lite file: $path" }
        }
        if ((Get-Content -Raw (Join-Path $activeLite "SKILL.md")) -notmatch "name: dreamers-lite") {
            Add-Error "Install smoke did not replace the active dreamers-lite skill"
        }
        foreach ($path in @(
            (Join-Path $tmpHome "dreamers\instructions\dreamers.comment-rules.instructions.md"),
            (Join-Path $tmpHome "dreamers\instructions\dreamers.laws.md")
        )) {
            if (-not (Test-Path $path)) { Add-Error "Install smoke missing managed instruction: $path" }
        }
        foreach ($managed in @("SKILL.md", "readme.md")) {
            $path = Join-Path $legacyFull $managed
            if (Test-Path $path) { Add-Error "Install smoke retained legacy managed file: $path" }
        }
        if (-not (Test-Path (Join-Path $activeLite "user-owned.md"))) { Add-Error "Install smoke removed user-owned active file: $activeLite" }
        if (Test-Path $legacyFull) { Add-Error "Install smoke did not prune empty legacy directory: $legacyFull" }

        New-Item -ItemType Directory -Path $legacyFull -Force | Out-Null
        Set-Content -Path (Join-Path $legacyFull "SKILL.md") -Value "managed" -Encoding utf8NoBOM
        Set-Content -Path (Join-Path $legacyFull "readme.md") -Value "managed" -Encoding utf8NoBOM
        Set-Content -Path $staleCommentRules -Value "obsolete managed file" -Encoding utf8NoBOM
        Set-Content -Path $staleGitInstructions -Value "obsolete managed file" -Encoding utf8NoBOM
        Set-Content -Path $stalePlanGuide -Value "obsolete managed file" -Encoding utf8NoBOM

        & (Join-Path $Root "Remove-DreamersCodex.ps1") -CodexHome $tmpHome | Out-Null

        foreach ($path in @($userRef, $userSkill, $userInstruction, $legacyUser)) {
            if (-not (Test-Path $path)) { Add-Error "Remove smoke removed user-owned file: $path" }
        }
        if (Test-Path (Join-Path $tmpHome "agents\sentinel.toml")) { Add-Error "Remove smoke left managed agent file behind" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers-plan\SKILL.md")) { Add-Error "Remove smoke left managed skill file behind" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers\SKILL.md")) { Add-Error "Remove smoke left exact dreamers skill behind" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers-help\SKILL.md")) { Add-Error "Remove smoke left dreamers-help skill behind" }
        foreach ($path in @(
            (Join-Path $tmpHome "dreamers\instructions\dreamers.comment-rules.instructions.md"),
            (Join-Path $tmpHome "dreamers\instructions\dreamers.laws.md")
        )) {
            if (Test-Path $path) { Add-Error "Remove smoke left managed instruction behind: $path" }
        }
        if (Test-Path $staleCommentRules) { Add-Error "Remove smoke left obsolete managed file behind: $staleCommentRules" }
        if (Test-Path $staleGitInstructions) { Add-Error "Remove smoke left obsolete managed file behind: $staleGitInstructions" }
        if (Test-Path $stalePlanGuide) { Add-Error "Remove smoke left obsolete managed file behind: $stalePlanGuide" }
        if (-not (Test-Path (Join-Path $activeLite "user-owned.md"))) { Add-Error "Remove smoke removed user-owned active file: $activeLite" }
        if (Test-Path $legacyFull) { Add-Error "Remove smoke did not prune empty legacy directory: $legacyFull" }
    }
    finally {
        if (Test-Path $tmpHome) { Remove-Item -LiteralPath $tmpHome -Recurse -Force }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Dreamers Codex validation passed." -ForegroundColor Green
