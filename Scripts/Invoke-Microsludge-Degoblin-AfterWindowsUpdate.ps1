<#
Runs Microsludge-Degoblin.ps1 only when Windows Update evidence is found.

This wrapper is meant for Task Scheduler. It logs either the Windows Update evidence it
found or the reason it skipped the run. Use -AlwaysApply to bypass the Windows
Update evidence gate and run at every scheduled launch.
#>

param(
    [switch]$TestOnly,
    [switch]$AlwaysApply,
    [switch]$BlockOneDrive,
    [switch]$RemoveOneDrive,
    [switch]$RemoveWidgets,
    [switch]$DisableEdgeUpdates,
    [switch]$DisableWindowsAI,
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
$targetScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$logRoot = Join-Path $repoRoot "Logs"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = Join-Path $logRoot "Microsludge-Degoblin-Auto-$timestamp.log"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

function Write-AutoLog {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Output $line
    Add-Content -Path $logPath -Value $line
}

function Get-LastBootTime {
    return (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
}

function Get-WindowsUpdateRebootEvidence {
    param([datetime]$LastBootTime)

    $evidence = New-Object System.Collections.Generic.List[string]
    $now = Get-Date
    $preBootStart = $LastBootTime.AddHours(-24)
    $postBootEnd = $LastBootTime.AddHours(2)
    if ($postBootEnd -gt $now) {
        $postBootEnd = $now
    }

    $updatePattern = "Windows Update|UpdateOrchestrator|UsoClient|MoUsoCoreWorker|MusNotification|hotfix|servicing|service pack|reboot|restart|required|successfully installed|installation successful"

    try {
        $restartEvents = Get-WinEvent -FilterHashtable @{
            LogName = "System"
            Id = 1074
            StartTime = $preBootStart
            EndTime = $LastBootTime.AddMinutes(10)
        } -ErrorAction SilentlyContinue

        foreach ($event in $restartEvents) {
            if ($event.Message -match $updatePattern) {
                $evidence.Add("System event 1074 at $($event.TimeCreated): $($event.ProviderName)")
            }
        }
    } catch {
        $evidence.Add("Unable to inspect System restart events: $($_.Exception.Message)")
    }

    try {
        $updateEvents = Get-WinEvent -FilterHashtable @{
            LogName = "Microsoft-Windows-WindowsUpdateClient/Operational"
            StartTime = $preBootStart
            EndTime = $postBootEnd
        } -MaxEvents 200 -ErrorAction SilentlyContinue

        foreach ($event in $updateEvents) {
            if ($event.Message -match $updatePattern) {
                $evidence.Add("WindowsUpdateClient event $($event.Id) at $($event.TimeCreated)")
            }
        }
    } catch {
        Write-AutoLog "Windows Update operational log unavailable: $($_.Exception.Message)"
    }

    $pendingRebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    try {
        if (Test-Path -LiteralPath $pendingRebootKey) {
            $evidence.Add("Windows Update pending-reboot key present (WU has queued updates requiring a reboot): $pendingRebootKey")
        }
    } catch {
        Write-AutoLog "Windows Update pending-reboot registry key unavailable: $($_.Exception.Message)"
    }

    return $evidence | Select-Object -First 8
}

$switchValues = @{
    AlwaysApply = $AlwaysApply.IsPresent
    BlockOneDrive = $BlockOneDrive.IsPresent
    RemoveOneDrive = $RemoveOneDrive.IsPresent
    RemoveWidgets = $RemoveWidgets.IsPresent
    DisableEdgeUpdates = $DisableEdgeUpdates.IsPresent
    DisableWindowsAI = $DisableWindowsAI.IsPresent
    SkipCopilot = $SkipCopilot.IsPresent
    SkipOneDrive = $SkipOneDrive.IsPresent
    SkipEdge = $SkipEdge.IsPresent
    SkipOutlook = $SkipOutlook.IsPresent
    SkipConsumerContent = $SkipConsumerContent.IsPresent
}

$optionSummary = Get-MicrosludgeOptionSummary -Values $switchValues -Names (Get-MicrosludgeWrapperSwitchNames)
$packageVersion = Get-MicrosludgeVersion -Root $repoRoot

Write-AutoLog "Starting automated Microsludge Degoblin check."
Write-AutoLog "Version: $packageVersion"
Write-AutoLog "Mode: $(if ($TestOnly) { 'TEST ONLY' } elseif ($AlwaysApply) { 'APPLY AT EVERY SCHEDULED LAUNCH' } else { 'APPLY IF WINDOWS UPDATE EVIDENCE IS FOUND' })"
Write-AutoLog "Options: $optionSummary"
Write-AutoLog "Wrapper log: $logPath"

Remove-MicrosludgeOldLogs `
    -LogRoot $logRoot `
    -KeepMostRecent 20 `
    -OlderThanDays 90 `
    -ExcludePath $logPath `
    -Logger { param($Message) Write-AutoLog $Message }

$installRootForUpdateCheck = Get-MicrosludgeInstallRoot

try {
    $updateStatus = Test-MicrosludgeUpdateAvailable -InstallRoot $installRootForUpdateCheck -CurrentVersion $packageVersion
    if ($updateStatus.UpdateAvailable) {
        Write-AutoLog "NOTICE: A newer Microsludge Degoblin release is available: $($updateStatus.LatestVersion) (installed: $($updateStatus.CurrentVersion)). Get it from https://github.com/jtcristina/Microsludge-Degoblin/releases"
        Show-MicrosludgeBalloonNotification `
            -Title "Microsludge Degoblin update available" `
            -Message "v$($updateStatus.LatestVersion) is out (you have v$($updateStatus.CurrentVersion)). Check the Releases page when you get a chance." `
            -Icon "Info" | Out-Null
    } elseif ($updateStatus.Checked) {
        Write-AutoLog "Installed version is current (checked GitHub: $($updateStatus.LatestVersion))."
    }
} catch {
    Write-AutoLog "WARNING: Update check failed: $($_.Exception.Message)"
}

