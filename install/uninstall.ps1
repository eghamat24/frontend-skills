<#
.SYNOPSIS
    Removes the global Junctions created by install.ps1.

.DESCRIPTION
    Removes only the Junctions this repository's install.ps1 creates under
    $HOME\.claude\skills. Never touches the repository itself, and never removes a path
    that isn't actually a Junction - a real directory or file found at one of these names
    is reported as a conflict and left untouched. Safe to run more than once.

.NOTES
    Removal uses [System.IO.Directory]::Delete($path, $false) (non-recursive). This is
    deliberate: PowerShell's Remove-Item -Recurse on a directory Junction can, in some
    versions, follow the reparse point and delete the *real* target's contents instead of
    just the link. Empirically verified in this repo's development that the non-recursive
    .NET delete removes only the link and leaves the real target fully intact.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SkillsDir = Join-Path $HOME '.claude\skills'

# Keep this list in sync with install.ps1 / status.ps1.
$Links = [ordered]@{
    'develop' = 'develop'
    'review'  = 'review'
    'ship'    = 'ship'
    'vendor'  = 'vendor'
}

Write-Output 'Claude Code Global Skills Uninstaller'
Write-Output ''
Write-Output 'Global skills:'
Write-Output "  $SkillsDir"
Write-Output ''

$results = New-Object System.Collections.Generic.List[object]

foreach ($name in $Links.Keys) {
    $target = Join-Path $SkillsDir $name
    $row = [ordered]@{ Name = $name; Target = $target; Ok = $false; Message = '' }

    try {
        if (-not (Test-Path -LiteralPath $target)) {
            $row.Ok = $true
            $row.Message = 'not installed (nothing to do)'
            $results.Add([pscustomobject]$row)
            continue
        }

        $item = Get-Item -LiteralPath $target -Force
        $isJunction = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -and ($item.LinkType -eq 'Junction')

        if (-not $isJunction) {
            $kind = if ($item.PSIsContainer) { 'a normal directory' } else { 'a normal file' }
            $row.Message = "CONFLICT - $target is $kind, not a Junction. Left untouched; remove it manually if that's intended."
            $results.Add([pscustomobject]$row)
            continue
        }

        $originalTarget = $item.Target
        if ($originalTarget -is [array]) { $originalTarget = $originalTarget[0] }

        [System.IO.Directory]::Delete($target, $false)

        if (Test-Path -LiteralPath $target) {
            $row.Message = 'removal did not take effect (path still exists)'
            $results.Add([pscustomobject]$row)
            continue
        }

        $row.Ok = $true
        $row.Message = "removed (was linked to $originalTarget)"
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
    Write-Output "Uninstall FAILED for $($failed.Count) of $($results.Count) link(s):"
    foreach ($f in $failed) {
        Write-Output "  - $($f.Name): $($f.Message)"
    }
    exit 1
}

Write-Output 'Uninstall completed successfully. The repository itself was not modified.'
exit 0
