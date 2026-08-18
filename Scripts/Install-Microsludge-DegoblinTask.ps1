<#
Registers the scheduled task for Microsludge Degoblin.

Run this once from an elevated PowerShell prompt. The task runs at logon,
waits two minutes, then calls the installed Windows Update-aware wrapper.
#>

param(
    [switch]$AlwaysApply,
    [switch]$BlockOneDrive,
    [switch]$RemoveOneDrive,
    [switch]$RemoveWidgets,
    [switch]$DisableEdgeUpdates,
    [switch]$DisableWindowsAI,
    [switch]$PinDocuments,
    [switch]$SkipCopilot,
    [switch]$SkipOneDrive,
    [switch]$SkipEdge,
    [switch]$SkipOutlook,
    [switch]$SkipConsumerContent
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$sourceWrapper = Join-Path $scriptRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$taskName = "Microsludge Degoblin After Windows Update"
$taskPath = "\Microsludge-Degoblin\"
$userId = "$env:USERDOMAIN\$env:USERNAME"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

function Copy-MicrosludgePackageToInstallRoot {
    param(
        [string]$SourceRoot,
        [string]$InstallRoot
    )

    $expectedInstallRoot = Get-MicrosludgeInstallRoot
    $actualFullPath = [System.IO.Path]::GetFullPath($InstallRoot).TrimEnd("\")
    $expectedFullPath = [System.IO.Path]::GetFullPath($expectedInstallRoot).TrimEnd("\")
    if ($actualFullPath -ne $expectedFullPath) {
        throw "Refusing to install to unexpected path: $InstallRoot"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot "Scripts"))) {
        throw "Source Scripts folder not found: $SourceRoot"
    }

    $sourceFullPath = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd("\")
    if ($sourceFullPath -eq $actualFullPath) {
        Write-Host "Source is already the installed package copy. Skipping copy refresh."
        return
    }

    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

    $directories = @("Scripts", "Assets")
    foreach ($directory in $directories) {
        $sourcePath = Join-Path $SourceRoot $directory
        $destinationPath = Join-Path $InstallRoot $directory
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }

        Copy-Item -LiteralPath $sourcePath -Destination $InstallRoot -Recurse -Force
    }

    Get-ChildItem -LiteralPath $SourceRoot -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "^\." } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $InstallRoot -Force
        }
}

function Install-MicrosludgeStartMenuShortcuts {
    param(
        [string]$InstallRoot
    )

    $startMenuFolder = Get-MicrosludgeStartMenuFolder
    $launcher = Join-Path $InstallRoot "START-HERE-Microsludge-Degoblin.vbs"
    $uninstallLauncher = Join-Path $InstallRoot "UNINSTALL-Microsludge-Degoblin.vbs"
    $wscript = Join-Path $env:WINDIR "System32\wscript.exe"
    $icon = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

    New-Item -ItemType Directory -Force -Path $startMenuFolder | Out-Null

    $shell = New-Object -ComObject WScript.Shell

    $appShortcutPath = Join-Path $startMenuFolder "Microsludge Degoblin 9000.lnk"
    $appShortcut = $shell.CreateShortcut($appShortcutPath)
    $appShortcut.TargetPath = $wscript
    $appShortcut.Arguments = ('"{0}"' -f $launcher)
    $appShortcut.WorkingDirectory = $InstallRoot
    $appShortcut.Description = "Launch Microsludge Degoblin 9000"
    $appShortcut.IconLocation = "$icon,0"
    $appShortcut.Save()

    $uninstallShortcutPath = Join-Path $startMenuFolder "Uninstall Microsludge Degoblin 9000.lnk"
    $uninstallShortcut = $shell.CreateShortcut($uninstallShortcutPath)
    $uninstallShortcut.TargetPath = $wscript
    $uninstallShortcut.Arguments = ('"{0}"' -f $uninstallLauncher)
    $uninstallShortcut.WorkingDirectory = $InstallRoot
    $uninstallShortcut.Description = "Uninstall Microsludge Degoblin 9000"
    $uninstallShortcut.IconLocation = "$icon,0"
    $uninstallShortcut.Save()

    return $startMenuFolder
}

