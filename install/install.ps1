<#
.SYNOPSIS
    Installs this repository's Claude Code skills globally via Windows directory Junctions.

.DESCRIPTION
    Creates a Junction under $HOME\.claude\skills for every skill in this repository
    (develop, review, ship). This repository remains the single source of truth: nothing
    is copied, only linked. Safe to run more than once.

.NOTES
    Requires no Administrator privileges - directory Junctions (unlike symbolic links)
    are a normal-user NTFS feature on Windows.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $HOME '.claude\skills'

# Name under $SkillsDir -> path relative to the repo root.
#
# No "vendor"/"ponytail" entry: review/SKILL.md reads the over-engineering/YAGNI ruleset at
# runtime from the standalone `ponytail` Claude Code plugin (see review/SKILL.md's "Locating
# the ponytail plugin" section) rather than from anything in this repository.
$Links = [ordered]@{
    'develop' = 'develop'
    'review'  = 'review'
    'ship'    = 'ship'
}

function Get-FullPathNoSlash {
    param([string]$Path)
    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\')
}

# Classifies what exists (if anything) at $Path relative to the junction we want there.
# Returns one of: Absent | CorrectJunction | Conflict
function Get-LinkState {
    param(
        [string]$Path,
        [string]$ExpectedTarget
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ State = 'Absent' }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

    if (-not $isReparsePoint) {
        $kind = if ($item.PSIsContainer) { 'a normal directory' } else { 'a normal file' }
        return @{ State = 'Conflict'; Detail = "$Path already exists as $kind (not a Junction)" }
    }

    if ($item.LinkType -ne 'Junction') {
        return @{ State = 'Conflict'; Detail = "$Path already exists as a $($item.LinkType), not a Junction" }
    }

    $actualTarget = $item.Target
    if ($actualTarget -is [array]) { $actualTarget = $actualTarget[0] }
    $normActual   = Get-FullPathNoSlash $actualTarget
    $normExpected = Get-FullPathNoSlash $ExpectedTarget

    if ($normActual -ieq $normExpected) {
        return @{ State = 'CorrectJunction'; Target = $normActual }
    }

    return @{ State = 'Conflict'; Detail = "$Path is a Junction, but points to '$normActual', expected '$normExpected'" }
}

Write-Output 'Claude Code Global Skills Installer'
Write-Output ''
Write-Output 'Repository:'
Write-Output "  $RepoRoot"
Write-Output ''
Write-Output 'Global skills:'
Write-Output "  $SkillsDir"
Write-Output ''

if (-not (Test-Path -LiteralPath $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($name in $Links.Keys) {
    $source = Join-Path $RepoRoot $Links[$name]
    $target = Join-Path $SkillsDir $name
    $row = [ordered]@{ Name = $name; Target = $target; Ok = $false; Message = '' }

    try {
        if (-not (Test-Path -LiteralPath $source)) {
            $row.Message = "source path does not exist in this repository: $source"
            $results.Add([pscustomobject]$row)
            continue
        }

        $state = Get-LinkState -Path $target -ExpectedTarget $source

        if ($state.State -eq 'Conflict') {
            $row.Message = "CONFLICT - $($state.Detail). Not touched. Resolve manually (move/remove the existing path), then re-run this script."
            $results.Add([pscustomobject]$row)
            continue
        }

        if ($state.State -eq 'Absent') {
            New-Item -ItemType Junction -Path $target -Target $source | Out-Null
        }
        # else: State -eq 'CorrectJunction' - already installed, nothing to do.

        # Verify, regardless of whether we just created it or it was already correct.
        $verifyItem = Get-Item -LiteralPath $target -Force
        $isJunction = (($verifyItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -and ($verifyItem.LinkType -eq 'Junction')
        if (-not $isJunction) {
            $row.Message = 'verification failed: target exists but is not a Junction'
            $results.Add([pscustomobject]$row)
            continue
        }

        $verifyTarget = $verifyItem.Target
        if ($verifyTarget -is [array]) { $verifyTarget = $verifyTarget[0] }
        if ((Get-FullPathNoSlash $verifyTarget) -ine (Get-FullPathNoSlash $source)) {
            $row.Message = "verification failed: Junction points to '$verifyTarget', expected '$source'"
            $results.Add([pscustomobject]$row)
            continue
        }

        $marker = Join-Path $target 'SKILL.md'
        if (-not (Test-Path -LiteralPath $marker)) {
            $row.Message = "verification failed: expected $marker does not exist"
            $results.Add([pscustomobject]$row)
            continue
        }

        $row.Ok = $true
        if ($state.State -eq 'Absent') {
            $row.Message = 'created'
        } else {
            $row.Message = 'already installed'
        }
        $results.Add([pscustomobject]$row)
    }
    catch {
        $row.Message = "unexpected error: $($_.Exception.Message)"
        $results.Add([pscustomobject]$row)
    }
}

$maxNameLen = ($results | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
foreach ($r in $results) {
    $tag = if ($r.Ok) { '[OK]' } else { '[FAIL]' }
    $paddedName = $r.Name.PadRight($maxNameLen)
    Write-Output "$tag $paddedName -> $($r.Target)"
    if ($r.Message) {
        Write-Output "       $($r.Message)"
    }
}

Write-Output ''

$failed = @($results | Where-Object { -not $_.Ok })
if ($failed.Count -gt 0) {
    Write-Output "Installation FAILED for $($failed.Count) of $($results.Count) link(s):"
    foreach ($f in $failed) {
        Write-Output "  - $($f.Name): $($f.Message)"
    }
    exit 1
}

Write-Output 'Installation completed successfully.'
exit 0
