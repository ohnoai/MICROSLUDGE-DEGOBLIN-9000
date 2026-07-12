# Code Map

This is a navigation aid, not a complete inventory. Update it when stable structure changes.

## Entry points

- `START-HERE-Microsludge-Degoblin.vbs`: normal graphical launcher.
- `START-HERE.txt`: short launch instructions.
- `WALKTHROUGH.txt`: longer user walkthrough.
- `UNINSTALL-Microsludge-Degoblin.vbs`: uninstall launcher.

## Core scripts

- `Scripts/Microsludge-Degoblin.ps1`: main detection, dry-run, and cleanup entry point.
- `Scripts/Microsludge-Degoblin.Helpers.ps1`: shared PowerShell helpers.
- `Scripts/Start-Microsludge-Degoblin-GUI.ps1`: graphical interface.
- `Scripts/Start-Microsludge-Degoblin-Walkthrough.ps1`: console walkthrough and wizard.
- `Scripts/Test-Microsludge-WindowsAI.ps1`: detection-only Windows AI report.

## Installation and persistence

- `Scripts/Install-Microsludge-DegoblinTask.ps1`: installs the post-update scheduled task and package copy.
- `Scripts/Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1`: scheduled-task wrapper and update-evidence gate.
- `Scripts/Uninstall-Microsludge-DegoblinTask.ps1`: removes the scheduled task and installed package.

## Project metadata and assets

- `README.md`: behavior, targets, non-targets, switches, and usage.
- `VERSION`: current release version.
- `Assets/`: GUI and README images.
- `.github/FUNDING.yml`: repository funding configuration.