function Register-MicrosludgeInstalledApp {
    param(
        [string]$InstallRoot,
        [string]$Version
    )

    $registryPath = Get-MicrosludgeUninstallRegistryPath
    $uninstallLauncher = Join-Path $InstallRoot "UNINSTALL-Microsludge-Degoblin.vbs"
    $wscript = Join-Path $env:WINDIR "System32\wscript.exe"
    $uninstallString = '"{0}" "{1}"' -f $wscript, $uninstallLauncher
    $estimatedSize = 0

    try {
        $estimatedSize = [int]([math]::Ceiling(((Get-ChildItem -LiteralPath $InstallRoot -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum) / 1KB))
    } catch {
        $estimatedSize = 0
    }

    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "DisplayName" -Value "Microsludge Degoblin 9000" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "DisplayVersion" -Value $Version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "Publisher" -Value "Microsludge Degoblin contributors" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "InstallLocation" -Value $InstallRoot -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "DisplayIcon" -Value $wscript -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "UninstallString" -Value $uninstallString -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "EstimatedSize" -Value $estimatedSize -PropertyType DWord -Force | Out-Null

    return $registryPath
}

if (-not (Test-MicrosludgeIsAdmin)) {
    throw "This installer must be run as Administrator."
}

if (-not (Test-Path -LiteralPath $sourceWrapper)) {
    throw "Wrapper script not found: $sourceWrapper"
}

$installRoot = Get-MicrosludgeInstallRoot
Copy-MicrosludgePackageToInstallRoot -SourceRoot $repoRoot -InstallRoot $installRoot

$installedScriptsRoot = Join-Path $installRoot "Scripts"
$installedWrapper = Join-Path $installedScriptsRoot "Invoke-Microsludge-Degoblin-AfterWindowsUpdate.ps1"
$installedVersion = Get-MicrosludgeVersion -Root $installRoot
$installedLogRoot = Join-Path $installRoot "Logs"

if (-not (Test-Path -LiteralPath $installedWrapper)) {
    throw "Installed wrapper script not found: $installedWrapper"
}

New-Item -ItemType Directory -Force -Path $installedLogRoot | Out-Null
$startMenuFolder = Install-MicrosludgeStartMenuShortcuts -InstallRoot $installRoot
$installedAppRegistryPath = Register-MicrosludgeInstalledApp -InstallRoot $installRoot -Version $installedVersion

$switchValues = @{
    AlwaysApply = $AlwaysApply.IsPresent
    BlockOneDrive = $BlockOneDrive.IsPresent
    RemoveOneDrive = $RemoveOneDrive.IsPresent
    RemoveWidgets = $RemoveWidgets.IsPresent
    DisableEdgeUpdates = $DisableEdgeUpdates.IsPresent
    DisableWindowsAI = $DisableWindowsAI.IsPresent
    PinDocuments = $PinDocuments.IsPresent
    SkipCopilot = $SkipCopilot.IsPresent
    SkipOneDrive = $SkipOneDrive.IsPresent
    SkipEdge = $SkipEdge.IsPresent
    SkipOutlook = $SkipOutlook.IsPresent
    SkipConsumerContent = $SkipConsumerContent.IsPresent
}

$taskArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-WindowStyle",
    "Hidden",
    "-File",
    ('"{0}"' -f $installedWrapper)
) + (Get-MicrosludgeSwitchArgumentList -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames))

$argument = $taskArguments -join " "
$optionSummary = Get-MicrosludgeOptionSummary -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames)

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $argument `
    -WorkingDirectory $installRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$trigger.Delay = "PT2M"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

$principal = New-ScheduledTaskPrincipal `
    -UserId $userId `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -TaskPath $taskPath `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Runs Microsludge Degoblin $installedVersion after logon only when Windows Update evidence is found. Options: $optionSummary." `
    -Force | Out-Null

$newSwitches = @(Update-MicrosludgeKnownSwitches -InstallRoot $installRoot)

Write-Host "Installed package copy: $installRoot"
Write-Host "Installed version: $installedVersion"
Write-Host "Scheduled task wrapper: $installedWrapper"
Write-Host "Installed logs: $installedLogRoot"
Write-Host "Start Menu folder: $startMenuFolder"
Write-Host "Apps entry: $installedAppRegistryPath"

if ($newSwitches.Count -gt 0) {
    Write-Host ""
    Write-Host "New option(s) since your last install:"
    foreach ($switchName in $newSwitches) {
        Write-Host "  -$switchName : $(Get-MicrosludgeSwitchDescription -Name $switchName)"
    }
    Write-Host "These stay off until you choose them in the GUI or console walkthrough."
}

Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath |
    Select-Object TaskName, TaskPath, State