$updateState = Get-MicrosludgeUpdateState -InstallRoot $installRootForUpdateCheck
if ($updateState -and @($updateState.PendingAcknowledgment).Count -gt 0) {
    Write-AutoLog "NOTICE: New option(s) awaiting review: $(@($updateState.PendingAcknowledgment) -join ', '). Open the GUI or console walkthrough to decide."
}

if (-not (Test-Path -LiteralPath $targetScript)) {
    Write-AutoLog "ERROR: Target script not found: $targetScript"
    exit 1
}

$lastBootTime = Get-LastBootTime
Write-AutoLog "Last boot time: $lastBootTime"

if ($AlwaysApply) {
    Write-AutoLog "AlwaysApply requested. Skipping Windows Update evidence gate."
} else {
    $evidence = @(Get-WindowsUpdateRebootEvidence -LastBootTime $lastBootTime)
    if ($evidence.Count -eq 0) {
        Write-AutoLog "No Windows Update evidence found. Skipping cleanup script."
        exit 0
    }

    Write-AutoLog "Windows Update evidence found:"
    foreach ($item in $evidence) {
        Write-AutoLog "  $item"
    }
}

if ($TestOnly) {
    Write-AutoLog "TestOnly requested. Skipping Microsludge-Degoblin.ps1 -Apply."
    exit 0
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $targetScript,
    "-Apply"
)

$arguments += Get-MicrosludgeSwitchArgumentList -Values $switchValues -Names (Get-MicrosludgeCleanupSwitchNames)

Write-AutoLog "Running Microsludge-Degoblin.ps1 -Apply with options: $optionSummary"
& powershell.exe @arguments *>&1 |
    ForEach-Object {
        $line = "$_"
        Write-Output $line
        Add-Content -Path $logPath -Value $line
    }

$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) {
    $exitCode = 0
}

Write-AutoLog "Microsludge-Degoblin exit code: $exitCode"
exit $exitCode

