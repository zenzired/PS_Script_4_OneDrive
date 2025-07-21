# Scan-OneDriveFileReferences.ps1
# Scans for references to OneDrive files

$ErrorActionPreference = "Stop"

$oneDrivePath = $env:OneDrive.ToLowerInvariant()
$logFile = "$env:USERPROFILE\Desktop\OneDriveReferencedFiles.txt"
$referencedFiles = @()

# Helper function
function Add-Match($path) {
    if ($path -and $path.ToLowerInvariant().StartsWith($oneDrivePath) -and (Test-Path $path)) {
        $referencedFiles += (Get-Item $path).FullName
    }
}

# 1. Shortcuts in Desktop, Start Menu, Startup
$shortcutDirs = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:USERPROFILE\Desktop"
)
foreach ($dir in $shortcutDirs) {
    Get-ChildItem -Path $dir -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
        $target = (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath
        Add-Match $target
    }
}

# 2. Environment PATH
$envPath = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
$envPath.Split(';') | ForEach-Object { Add-Match $_ }

# 3. Scheduled Tasks
try {
    schtasks /Query /FO LIST /V | ForEach-Object {
        if ($_ -match "Task To Run:\s+(.+)") {
            Add-Match $matches[1]
        }
    }
} catch {
    Write-Warning "Could not scan scheduled tasks"
}

# 4. Running Processes
Get-Process | ForEach-Object {
    try {
        Add-Match $_.Path
    } catch {}
}

$referencedFiles = $referencedFiles | Sort-Object -Unique
$referencedFiles | Out-File -FilePath $logFile -Encoding UTF8

Write-Host "✅ Referenced OneDrive files saved to: $logFile"
Write-Host "Total referenced: $($referencedFiles.Count)"
