[CmdletBinding()]
param(
    [string]$Root = $(if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Get-Location })
)

$ErrorActionPreference = "Stop"
$skillRoot = Join-Path $Root "skills"
if (-not (Test-Path $skillRoot)) { throw "Missing skills directory: $skillRoot" }

$errors = New-Object System.Collections.Generic.List[string]
Get-ChildItem $skillRoot -Directory | ForEach-Object {
    $skill = $_
    $file = Join-Path $skill.FullName "SKILL.md"
    if (-not (Test-Path $file)) {
        $errors.Add("Missing SKILL.md: $($skill.FullName)")
        return
    }
    $content = Get-Content -Raw $file
    if ($content -notmatch "(?s)^---\s*\nname:\s*([^\n]+)\ndescription:\s*([^\n]+)\n---") {
        $errors.Add("Invalid frontmatter: $file")
    }
    if ($content -match "argument-hint:") {
        $errors.Add("Copilot argument-hint remains: $file")
    }
    if ($content -match "request_information|manage_todo_list|~/.copilot") {
        $errors.Add("Unconverted Copilot token remains: $file")
    }
}

$manifest = Join-Path $Root ".codex-plugin\plugin.json"
if (-not (Test-Path $manifest)) { $errors.Add("Missing plugin manifest: $manifest") }
else { Get-Content -Raw $manifest | ConvertFrom-Json | Out-Null }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Dreamers Codex validation passed." -ForegroundColor Green
