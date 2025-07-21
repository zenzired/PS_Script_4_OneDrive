# Cleanup-OneDriveFiles.ps1
# Deletes OneDrive files if:
# - They were copied
# - Not referenced anywhere

$ErrorActionPreference = "Stop"

$oneDrivePath = $env:OneDrive
$copiedLogPath = "$env:USERPROFILE\Desktop\OneDriveFiles.txt"
$referencedPath = "$env:USERPROFILE\Desktop\OneDriveReferencedFiles.txt"
$deletedLog = "$env:USERPROFILE\Desktop\DeletedOneDriveFiles.txt"

$dryRun = $false  # Set to $false to enable deletion

if (!(Test-Path $copiedLogPath) -or !(Test-Path $referencedPath)) {
    Write-Error "Required log files not found. Run prior scripts first."
    exit
}

$copiedFiles = Get-Content $copiedLogPath | Where-Object { Test-Path $_ }
$referenced = Get-Content $referencedPath | ForEach-Object { $_.ToLowerInvariant().Trim() }

$deleted = @()
$skipped = @()

foreach ($file in $copiedFiles) {
    $fLower = $file.ToLowerInvariant()

    if ($referenced -contains $fLower) {
        $skipped += $file
        continue
    }

    if ($dryRun) {
        Write-Host "[DRY RUN] Would delete: $file"
    } else {
        try {
            Remove-Item -Path $file -Force
            $deleted += $file
            Write-Host "🗑️ Deleted: $file"
        } catch {
            $skipped += $file
            Write-Warning "❌ Failed to delete: $file"
        }
    }
}

if (-not $dryRun -and $deleted.Count -gt 0) {
    $deleted | Out-File -FilePath $deletedLog -Encoding UTF8
    Write-Host "📝 Deleted log saved to: $deletedLog"
}

Write-Host ""
Write-Host "=== Cleanup Summary ==="
Write-Host "Total Files Checked: $($copiedFiles.Count)"
Write-Host "Deleted: $($deleted.Count)"
Write-Host "Skipped: $($skipped.Count)"
Write-Host "Dry Run: $dryRun"
