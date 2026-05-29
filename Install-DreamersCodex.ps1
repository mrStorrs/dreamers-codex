<#
.SYNOPSIS
    Installs Dreamers Codex-managed files into the user's Codex home.

.DESCRIPTION
    Copies agents, skills, shared Dreamers resources, and instructions from
    this package into $env:CODEX_HOME, or ~/.codex when CODEX_HOME is not set.

    Only manages Dreamers-owned files. Does not remove user files from shared
    Codex directories.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

$legacyAgentNames = @("echo", "forge", "hone", "nova", "probe", "sage", "sentinel")
$legacyAgentTomlNames = @("bolt")

function Copy-DreamersFiles {
    param(
        [string]$From,
        [string]$To,
        [string]$Label
    )
    if (-not (Test-Path $From)) {
        Write-Warning "Source not found, skipping: $From"
        return 0
    }
    if (-not (Test-Path $To)) {
        New-Item -ItemType Directory -Path $To -Force | Out-Null
    }

    $count = 0
    foreach ($file in Get-ChildItem $From -File) {
        $dest = Join-Path $To $file.Name
        if ((Test-Path $dest) -and -not $Force) {
            Write-Host "  SKIP (exists): $Label/$($file.Name) - use -Force to overwrite" -ForegroundColor Yellow
            continue
        }
        Copy-Item -Path $file.FullName -Destination $dest -Force
        Write-Host "  OK: $Label/$($file.Name)" -ForegroundColor Green
        $count++
    }
    return $count
}

function Remove-LegacyAgentFiles {
    param(
        [string]$TargetDir
    )
    if (-not (Test-Path $TargetDir)) { return 0 }

    $count = 0
    foreach ($name in $legacyAgentNames) {
        $target = Join-Path $TargetDir "$name.md"
        if (-not (Test-Path $target)) { continue }
        Remove-Item -LiteralPath $target -Force
        Write-Host "  REMOVED legacy: dreamers/agents/$name.md" -ForegroundColor DarkGray
        $count++
    }

    $remaining = Get-ChildItem $TargetDir -Force
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $TargetDir -Force
        Write-Host "  REMOVED empty legacy dir: dreamers/agents" -ForegroundColor DarkGray
    }
    return $count
}

function Remove-LegacyAgentTomls {
    param(
        [string]$TargetDir
    )
    if (-not (Test-Path $TargetDir)) { return 0 }

    $count = 0
    foreach ($name in $legacyAgentTomlNames) {
        $target = Join-Path $TargetDir "$name.toml"
        if (-not (Test-Path $target)) { continue }
        Remove-Item -LiteralPath $target -Force
        Write-Host "  REMOVED legacy: agents/$name.toml" -ForegroundColor DarkGray
        $count++
    }
    return $count
}

Write-Host "`nDreamers Codex Installer" -ForegroundColor Cyan
Write-Host "Source:  $RepoRoot"
Write-Host "Target:  $CodexHome`n"

$total = 0
$legacyRemoved = 0

Write-Host "[agents]" -ForegroundColor Cyan
$total += Copy-DreamersFiles -From (Join-Path $RepoRoot "agents") -To (Join-Path $CodexHome "agents") -Label "agents"

Write-Host "[skills]" -ForegroundColor Cyan
$skillsRoot = Join-Path $RepoRoot "skills"
if (Test-Path $skillsRoot) {
    Get-ChildItem $skillsRoot -Directory | Where-Object { $_.Name -like "dreamers-*" } | ForEach-Object {
        $total += Copy-DreamersFiles -From $_.FullName -To (Join-Path (Join-Path $CodexHome "skills") $_.Name) -Label "skills/$($_.Name)"
    }
}

Write-Host "[dreamers]" -ForegroundColor Cyan
foreach ($name in @("refs", "templates", "instructions")) {
    $total += Copy-DreamersFiles -From (Join-Path (Join-Path $RepoRoot "dreamers") $name) -To (Join-Path (Join-Path $CodexHome "dreamers") $name) -Label "dreamers/$name"
}

Write-Host "[legacy]" -ForegroundColor Cyan
$legacyRemoved += Remove-LegacyAgentTomls -TargetDir (Join-Path $CodexHome "agents")
$legacyRemoved += Remove-LegacyAgentFiles -TargetDir (Join-Path (Join-Path $CodexHome "dreamers") "agents")

Write-Host "`nInstalled $total Dreamers Codex file(s); removed $legacyRemoved legacy file(s).`n" -ForegroundColor Cyan
