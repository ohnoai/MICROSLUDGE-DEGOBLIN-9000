<#
Interactive walkthrough for Microsludge Degoblin.

This launcher does not hide what it runs. It refuses to continue without admin,
shows the selected command, asks for confirmation before apply/removal paths,
and then delegates to the real scripts.
#>

param(
    [switch]$Wizard
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$helpers = Join-Path $scriptRoot "Microsludge-Degoblin.Helpers.ps1"
$mainScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$installerScript = Join-Path $scriptRoot "Install-Microsludge-DegoblinTask.ps1"
$uninstallerScript = Join-Path $scriptRoot "Uninstall-Microsludge-DegoblinTask.ps1"
$windowsAITestScript = Join-Path $scriptRoot "Test-Microsludge-WindowsAI.ps1"
$walkthroughText = Join-Path $repoRoot "WALKTHROUGH.txt"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

function Invoke-CommandPreview {
    param(
        [string]$Label,
        [string]$ScriptPath,
        [string[]]$ExtraArgs,
        [string]$ConfirmationWord,
        [switch]$OfferRestorePoint
    )

    $effectiveExtraArgs = @($ExtraArgs)
    if ($OfferRestorePoint -and -not ($effectiveExtraArgs -contains "-SkipRestorePoint")) {
        $effectiveExtraArgs += "-SkipRestorePoint"
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Host ""
        Write-Host "Missing script: $ScriptPath"
        return
    }

    $displayArgs = @(
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $effectiveExtraArgs

    Write-Host ""
    Write-Host $Label
    Write-Host ($displayArgs -join " ")

    if ($ConfirmationWord) {
        Write-Host ""
        $answer = Read-Host "Type $ConfirmationWord to continue"
        if ($answer -ne $ConfirmationWord) {
            Write-Host "Skipped."
            return
        }
    }

    if ($OfferRestorePoint) {
        $createRestorePoint = Read-WizardYesNo `
            -Question "Create a Windows restore point before continuing?" `
            -DefaultYes $true `
            -Explanation "Recommended before apply. This can fail if System Protection is off or Windows recently created a restore point."

        if ($createRestorePoint) {
            $restorePointCreated = New-MicrosludgeRestorePoint -Writer { param($Message) Write-Host $Message }
            if (-not $restorePointCreated) {
                $continueAfterFailure = Read-WizardYesNo `
                    -Question "Restore point was not created. Continue anyway?" `
                    -DefaultYes $false `
                    -Explanation "Pick no if you want to enable System Protection or create a restore point manually first."
                if (-not $continueAfterFailure) {
                    Write-Host "Skipped."
                    return
                }
            }
        }
    }

    $runArgs = @(
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $ScriptPath
    ) + $effectiveExtraArgs

    & powershell.exe @runArgs
}

function Show-Banner {
    $banner = @'
>< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><
>< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><
 __  __ ___ ___ ___  ___  ___ _    _   _ ___   ___ ___          ,      ,
|  \/  |_ _/ __| _ \/ _ \/ __| |  | | | |   \ / __| __|        /(.-""-.)\
| |\/| || | (__|   / (_) \__ \ |__| |_| | |) | (_ | _|     |\  \/      \/  /|
|_|  |_|___\___|_|_\\___/|___/_____\___/|___/ \___|___|    | \ / =.  .= \ / |
 ____  _____ ____  ___  ____  _     ___ _   _              \( \   o\/o   / )/
|  _ \| ____/ ___|/ _ \| __ )| |   |_ _| \ | |              \_, '-/  \-' ,_/
| | | |  _|| |  _| | | |  _ \| |    | ||  \| |                /   \__/   \
| |_| | |__| |_| | |_| | |_) | |___ | || |\  |                \ \__/\__/ /
|____/|_____\____|\___/|____/|_____|___|_| \_| 9000         ___\ \|--|/ /___
                                                          /`    \      /    `\
Windows Update resurrected something stupid again...             '----'
>< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><
>< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><
'@ -split "`r?`n"

    foreach ($line in $banner) {
        Write-Host $line
    }
}

function Read-WizardChoice {
    param(
        [string]$Prompt,
        [string[]]$Allowed
    )

    while ($true) {
        $answer = Read-Host $Prompt
        if ($null -eq $answer) {
            $answer = ""
        }

        $choice = $answer.Trim().ToUpperInvariant()
        if ($Allowed -contains $choice) {
            return $choice
        }

        Write-Host "Pick one of: $($Allowed -join ', ')."
    }
}

