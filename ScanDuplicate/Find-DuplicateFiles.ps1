<#
.SYNOPSIS
    Finds and manages duplicate files on Windows 11 with interactive options.
.DESCRIPTION
    Scans selected directories, identifies duplicates, and provides options to:
    - Ignore results
    - Preview duplicates
    - Delete duplicates (keeping newest or oldest)
.NOTES
    File Name      : FindAndManageDuplicates.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Parameters
param (
    [string]$OutputFile = "DuplicateFiles_Report.csv",
    [switch]$IncludeSystemFolders = $false,
    [int]$MinimumSizeKB = 10,
    [switch]$ScanAllUserFolders = $false
)

# Add required assembly for folder browser
Add-Type -AssemblyName System.Windows.Forms

# Function to calculate MD5 hash
function Get-FileHashMD5 {
    param ([string]$FilePath)
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hashBytes = $md5.ComputeHash($stream)
        $stream.Close()
        return [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    }
    catch {
        Write-Warning "Error calculating hash for $FilePath : $_"
        return $null
    }
}

function Format-FileSize {
    param ([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes bytes" }
}

function Select-UserFolders {
    param ([string]$RootPath = "$env:USERPROFILE")
    
    $allFolders = Get-ChildItem -Path $RootPath -Directory | 
                  Where-Object { $_.Name -notin @('AppData', 'Application Data', 'Cookies', 'Local Settings', 'NetHood', 'PrintHood', 'Recent', 'SendTo', 'Templates', 'Start Menu') }
    
    if ($ScanAllUserFolders) { return $allFolders.FullName }
    
    Write-Host "`nAvailable folders under your user profile ($RootPath):" -ForegroundColor Cyan
    $menu = @{}; $i = 1
    
    foreach ($folder in $allFolders) {
        $size = (Get-ChildItem $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $formattedSize = if ($size) { Format-FileSize -Bytes $size } else { "Unknown size" }
        Write-Host "$i. $($folder.Name) ($formattedSize)"
        $menu.Add($i, $folder.FullName)
        $i++
    }
    
    Write-Host "$i. ALL of the above folders"
    $menu.Add($i, $allFolders.FullName)
    
    $selection = Read-Host "`nSelect folders to scan (comma-separated numbers, or $i for all)"
    $selectedNumbers = $selection -split ',' | ForEach-Object { $_.Trim() }
    
    $selectedFolders = @()
    foreach ($number in $selectedNumbers) {
        if ($number -eq $i) { return $allFolders.FullName }
        elseif ($menu.ContainsKey([int]$number)) { $selectedFolders += $menu[[int]$number] }
    }
    
    return $selectedFolders | Select-Object -Unique
}

# Main script
Write-Host "`nDuplicate File Finder and Manager" -ForegroundColor Cyan
Write-Host "===================================="

# Get folders to scan
$selectedFolders = Select-UserFolders
if (-not $selectedFolders) {
    Write-Host "No folders selected. Exiting." -ForegroundColor Yellow
    exit
}

# Allow adding additional folders
do {
    $addMore = Read-Host "`nDo you want to add more folders to scan? (Y/N)"
    if ($addMore -eq 'Y' -or $addMore -eq 'y') {
        $customPath = Read-Host "Enter full path to folder (or leave blank to browse)"
        
        if ([string]::IsNullOrWhiteSpace($customPath)) {
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderBrowser.Description = "Select additional folder to scan"
            $folderBrowser.RootFolder = 'MyComputer'
            
            if ($folderBrowser.ShowDialog() -eq 'OK') {
                $selectedFolders += $folderBrowser.SelectedPath
            }
        }
        else {
            if (Test-Path $customPath -PathType Container) {
                $selectedFolders += $customPath
            }
            else {
                Write-Host "Path not found: $customPath" -ForegroundColor Red
            }
        }
    }
} while ($addMore -eq 'Y' -or $addMore -eq 'y')

$selectedFolders = $selectedFolders | Select-Object -Unique
Write-Host "`nSelected folders to scan:" -ForegroundColor Cyan
$selectedFolders | ForEach-Object { Write-Host "- $_" }

# Exclude system folders
$excludeFolders = @(
    "C:\\Windows", "C:\\Program Files", "C:\\Program Files (x86)",
    "C:\\ProgramData", "C:\\System Volume Information",
    "C:\\Recovery", "C:\\`$Recycle.Bin"
)

if (-not $IncludeSystemFolders) {
    $excludePattern = ($excludeFolders | ForEach-Object { [regex]::Escape($_) }) -join '|'
}

# Scan for duplicates
$fileHashTable = @{}
$duplicatesFound = 0
$totalFilesScanned = 0
$startTime = Get-Date
$minimumSizeBytes = $MinimumSizeKB * 1024

try {
    Write-Host "`nScanning files (this may take a while)..." -ForegroundColor Cyan
    $allFiles = Get-ChildItem -Path $selectedFolders -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { $_.Length -ge $minimumSizeBytes }
    
    if ($excludePattern) {
        $allFiles = $allFiles | Where-Object { $_.FullName -notmatch $excludePattern }
    }
}
catch {
    Write-Error "Error accessing files: $_"
    exit 1
}

$totalFilesToScan = $allFiles.Count
Write-Host "Found $totalFilesToScan files to scan (excluding files smaller than $MinimumSizeKB KB)"

# Process files
$progress = 0
foreach ($file in $allFiles) {
    $progress++
    $totalFilesScanned++
    
    if ($progress % 100 -eq 0) {
        $percentComplete = [math]::Round(($progress / $totalFilesToScan) * 100, 2)
        Write-Progress -Activity "Scanning files..." -Status "$percentComplete% complete ($progress of $totalFilesToScan)" -PercentComplete $percentComplete
    }
    
    try {
        $fileSize = $file.Length
        $fileHash = Get-FileHashMD5 -FilePath $file.FullName
        
        if ($fileHash) {
            $fileKey = "$fileSize-$fileHash"
            
            if ($fileHashTable.ContainsKey($fileKey)) {
                $fileHashTable[$fileKey] += @($file)
                $duplicatesFound++
            }
            else {
                $fileHashTable[$fileKey] = @($file)
            }
        }
    }
    catch {
        Write-Warning "Error processing file $($file.FullName): $_"
    }
}

Write-Progress -Activity "Scanning files..." -Completed

# Prepare results
$duplicateGroups = $fileHashTable.Values | Where-Object { $_.Count -gt 1 }
$totalDuplicateGroups = $duplicateGroups.Count
$endTime = Get-Date
$duration = $endTime - $startTime

# Display summary
Write-Host ""
Write-Host "Scan completed in $($duration.TotalSeconds.ToString('N2')) seconds" -ForegroundColor Cyan
Write-Host "Files scanned: $totalFilesScanned" -ForegroundColor Cyan
Write-Host "Duplicate files found: $duplicatesFound (in $totalDuplicateGroups groups)" -ForegroundColor Cyan
Write-Host ""

if ($totalDuplicateGroups -gt 0) {
    # Save results to CSV
    $results = @()
    foreach ($group in $duplicateGroups) {
        $groupSize = Format-FileSize -Bytes $group[0].Length
        foreach ($file in $group) {
            $results += [PSCustomObject]@{
                GroupNumber = $duplicateGroups.IndexOf($group) + 1
                FilePath = $file.FullName
                FileName = $file.Name
                FileSize = $groupSize
                LastModified = $file.LastWriteTime
                Hash = $fileKey.Split('-')[1]
            }
        }
    }
    
    if ($OutputFile) {
        try {
            $results | Export-Csv -Path $OutputFile -NoTypeInformation
            Write-Host "Results saved to $OutputFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not save results to $OutputFile : $_"
        }
    }

    # Present management options
    do {
        Write-Host "`nDuplicate Management Options:" -ForegroundColor Magenta
        Write-Host "1. Ignore duplicates (exit)"
        Write-Host "2. Preview duplicates"
        Write-Host "3. Delete duplicates (keep newest)"
        Write-Host "4. Delete duplicates (keep oldest)"
        Write-Host "5. Delete all duplicates (keep one random copy)"
        
        $choice = Read-Host "`nSelect action (1-5)"
        
        switch ($choice) {
            "1" { 
                Write-Host "Exiting without taking action." -ForegroundColor Yellow
                exit 
            }
            "2" {
                # Preview duplicates
                $groupNumber = 1
                foreach ($group in $duplicateGroups) {
                    $groupSize = Format-FileSize -Bytes $group[0].Length
                    Write-Host "`nDuplicate Group #$groupNumber ($groupSize)" -ForegroundColor Yellow
                    Write-Host "----------------------------------------"
                    $group | ForEach-Object { Write-Host $_.FullName }
                    $groupNumber++
                }
            }
            "3" {
                # Delete duplicates (keep newest)
                $deletedCount = 0
                foreach ($group in $duplicateGroups) {
                    $toDelete = $group | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1
                    $toDelete | ForEach-Object {
                        try {
                            Remove-Item $_.FullName -ErrorAction Stop
                            Write-Host "Deleted: $($_.FullName)" -ForegroundColor Red
                            $deletedCount++
                        }
                        catch {
                            Write-Warning "Failed to delete $($_.FullName): $_"
                        }
                    }
                }
                Write-Host "`nDeleted $deletedCount duplicate files (kept newest copies)." -ForegroundColor Cyan
                exit
            }
            "4" {
                # Delete duplicates (keep oldest)
                $deletedCount = 0
                foreach ($group in $duplicateGroups) {
                    $toDelete = $group | Sort-Object LastWriteTime | Select-Object -Skip 1
                    $toDelete | ForEach-Object {
                        try {
                            Remove-Item $_.FullName -ErrorAction Stop
                            Write-Host "Deleted: $($_.FullName)" -ForegroundColor Red
                            $deletedCount++
                        }
                        catch {
                            Write-Warning "Failed to delete $($_.FullName): $_"
                        }
                    }
                }
                Write-Host "`nDeleted $deletedCount duplicate files (kept oldest copies)." -ForegroundColor Cyan
                exit
            }
            "5" {
                # Delete all duplicates (keep one random copy)
                $deletedCount = 0
                foreach ($group in $duplicateGroups) {
                    $toDelete = $group | Get-Random -Count ($group.Count - 1)
                    $toDelete | ForEach-Object {
                        try {
                            Remove-Item $_.FullName -ErrorAction Stop
                            Write-Host "Deleted: $($_.FullName)" -ForegroundColor Red
                            $deletedCount++
                        }
                        catch {
                            Write-Warning "Failed to delete $($_.FullName): $_"
                        }
                    }
                }
                Write-Host "`nDeleted $deletedCount duplicate files (kept one random copy per group)." -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "Invalid selection. Please choose 1-5." -ForegroundColor Red
            }
        }
    } while ($true)
}
else {
    Write-Host "No duplicate files found!" -ForegroundColor Green
}