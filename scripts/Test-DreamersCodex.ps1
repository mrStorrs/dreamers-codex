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

$expectedAgents = @("echo", "forge", "hone", "nova", "probe", "sage", "sentinel")
$expectedSkills = @(
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
    "dreamers-update"
)
$expectedRefs = @(
    "agent-recovery.md",
    "codex-runtime.md",
    "comment-rules.md",
    "dreamers-kernel.md",
    "git-workflow.md",
    "logging-discipline.md",
    "project-bootstrap.md",
    "reviewer-findings-format.md",
    "testing-mandate.md"
)
$expectedTemplates = @(
    "discovery-questions.md",
    "github-issue.md",
    "logging-standards.md",
    "manifest.md",
    "plan-writing-guide.md",
    "plan.md",
    "pr-description.md",
    "project-brief.md",
    "shell-plan.md",
    "test-benchmarks.md"
)
$expectedInstructions = @(
    "comment-rules.instructions.md",
    "dreamers.instructions.md",
    "git.instructions.md"
)
$expectedSkillReadmes = @(
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
        if ($content -notmatch "(?m)^name\s*=\s*`"$name`"\s*$") {
            Add-Error "Agent name does not match basename: $file"
        }
        if ($content -notmatch "(?m)^description\s*=\s*`".+`"\s*$") {
            Add-Error "Agent missing non-empty description: $file"
        }
        if ($content -notmatch "(?s)developer_instructions\s*=\s*'''(.+)'''") {
            Add-Error "Agent missing developer_instructions literal block: $file"
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

if (-not $SkipInstallSmoke) {
    $tmpBase = Join-Path $Root ".tmp"
    New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null
    $tmpHome = Join-Path $tmpBase ("dreamers-codex-test-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
    try {
        $userRef = Join-Path $tmpHome "dreamers\refs\user-owned.md"
        $userSkill = Join-Path $tmpHome "skills\dreamers-plan\user-owned.md"
        $legacyAgent = Join-Path $tmpHome "dreamers\agents\echo.md"
        $legacyUser = Join-Path $tmpHome "dreamers\agents\user-owned.md"
        $legacyBolt = Join-Path $tmpHome "agents\bolt.toml"
        foreach ($path in @($userRef, $userSkill, $legacyAgent, $legacyUser, $legacyBolt)) {
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -Path $path -Value "user-owned" -Encoding utf8NoBOM
        }

        & (Join-Path $Root "Install-DreamersCodex.ps1") -CodexHome $tmpHome -Force | Out-Null

        foreach ($path in @($userRef, $userSkill, $legacyUser)) {
            if (-not (Test-Path $path)) { Add-Error "Install smoke removed user-owned file: $path" }
        }
        if (Test-Path $legacyAgent) { Add-Error "Install smoke did not remove legacy agent file: $legacyAgent" }
        if (Test-Path $legacyBolt) { Add-Error "Install smoke did not remove legacy bolt agent: $legacyBolt" }
        if (Test-Path (Join-Path $tmpHome "dreamers\refs\refs")) { Add-Error "Install smoke created nested refs directory" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers-pr-resolve\dreamers-pr-resolve")) { Add-Error "Install smoke created nested skill directory" }
        if (-not (Test-Path (Join-Path $tmpHome "agents\sentinel.toml"))) { Add-Error "Install smoke did not install agent TOMLs" }
        if (Test-Path (Join-Path $tmpHome "agents\bolt.toml")) { Add-Error "Install smoke installed non-authoritative bolt agent" }

        & (Join-Path $Root "Remove-DreamersCodex.ps1") -CodexHome $tmpHome | Out-Null

        foreach ($path in @($userRef, $userSkill, $legacyUser)) {
            if (-not (Test-Path $path)) { Add-Error "Remove smoke removed user-owned file: $path" }
        }
        if (Test-Path (Join-Path $tmpHome "agents\sentinel.toml")) { Add-Error "Remove smoke left managed agent file behind" }
        if (Test-Path (Join-Path $tmpHome "skills\dreamers-plan\SKILL.md")) { Add-Error "Remove smoke left managed skill file behind" }
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
