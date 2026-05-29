<#
.SYNOPSIS
    Installs Dreamers Codex skills into the user's Codex home.

.DESCRIPTION
    Copies skills and shared Dreamers resources from this package into
    $env:CODEX_HOME, or ~/.codex when CODEX_HOME is not set.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

function Copy-DreamersDirectory {
    param(
        [string]$From,
        [string]$To,
        [string]$Label
    )
    if (-not (Test-Path $From)) {
        Write-Warning "Source not found, skipping: $From"
        return 0
    }
    if ((Test-Path $To) -and -not $Force) {
        Write-Host "  SKIP (exists): $Label - use -Force to overwrite" -ForegroundColor Yellow
        return 0
    }
    $parent = Split-Path $To -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -Path $From -Destination $To -Recurse -Force
    Write-Host "  OK: $Label" -ForegroundColor Green
    return 1
}

Write-Host "`nDreamers Codex Installer" -ForegroundColor Cyan
Write-Host "Source:  $RepoRoot"
Write-Host "Target:  $CodexHome`n"

$total = 0

Write-Host "[skills]" -ForegroundColor Cyan
$skillsRoot = Join-Path $RepoRoot "skills"
if (Test-Path $skillsRoot) {
    Get-ChildItem $skillsRoot -Directory | Where-Object { $_.Name -like "dreamers-*" } | ForEach-Object {
        $total += Copy-DreamersDirectory -From $_.FullName -To (Join-Path (Join-Path $CodexHome "skills") $_.Name) -Label "skills/$($_.Name)"
    }
}

Write-Host "[dreamers]" -ForegroundColor Cyan
foreach ($name in @("refs", "templates", "agents", "instructions")) {
    $total += Copy-DreamersDirectory -From (Join-Path (Join-Path $RepoRoot "dreamers") $name) -To (Join-Path (Join-Path $CodexHome "dreamers") $name) -Label "dreamers/$name"
}

Write-Host "`nInstalled $total Dreamers Codex item(s).`n" -ForegroundColor Cyan
