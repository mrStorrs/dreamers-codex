<#
.SYNOPSIS
    Removes Dreamers Codex-managed files from the user's Codex home.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

function Remove-DreamersPath {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { return 0 }
    if ($DryRun) {
        Write-Host "  WOULD REMOVE: $Label -> $Path" -ForegroundColor Yellow
    } else {
        Remove-Item -LiteralPath $Path -Recurse -Force
        Write-Host "  REMOVED: $Label" -ForegroundColor Red
    }
    return 1
}

$verb = if ($DryRun) { "Dreamers Codex Remover (DRY RUN)" } else { "Dreamers Codex Remover" }
Write-Host "`n$verb" -ForegroundColor Cyan
Write-Host "Target: $CodexHome`n"

$total = 0

Write-Host "[skills]" -ForegroundColor Cyan
$skillsRoot = Join-Path $RepoRoot "skills"
if (Test-Path $skillsRoot) {
    Get-ChildItem $skillsRoot -Directory | Where-Object { $_.Name -like "dreamers-*" } | ForEach-Object {
        $total += Remove-DreamersPath -Path (Join-Path (Join-Path $CodexHome "skills") $_.Name) -Label "skills/$($_.Name)"
    }
}

Write-Host "[dreamers]" -ForegroundColor Cyan
foreach ($name in @("refs", "templates", "agents", "instructions")) {
    $total += Remove-DreamersPath -Path (Join-Path (Join-Path $CodexHome "dreamers") $name) -Label "dreamers/$name"
}

$action = if ($DryRun) { "Would remove" } else { "Removed" }
Write-Host "`n$action $total Dreamers Codex item(s).`n" -ForegroundColor Cyan
