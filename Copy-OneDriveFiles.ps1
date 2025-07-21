# Copy-OneDriveFiles.ps1
# Copies files listed in OneDriveFiles.txt to a local folder

$ErrorActionPreference = "Stop"

$sourceLog = "$env:USERPROFILE\Desktop\OneDriveFiles.txt"
$targetRoot = "C:\Users\louie"
$skippedLog = "$env:USERPROFILE\Desktop\SkippedOneDriveFiles.txt"

$copiedCount = 0
$skippedCount = 0
$alreadyCopiedCount = 0

$oneDrivePath = $env:OneDrive

if (!(Test-Path $sourceLog)) {
    Write-Error "Source file list not found: $sourceLog"
    exit 1
}

$files = Get-Content $sourceLog
$skipped = @()

foreach ($file in $files) {
    if (-not (Test-Path $file)) {
        $skipped += $file
        $skippedCount++
        continue
    }

    if (-not $file.StartsWith($oneDrivePath)) {
        Write-Warning "Skipping file not under OneDrive: $file"
        $skipped += $file
        continue
    }

    $relativePath = $file.Substring($oneDrivePath.Length).TrimStart("\")
    $destinationPath = Join-Path -Path $targetRoot -ChildPath $relativePath

    # Create directory if needed
    $destFolder = Split-Path -Path $destinationPath -Parent
    if (!(Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }

    if (Test-Path $destinationPath) {
        $src = Get-Item $file
        $dst = Get-Item $destinationPath

        if ($src.Length -eq $dst.Length -and $src.LastWriteTime -eq $dst.LastWriteTime) {
            $alreadyCopiedCount++
            continue
        }
    }

    try {
        Copy-Item -Path $file -Destination $destinationPath -Force
        $copiedCount++
    } catch {
        $skipped += $file
        $skippedCount++
        Write-Warning "Failed to copy: $file"
    }
}

$skipped | Out-File -FilePath $skippedLog -Encoding UTF8

Write-Host "`n=== Copy Summary ==="
Write-Host "Copied: $copiedCount"
Write-Host "Already copied: $alreadyCopiedCount"
Write-Host "Skipped: $skippedCount"
Write-Host "Skipped file list saved to: $skippedLog"
