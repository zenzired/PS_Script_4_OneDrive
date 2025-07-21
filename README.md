
# 📁 OneDrive File Management Toolkit

A PowerShell-based utility suite to **locate**, **copy**, **analyze references to**, and **(safely) delete** files from your OneDrive folder.

---

## 🧰 Included Scripts

| Script Name                     | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `Find-OneDriveFiles.ps1`       | Scans your OneDrive folder and logs all file paths to a `.txt` file.       |
| `Copy-OneDriveFiles.ps1`       | Copies OneDrive files to a local backup folder, preserving structure.      |
| `Scan-OneDriveFileReferences.ps1` | Detects if any OneDrive files are actively referenced or used by Windows. |
| `Cleanup-OneDriveFiles.ps1`    | Deletes OneDrive files that are safely copied and unused elsewhere.        |

---

## ✅ Pre-requisites

- ✅ Windows 10/11
- ✅ PowerShell 5.1+ (Built-in)
- ✅ Visual Studio Code or Notepad++ (UTF-8 safe editors)
- ✅ Administrator access recommended for scanning scheduled tasks and environment paths

---

## 🔄 Script Workflow

### 1. **Locate Files**
```powershell
.\Find-OneDriveFiles.ps1
```
📄 Saves result to:  
`C:\Users\<you>\Desktop\OneDriveFiles.txt`

---

### 2. **Copy Files**
```powershell
.\Copy-OneDriveFiles.ps1
```
📂 Copies files to:  
`C:\Users\<you>\<OneDriveRelativePath>`

📝 Logs:
- Skipped files → `SkippedOneDriveFiles.txt`
- Already copied → Counted silently

---

### 3. **Scan Active References**
```powershell
.\Scan-OneDriveFileReferences.ps1
```
🔎 Scans:
- Shortcuts (Desktop, Start Menu, Startup)
- `PATH` environment variables
- Scheduled tasks
- Running processes

📄 Output:  
`OneDriveReferencedFiles.txt`

---

### 4. **Delete Safely**
```powershell
.\Cleanup-OneDriveFiles.ps1
```

- 🚨 Default: **Dry Run** (no deletion)
- 🔐 Only deletes files:
  - In `OneDriveFiles.txt`
  - Not listed in `OneDriveReferencedFiles.txt`

💡 To enable real deletion:
```powershell
$dryRun = $false
```
📄 Logs:
- Deleted files → `DeletedOneDriveFiles.txt`

---

## 🕐 How to Run as a Scheduled Task (Optional)

To automate daily or weekly cleanup:

1. Open **Task Scheduler**.
2. Click **Create Task**.
3. Under **General**:
   - Name: `OneDrive Cleanup`
   - Run with highest privileges
4. Under **Triggers**:
   - Add a schedule (e.g. Weekly at 1 AM)
5. Under **Actions**:
   - Action: Start a program
   - Program: `powershell.exe`
   - Add arguments:
     ```powershell
     -ExecutionPolicy Bypass -File "C:\Path\To\Cleanup-OneDriveFiles.ps1"
     ```
6. Click **OK**.

🔐 Optional: Sign the script or set execution policy via Group Policy.

---

## 🖥️ Optional: Simple UI Script Launcher

Use a **menu-based launcher** for easier interaction:

```powershell
# launcher.ps1
$menu = @(
    "1. Find OneDrive Files",
    "2. Copy Files",
    "3. Scan References",
    "4. Cleanup Files",
    "5. Exit"
)

do {
    Clear-Host
    $menu | ForEach-Object { Write-Host $_ }
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        "1" { .\Find-OneDriveFiles.ps1 }
        "2" { .\Copy-OneDriveFiles.ps1 }
        "3" { .\Scan-OneDriveFileReferences.ps1 }
        "4" { .\Cleanup-OneDriveFiles.ps1 }
        "5" { break }
        default { Write-Host "Invalid choice." }
    }
    Pause
} while ($true)
```

---

## ⚠ Notes

- These scripts are designed for **backup-and-cleanup** operations only.
- Always review `OneDriveReferencedFiles.txt` before deleting.
- Emojis/logs require saving in **UTF-8** format (Visual Studio Code: File → Save with Encoding → UTF-8).

---

## 💬 Need Help?

If you'd like a GUI (WPF or WinForms) or integration into a portable app, feel free to ask.