function Read-WizardYesNo {
    param(
        [string]$Question,
        [bool]$DefaultYes,
        [string]$Explanation
    )

    Write-Host ""
    if ($Explanation) {
        Write-Host $Explanation
    }

    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $answer = Read-Host "$Question $suffix"
        if ($null -eq $answer) {
            $answer = ""
        }

        $normalized = $answer.Trim().ToLowerInvariant()
        if ($normalized -eq "") {
            return $DefaultYes
        }

        if (@("y", "yes") -contains $normalized) {
            return $true
        }

        if (@("n", "no") -contains $normalized) {
            return $false
        }

        Write-Host "Answer yes or no."
    }
}

function Format-CommandLine {
    param(
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    $parts = @(
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $ExtraArgs

    return $parts -join " "
}

function Show-LatestCleanupLog {
    param(
        [datetime]$After
    )

    $logRoot = Join-Path $repoRoot "Logs"
    $latestLog = Get-ChildItem -Path $logRoot -Filter "Microsludge-Degoblin-*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $After } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestLog) {
        Get-Content -LiteralPath $latestLog.FullName | more
    } else {
        Write-Host "No log file found from this session."
    }
}

function Start-DryRunFollowUp {
    param(
        [string[]]$CleanupArgs,
        [datetime]$DryRunStartedAt
    )

    $savedCleanupArgs = @($CleanupArgs)

    while ($true) {
        Write-Host ""
        Write-Host "Dry Run Follow-Up"
        Write-Host ""
        Write-Host "1. Review the dry-run log - highly recommended before changing anything"
        Write-Host "2. Apply these exact selections now"
        Write-Host "3. Apply now and install task for when Windows Update runs - highly recommended"
        Write-Host "4. Apply now and install task that runs at every logon"
        Write-Host "Q. Return"
        Write-Host ""

        $choice = Read-WizardChoice -Prompt "Choose next step" -Allowed @("1", "2", "3", "4", "Q")
        $applyArgs = @("-Apply") + $savedCleanupArgs
        $confirmationWord = if ($savedCleanupArgs -contains "-RemoveOneDrive") { "REMOVE" } else { "APPLY" }

        switch ($choice) {
            "1" {
                Show-LatestCleanupLog -After $DryRunStartedAt
            }
            "2" {
                Invoke-CommandPreview `
                    -Label "Apply these exact dry-run selections:" `
                    -ScriptPath $mainScript `
                    -ExtraArgs $applyArgs `
                    -ConfirmationWord $confirmationWord `
                    -OfferRestorePoint

                return
            }
            "3" {
                Invoke-CommandPreview `
                    -Label "Step 1 of 2: Install post-update scheduled task (Windows Update-aware):" `
                    -ScriptPath $installerScript `
                    -ExtraArgs $savedCleanupArgs `
                    -ConfirmationWord "INSTALL"

                Invoke-CommandPreview `
                    -Label "Step 2 of 2: Apply these exact dry-run selections:" `
                    -ScriptPath $mainScript `
                    -ExtraArgs $applyArgs `
                    -ConfirmationWord $confirmationWord `
                    -OfferRestorePoint

                return
            }
            "4" {
                $alwaysApplyInstallArgs = @("-AlwaysApply") + @($savedCleanupArgs)

                Invoke-CommandPreview `
                    -Label "Step 1 of 2: Install every-logon scheduled task:" `
                    -ScriptPath $installerScript `
                    -ExtraArgs $alwaysApplyInstallArgs `
                    -ConfirmationWord "INSTALL"

                Invoke-CommandPreview `
                    -Label "Step 2 of 2: Apply these exact dry-run selections:" `
                    -ScriptPath $mainScript `
                    -ExtraArgs $applyArgs `
                    -ConfirmationWord $confirmationWord `
                    -OfferRestorePoint

                return
            }
            "Q" {
                return
            }
        }
    }
}

function Start-Wizard {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "Microsludge Degoblin Wizard"
    Write-Host ""
    Write-Host "This will ask what to include, explain the stronger options, show the exact command,"
    Write-Host "and ask for confirmation before doing anything that changes the machine."
    Write-Host ""
    Write-Host "Run modes:"
    Write-Host "  1. Dry run now: highly recommended first. Logs what would change, changes nothing."
    Write-Host "  2. Apply now: recommended after reviewing dry run. Offers a restore point, then performs the selected cleanup."
    Write-Host "  3. Install post-update task: highly recommended after your choices look right. Copies this package to ProgramData and saves these choices for automatic cleanup when Windows Update evidence is found."
    Write-Host "  4. Uninstall post-update task: removes the saved automatic cleanup task and installed ProgramData copy."
    Write-Host "  5. Test for Windows AI targets: report only, changes nothing."
    Write-Host "  Q. Quit"
    Write-Host ""

    $modeChoice = Read-WizardChoice -Prompt "Choose run mode" -Allowed @("1", "2", "3", "4", "5", "Q")
    if ($modeChoice -eq "Q") {
        Write-Host "Wizard cancelled."
        return
    }

    $modeName = switch ($modeChoice) {
        "1" { "Dry run now" }
        "2" { "Apply now" }
        "3" { "Install post-update task" }
        "4" { "Uninstall post-update task" }
        "5" { "Test for Windows AI targets" }
    }

    if ($modeChoice -eq "4") {
        Write-Host ""
        Write-Host "This removes the saved scheduled task and installed ProgramData copy. It does not undo previous cleanup changes."
        Write-Host ""
        Write-Host "Command:"
        Write-Host (Format-CommandLine -ScriptPath $uninstallerScript -ExtraArgs @())

        Invoke-CommandPreview `
            -Label "Uninstalling post-update scheduled task:" `
            -ScriptPath $uninstallerScript `
            -ExtraArgs @() `
            -ConfirmationWord "UNINSTALL"

        return
    }

    if ($modeChoice -eq "5") {
        Write-Host ""
        Write-Host "This checks for known Windows AI policy values, Recall optional feature state,"
        Write-Host "related Appx packages, and related running processes. It does not change anything."
        Write-Host ""
        Write-Host "Command:"
        Write-Host (Format-CommandLine -ScriptPath $windowsAITestScript -ExtraArgs @())

        Invoke-CommandPreview `
            -Label "Running Windows AI detection report:" `
            -ScriptPath $windowsAITestScript `
            -ExtraArgs @() `
            -ConfirmationWord $null

        return
    }

    Write-Host ""
    Write-Host "Step 1: choose cleanup targets."

    $alwaysApply = $false
    if ($modeChoice -eq "3") {
        $alwaysApply = Read-WizardYesNo `
            -Question "Run the scheduled task at every logon instead of only when Windows Update evidence is found?" `
            -DefaultYes $false `
            -Explanation "Highly recommended default: no, use Windows Update-aware mode. Pick yes only if this should run at every logon."
    }

    Write-Host ""
    Write-Host "Preflight: Windows AI detection report."
    Write-Host "This checks for Recall, Click to Do, Settings AI agent, Paint AI policy targets,"
    Write-Host "related packages, and related running processes before deciding whether to ask"
    Write-Host "about Windows AI cleanup."
    Write-Host ""

    $windowsAIDetection = Get-MicrosludgeWindowsAIDetection
    Write-MicrosludgeWindowsAIReport -Detection $windowsAIDetection
    $windowsAITargetFound = Test-MicrosludgeWindowsAITargetFound -Detection $windowsAIDetection

    $disableWindowsAI = $false
    if ($windowsAITargetFound) {
        $disableWindowsAI = Read-WizardYesNo `
            -Question "Include Windows AI cleanup?" `
            -DefaultYes $false `
            -Explanation "Opt-in policy cleanup. Recommended if: targets were found and you want Recall, Click to Do, Settings AI agent, and Paint AI features disabled by policy. Does not remove Recall optional feature bits."
    } else {
        Write-Host ""
        Write-Host "No Windows AI targets were found, so the Windows AI cleanup option is omitted."
    }

    $includeCopilot = Read-WizardYesNo `
        -Question "Include Copilot cleanup?" `
        -DefaultYes $true `
        -Explanation "Highly recommended: removes installed and provisioned Copilot packages and sets Windows Copilot off policies."

    $includeOneDrive = Read-WizardYesNo `
        -Question "Include OneDrive startup cleanup?" `
        -DefaultYes $true `
        -Explanation "Highly recommended: stops OneDrive if running, removes OneDrive startup entries, and disables OneDrive scheduled tasks. This does not uninstall OneDrive."

    $blockOneDrive = $false
    $removeOneDrive = $false
    if ($includeOneDrive) {
        $blockOneDrive = Read-WizardYesNo `
            -Question "Block OneDrive file sync by policy?" `
            -DefaultYes $false `
            -Explanation "Stronger option. Recommended if: OneDrive sync should stay blocked at the machine-policy level."

        $removeOneDrive = Read-WizardYesNo `
            -Question "Uninstall OneDrive when the local uninstaller is found?" `
            -DefaultYes $false `
            -Explanation "Strongest OneDrive option. Recommended if: you want OneDrive removed, not just kept out of startup."
    }

    $includeEdge = Read-WizardYesNo `
        -Question "Include Edge background cleanup?" `
        -DefaultYes $true `
        -Explanation "Highly recommended: removes Edge GameAssist, blocks Edge startup boost, background mode, and sidebar behavior by policy. Does not remove Edge itself."

    $disableEdgeUpdates = $false
    if ($includeEdge) {
        $disableEdgeUpdates = Read-WizardYesNo `
            -Question "Disable Edge update services and scheduled tasks?" `
            -DefaultYes $false `
            -Explanation "Stronger option. Recommended if: you want Edge and WebView2 update tasks and services disabled. This can affect Edge and WebView2 update freshness."
    }

    $includeOutlook = Read-WizardYesNo `
        -Question "Include new Outlook cleanup?" `
        -DefaultYes $true `
        -Explanation "Recommended if: you do not use the new standalone Outlook app (Microsoft.OutlookForWindows). This does not affect classic Office or Microsoft 365 Outlook."

    $includeConsumerContent = Read-WizardYesNo `
        -Question "Include Microsoft ads, suggestions, widgets, and SoftLanding cleanup?" `
        -DefaultYes $true `
        -Explanation "Highly recommended: low-risk cleanup for noisy Windows ads, suggestions, search highlights, widgets/news, activity upload, and SoftLanding tasks. Also stops the Widgets platform background process each run."

    $wizardInstallTask = $false
    $wizardAlwaysApply = $false
    if ($modeChoice -eq "2") {
        $wizardInstallTask = Read-WizardYesNo `
            -Question "Also install the post-update scheduled task?" `
            -DefaultYes $true `
            -Explanation "Highly recommended if you haven't already. Copies the package to C:\ProgramData\Microsludge-Degoblin and runs cleanup automatically after future Windows Updates. This is separate from the cleanup about to run."

        if ($wizardInstallTask) {
            $wizardAlwaysApply = Read-WizardYesNo `
                -Question "Run the task at every logon instead of only when Windows Update evidence is found?" `
                -DefaultYes $false `
                -Explanation "Highly recommended default: no, use Windows Update-aware mode. Choose yes only if you want routine cleanup at every logon."
        }
    }

    $selectedSwitches = @{
        AlwaysApply = $alwaysApply
        BlockOneDrive = $blockOneDrive
        RemoveOneDrive = $removeOneDrive
        DisableEdgeUpdates = $disableEdgeUpdates
        DisableWindowsAI = $disableWindowsAI
        SkipCopilot = -not $includeCopilot
        SkipOneDrive = -not $includeOneDrive
        SkipEdge = -not $includeEdge
        SkipOutlook = -not $includeOutlook
        SkipConsumerContent = -not $includeConsumerContent
    }

    $switchNames = if ($modeChoice -eq "3") {
        Get-MicrosludgeWrapperSwitchNames
    } else {
        Get-MicrosludgeCleanupSwitchNames
    }

    $extraArgs = @()
    if ($modeChoice -eq "2") {
        $extraArgs += "-Apply"
    }
    $extraArgs += Get-MicrosludgeSwitchArgumentList -Values $selectedSwitches -Names $switchNames

    $installBeforeApplyArgs = Get-MicrosludgeSwitchArgumentList -Values $selectedSwitches -Names (Get-MicrosludgeCleanupSwitchNames)

    $taskInstallArgs = @($installBeforeApplyArgs)
    if ($wizardAlwaysApply) {
        $taskInstallArgs = @("-AlwaysApply") + $taskInstallArgs
    }

    $scriptPath = if ($modeChoice -eq "3") { $installerScript } else { $mainScript }
    $confirmationWord = $null
    if ($modeChoice -eq "2") {
        $confirmationWord = if ($removeOneDrive) { "REMOVE" } else { "APPLY" }
    } elseif ($modeChoice -eq "3") {
        $confirmationWord = "INSTALL"
    }

    Write-Host ""
    Write-Host "Step 2: review your choices."
    Write-Host "  Mode: $modeName"
    if ($modeChoice -eq "3") {
        Write-Host "  Run at every logon: $alwaysApply"
    }
    Write-Host "  Windows AI targets found: $windowsAITargetFound"
    if ($windowsAITargetFound) {
        Write-Host "  Windows AI cleanup: $disableWindowsAI"
    } else {
        Write-Host "  Windows AI cleanup: omitted"
    }
    Write-Host "  Copilot cleanup: $includeCopilot"
    Write-Host "  OneDrive startup cleanup: $includeOneDrive"
    Write-Host "  Block OneDrive sync: $blockOneDrive"
    Write-Host "  Uninstall OneDrive: $removeOneDrive"
    Write-Host "  Edge background cleanup: $includeEdge"
    Write-Host "  Disable Edge updates: $disableEdgeUpdates"
    Write-Host "  New Outlook cleanup: $includeOutlook"
    Write-Host "  Ads/suggestions/widgets cleanup: $includeConsumerContent"
    if ($modeChoice -eq "2") {
        Write-Host "  Install scheduled task: $wizardInstallTask"
        if ($wizardInstallTask) {
            Write-Host "  Task mode: $(if ($wizardAlwaysApply) { 'every logon' } else { 'Windows Update-aware' })"
        }
    }
    Write-Host ""
    if ($modeChoice -eq "2" -and $wizardInstallTask) {
        Write-Host "Commands (installer runs first, then cleanup):"
        Write-Host (Format-CommandLine -ScriptPath $installerScript -ExtraArgs $taskInstallArgs)
        Write-Host (Format-CommandLine -ScriptPath $mainScript -ExtraArgs $extraArgs)
    } else {
        Write-Host "Command:"
        Write-Host (Format-CommandLine -ScriptPath $scriptPath -ExtraArgs $extraArgs)
    }

    if ($modeChoice -eq "1") {
        $runDryRun = Read-WizardYesNo `
            -Question "Run this dry run now?" `
            -DefaultYes $true `
            -Explanation "Dry run mode only reports what would change. After it completes, you will be offered options to review the log, apply, or install the scheduled task."

        if (-not $runDryRun) {
            Write-Host "Dry run skipped."
            return
        }
    }

    $label = switch ($modeChoice) {
        "1" { "Running wizard-selected dry run:" }
        "2" { "Running wizard-selected apply:" }
        "3" { "Installing wizard-selected post-update task:" }
    }

    $dryRunStartedAt = if ($modeChoice -eq "1") { Get-Date } else { $null }

    if ($modeChoice -eq "2" -and $wizardInstallTask) {
        Invoke-CommandPreview `
            -Label "Step 1 of 2: Install post-update scheduled task:" `
            -ScriptPath $installerScript `
            -ExtraArgs $taskInstallArgs `
            -ConfirmationWord "INSTALL"

        Invoke-CommandPreview `
            -Label "Step 2 of 2: Apply cleanup:" `
            -ScriptPath $mainScript `
            -ExtraArgs $extraArgs `
            -ConfirmationWord $confirmationWord `
            -OfferRestorePoint
    } else {
        Invoke-CommandPreview `
            -Label $label `
            -ScriptPath $scriptPath `
            -ExtraArgs $extraArgs `
            -ConfirmationWord $confirmationWord `
            -OfferRestorePoint:($modeChoice -eq "2")
    }

    if ($modeChoice -eq "1") {
        Start-DryRunFollowUp -CleanupArgs $installBeforeApplyArgs -DryRunStartedAt $dryRunStartedAt
    }
}

function Show-Menu {
    Clear-Host
    Show-Banner
    Write-Host ""
    Write-Host "Microsludge Degoblin Walkthrough"
    Write-Host ""
    Write-Host "Default apply does real cleanup for Copilot, OneDrive startup, new Outlook,"
    Write-Host "Edge background behavior, GameAssist, Microsoft consumer content, widgets,"
    Write-Host "and SoftLanding tasks."
    Write-Host ""
    Write-Host "Dry run logs what would change. Apply offers a restore point, then performs the changes."
    Write-Host ""
    Write-Host "1.  Guided step-by-step wizard - highly recommended"
    Write-Host "2.  Dry run default cleanup - highly recommended first"
    Write-Host "3.  Apply default cleanup - recommended after dry run"
    Write-Host "4.  Apply plus block OneDrive file sync - recommended if OneDrive sync should stay blocked"
    Write-Host "5.  Apply plus block OneDrive and disable Edge updates - stronger option"
    Write-Host "6.  Apply plus uninstall OneDrive - stronger option if startup cleanup is not enough"
    Write-Host "7.  Install post-update scheduled task - highly recommended after choices look right"
    Write-Host "8.  Install every-logon scheduled task - recommended only for routine startup cleanup"
    Write-Host "9.  Install post-update task with OneDrive block and Edge update disable"
    Write-Host "10. Uninstall scheduled task and installed copy"
    Write-Host "11. Test for Windows AI targets"
    Write-Host "12. Open walkthrough text"
    Write-Host "Q.  Quit"
    Write-Host ""
}

if (-not (Test-MicrosludgeIsAdmin)) {
    Write-Host "ERROR: Microsludge Degoblin must be run from an Administrator PowerShell window."
    Write-Host "Right-click PowerShell, choose Run as administrator, then rerun this command."
    Write-Host "No cleanup, dry run, or scheduled-task install was started."
    Write-Host ""
    exit 1
}

$installRoot = Get-MicrosludgeInstallRoot
$updateState = Get-MicrosludgeUpdateState -InstallRoot $installRoot
if ($updateState) {
    $packageVersion = Get-MicrosludgeVersion -Root $repoRoot
    if ($updateState.LatestKnownVersion -and $updateState.LatestKnownVersion -ne $packageVersion) {
        Write-Host "NOTICE: v$($updateState.LatestKnownVersion) is available on GitHub (you have v$packageVersion)."
        Write-Host "        https://github.com/ohnoai/MICROSLUDGE-DEGOBLIN-9000/releases"
        Write-Host ""
    }

    $pending = @($updateState.PendingAcknowledgment)
    if ($pending.Count -gt 0) {
        Write-Host "NOTICE: new option(s) since your last install:"
        foreach ($switchName in $pending) {
            Write-Host "  -$switchName : $(Get-MicrosludgeSwitchDescription -Name $switchName)"
        }
        Write-Host "These stay off until you choose them here or in the GUI, then reinstall the task to save the choice."
        Write-Host ""
        Clear-MicrosludgePendingAcknowledgment -InstallRoot $installRoot
    }
}

if ($Wizard) {
    Start-Wizard
    return
}

do {
    Show-Menu
    $choice = Read-Host "Choose"

    switch ($choice.ToUpperInvariant()) {
        "1" {
            Start-Wizard
        }
        "2" {
            Invoke-CommandPreview `
                -Label "Dry run default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @() `
                -ConfirmationWord $null
        }
        "3" {
            Invoke-CommandPreview `
                -Label "Apply default cleanup:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply") `
                -ConfirmationWord "APPLY" `
                -OfferRestorePoint
        }
        "4" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and block OneDrive file sync:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive") `
                -ConfirmationWord "APPLY" `
                -OfferRestorePoint
        }
        "5" {
            Invoke-CommandPreview `
                -Label "Apply cleanup, block OneDrive, and disable Edge updates:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "APPLY" `
                -OfferRestorePoint
        }
        "6" {
            Invoke-CommandPreview `
                -Label "Apply cleanup and uninstall OneDrive:" `
                -ScriptPath $mainScript `
                -ExtraArgs @("-Apply", "-RemoveOneDrive") `
                -ConfirmationWord "REMOVE" `
                -OfferRestorePoint
        }
        "7" {
            Invoke-CommandPreview `
                -Label "Install post-update scheduled task:" `
                -ScriptPath $installerScript `
                -ExtraArgs @() `
                -ConfirmationWord "INSTALL"
        }
        "8" {
            Invoke-CommandPreview `
                -Label "Install every-logon scheduled task:" `
                -ScriptPath $installerScript `
                -ExtraArgs @("-AlwaysApply") `
                -ConfirmationWord "INSTALL"
        }
        "9" {
            Invoke-CommandPreview `
                -Label "Install post-update task with OneDrive block and Edge update disable:" `
                -ScriptPath $installerScript `
                -ExtraArgs @("-BlockOneDrive", "-DisableEdgeUpdates") `
                -ConfirmationWord "INSTALL"
        }
        "10" {
            Invoke-CommandPreview `
                -Label "Uninstall scheduled task:" `
                -ScriptPath $uninstallerScript `
                -ExtraArgs @() `
                -ConfirmationWord "UNINSTALL"
        }
        "11" {
            Invoke-CommandPreview `
                -Label "Running Windows AI detection report:" `
                -ScriptPath $windowsAITestScript `
                -ExtraArgs @() `
                -ConfirmationWord $null
        }
        "12" {
            if (Test-Path -LiteralPath $walkthroughText) {
                Get-Content -LiteralPath $walkthroughText | more
            } else {
                Write-Host "Missing walkthrough: $walkthroughText"
            }
        }
        "Q" {
            return
        }
        default {
            Write-Host "Unknown choice."
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the menu"
} while ($true)

