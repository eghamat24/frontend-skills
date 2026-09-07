<#
.SYNOPSIS
    Reports whether this repository's Claude Code skills are correctly linked globally.

.DESCRIPTION
    Read-only check - never creates, modifies, or removes anything. Reports, for each
    expected Junction under $HOME\.claude\skills, whether it exists, is actually a
    Junction, points at this repository, and (for a skill) has a SKILL.md.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $HOME '.claude\skills'

# Keep this list in sync with install.ps1 / uninstall.ps1.
$Links = [ordered]@{
    'develop' = 'develop'
    'review'  = 'review'
    'ship'    = 'ship'
    'vendor'  = 'vendor'
}

function Get-FullPathNoSlash {
    param([string]$Path)
    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\')
}

Write-Output 'Claude Code Global Skills Status'
Write-Output ''
Write-Output 'Repository:'
Write-Output "  $RepoRoot"
Write-Output ''
Write-Output 'Global skills:'
Write-Output "  $SkillsDir"
Write-Output ''

$allOk = $true

foreach ($name in $Links.Keys) {
    $source = Join-Path $RepoRoot $Links[$name]
    $target = Join-Path $SkillsDir $name

    if (-not (Test-Path -LiteralPath $target)) {
        Write-Output "[MISSING] $name -> not installed ($target does not exist)"
        $allOk = $false
        continue
    }

    $item = Get-Item -LiteralPath $target -Force
    $isJunction = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -and ($item.LinkType -eq 'Junction')

    if (-not $isJunction) {
        Write-Output "[CONFLICT] $name -> $target exists but is not a Junction"
        $allOk = $false
        continue
    }

    $actualTarget = $item.Target
    if ($actualTarget -is [array]) { $actualTarget = $actualTarget[0] }
    $normActual = Get-FullPathNoSlash $actualTarget

    if (-not (Test-Path -LiteralPath $normActual)) {
        Write-Output "[BROKEN] $name -> $target points to '$normActual', which no longer exists"
        $allOk = $false
        continue
    }

    if (-not (Test-Path -LiteralPath $source)) {
        Write-Output "[STALE] $name -> $target points to '$normActual', but this repo no longer has '$source'"
        $allOk = $false
        continue
    }

    if ($normActual -ine (Get-FullPathNoSlash $source)) {
        Write-Output "[MISMATCH] $name -> $target points to '$normActual', expected '$source'"
        $allOk = $false
        continue
    }

    if ($name -eq 'vendor') {
        $marker = Join-Path $target 'ponytail\AGENTS.md'
        if (-not (Test-Path -LiteralPath $marker)) {
            Write-Output "[WARN] $name -> $target (linked, but vendor/ponytail submodule looks uninitialized)"
            $allOk = $false
            continue
        }
        Write-Output "[OK] $name -> $target"
    }
    else {
        $marker = Join-Path $target 'SKILL.md'
        if (-not (Test-Path -LiteralPath $marker)) {
            Write-Output "[BROKEN] $name -> $target (linked, but SKILL.md is missing)"
            $allOk = $false
            continue
        }
        Write-Output "[OK] $name -> $target"
    }
}

Write-Output ''
if ($allOk) {
    Write-Output 'All skills are correctly linked.'
    exit 0
}
else {
    Write-Output 'One or more skills are not correctly linked. Run .\install.ps1 to fix, or see messages above.'
    exit 1
}
