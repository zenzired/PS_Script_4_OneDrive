# Find-OneDriveFiles.ps1
# Collects all file paths from the user's OneDrive folder

$ErrorActionPreference = "Stop"

$oneDrivePath = $env:OneDrive
$outputPath = "$env:USERPROFILE\Desktop\OneDriveFiles.txt"

if (!(Test-Path $oneDrivePath)) {
    Write-Error "OneDrive folder not found at: $oneDrivePath"
    exit 1
}

Write-Host "Scanning OneDrive files in: $oneDrivePath..."

$files = Get-ChildItem -Path $oneDrivePath -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$files | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ OneDrive file list saved to: $outputPath"
Write-Host "Total files found: $($files.Count)"
