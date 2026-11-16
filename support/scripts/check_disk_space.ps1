<#
.SYNOPSIS
    Mesh Disk Space Safety Guard
.DESCRIPTION
    Checks available disk capacity on system drive (C:) and project drive (D:)
    before executing resource-heavy operations (Flutter, Gradle, Cargo builds).
    Enforces safety thresholds to prevent system drive exhaustion.
#>

param(
    [int]$CriticalThresholdGB = 15,
    [int]$WarningThresholdGB = 25
)

$ErrorActionPreference = "Stop"

function Check-DriveCapacity {
    param([string]$DriveLetter)

    try {
        $drive = Get-PSDrive -Name $DriveLetter -PSProvider FileSystem -ErrorAction SilentlyContinue
        if (-not $drive) {
            Write-Warning "Drive $DriveLetter`: not found or not accessible."
            return $true
        }

        $freeGB = [Math]::Round($drive.Free / 1GB, 2)
        $usedGB = [Math]::Round($drive.Used / 1GB, 2)
        $totalGB = $freeGB + $usedGB
        $percentFree = [Math]::Round(($freeGB / $totalGB) * 100, 1)

        Write-Host "Drive $DriveLetter`: Total: $totalGB GB | Used: $usedGB GB | Free: $freeGB GB ($percentFree%)"

        if ($freeGB -lt 8) {
            Write-Error "[EMERGENCY] Drive $DriveLetter`: has only $freeGB GB free (< 8 GB)! Halting build to prevent system freeze/corruption."
            return $false
        }
        elseif ($freeGB -lt $CriticalThresholdGB) {
            Write-Error "[CRITICAL] Drive $DriveLetter`: has only $freeGB GB free (< $CriticalThresholdGB GB)! Aborting operation."
            return $false
        }
        elseif ($freeGB -lt $WarningThresholdGB) {
            Write-Warning "[WARNING] Drive $DriveLetter`: is below $WarningThresholdGB GB free ($freeGB GB remaining). Proceed with caution."
            return $true
        }
        else {
            Write-Host "[HEALTHY] Drive $DriveLetter`: free space is satisfactory ($freeGB GB)." -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to query drive $DriveLetter`: $_"
        return $false
    }
}

Write-Host "=== Mesh Development Storage Guard ===" -ForegroundColor Cyan
$cSafe = Check-DriveCapacity -DriveLetter "C"
$dSafe = Check-DriveCapacity -DriveLetter "D"

if (-not $cSafe -or -not $dSafe) {
    Write-Host "`nDisk protection triggered! Operation aborted." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll drive checks passed. Safe to proceed." -ForegroundColor Green
exit 0
