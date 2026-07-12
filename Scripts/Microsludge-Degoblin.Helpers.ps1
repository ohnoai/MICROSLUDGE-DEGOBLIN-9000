function Test-MicrosludgeIsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MicrosludgeInstallRoot {
    return (Join-Path ([Environment]::GetFolderPath("CommonApplicationData")) "Microsludge-Degoblin")
}

function Get-MicrosludgeStartMenuFolder {
    return (Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "Microsludge Degoblin 9000")
}

function Get-MicrosludgeUninstallRegistryPath {
    return "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsludge-Degoblin"
}

function Get-MicrosludgeVersion {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return "unknown"
    }

    $versionPath = Join-Path $Root "VERSION"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        return "unknown"
    }

    try {
        $version = Get-Content -LiteralPath $versionPath -TotalCount 1 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($version)) {
            return "unknown"
        }

        return $version.Trim()
    } catch {
        return "unknown"
    }
}

function New-MicrosludgeRestorePoint {
    param(
        [string]$Description = "Microsludge Degoblin before cleanup",
        [scriptblock]$Writer
    )

    if ($Writer) {
        & $Writer "Creating Windows restore point: $Description"
    }

    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        if ($Writer) {
            & $Writer "WARNING: Restore point was not created. Checkpoint-Computer is unavailable in this PowerShell session."
        }
        return $false
    }

    try {
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        if ($Writer) {
            & $Writer "Restore point requested. Windows may reuse a recent restore point instead of creating a new one."
        }
        return $true
    } catch {
        if ($Writer) {
            & $Writer "WARNING: Restore point was not created: $($_.Exception.Message)"
            & $Writer "WARNING: System Protection may be off, or Windows may be limiting restore point creation."
        }
        return $false
    }
}

function Get-MicrosludgeCleanupSwitchNames {
    return @(
        "BlockOneDrive",
        "RemoveOneDrive",
        "RemoveWidgets",
        "DisableEdgeUpdates",
        "DisableWindowsAI",
        "SkipCopilot",
        "SkipOneDrive",
        "SkipEdge",
        "SkipOutlook",
        "SkipConsumerContent"
    )
}

function Get-MicrosludgeWrapperSwitchNames {
    return @("AlwaysApply") + (Get-MicrosludgeCleanupSwitchNames)
}

function Get-MicrosludgeSwitchArgumentList {
    param(
        [hashtable]$Values,
        [string[]]$Names
    )

    $arguments = @()
    foreach ($name in $Names) {
        if ($Values.ContainsKey($name) -and [bool]$Values[$name]) {
            $arguments += "-$name"
        }
    }

    return $arguments
}

function Get-MicrosludgeOptionSummary {
    param(
        [hashtable]$Values,
        [string[]]$Names
    )

    $enabled = @()
    foreach ($name in $Names) {
        if ($Values.ContainsKey($name) -and [bool]$Values[$name]) {
            $enabled += $name
        }
    }

    if ($enabled.Count -eq 0) {
        return "default"
    }

    return $enabled -join ", "
}

function Get-MicrosludgeSwitchDescription {
    param([string]$Name)

    $descriptions = @{
        BlockOneDrive = "Blocks OneDrive file sync by machine policy."
        RemoveOneDrive = "Uninstalls OneDrive when a local installer is found."
        RemoveWidgets = "Removes the Widgets Platform Runtime package outright, not just its background process."
        DisableEdgeUpdates = "Disables Edge update scheduled tasks and services."
        DisableWindowsAI = "Disables Recall, Click to Do, Settings AI agent, and Paint AI policies."
        SkipCopilot = "Skips Copilot package and policy cleanup."
        SkipOneDrive = "Skips OneDrive process/startup/task cleanup."
        SkipEdge = "Skips Edge background/startup/GameAssist cleanup."
        SkipOutlook = "Skips new Outlook package cleanup."
        SkipConsumerContent = "Skips ads/suggestions/widgets/search-highlights cleanup."
        AlwaysApply = "Runs cleanup at every logon instead of only after Windows Update evidence."
    }

    if ($descriptions.ContainsKey($Name)) {
        return $descriptions[$Name]
    }

    return "New option. See README.md or WALKTHROUGH.txt for details."
}

function Get-MicrosludgeUpdateStatePath {
    param([string]$InstallRoot)

    return (Join-Path $InstallRoot "Update-State.json")
}

function Get-MicrosludgeUpdateState {
    param([string]$InstallRoot)

    $path = Get-MicrosludgeUpdateStatePath -InstallRoot $InstallRoot
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    try {
        return (Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Set-MicrosludgeUpdateState {
    param(
        [string]$InstallRoot,
        [hashtable]$Updates
    )

    $existing = Get-MicrosludgeUpdateState -InstallRoot $InstallRoot
    $state = [ordered]@{
        KnownSwitchNames = @()
        PendingAcknowledgment = @()
        LastGitHubCheckAt = $null
        LatestKnownVersion = $null
    }

    if ($existing) {
        foreach ($key in @($state.Keys)) {
            if ($existing.PSObject.Properties.Name -contains $key) {
                $state[$key] = $existing.$key
            }
        }
    }

    foreach ($key in $Updates.Keys) {
        $state[$key] = $Updates[$key]
    }

    $state["SavedAt"] = (Get-Date -Format "o")

    $path = Get-MicrosludgeUpdateStatePath -InstallRoot $InstallRoot
    ($state | ConvertTo-Json) | Set-Content -LiteralPath $path -Encoding UTF8

    return $state
}

function Update-MicrosludgeKnownSwitches {
    param([string]$InstallRoot)

    $current = @(Get-MicrosludgeWrapperSwitchNames)
    $existing = Get-MicrosludgeUpdateState -InstallRoot $InstallRoot

    if (-not $existing) {
        Set-MicrosludgeUpdateState -InstallRoot $InstallRoot -Updates @{
            KnownSwitchNames = $current
            PendingAcknowledgment = @()
        } | Out-Null
        return @()
    }

    $previousKnown = @($existing.KnownSwitchNames)
    $previousPending = @($existing.PendingAcknowledgment)
    $newlyDiscovered = @($current | Where-Object { $_ -notin $previousKnown })
    $mergedPending = @($previousPending + $newlyDiscovered | Select-Object -Unique)

    Set-MicrosludgeUpdateState -InstallRoot $InstallRoot -Updates @{
        KnownSwitchNames = $current
        PendingAcknowledgment = $mergedPending
    } | Out-Null

    return $newlyDiscovered
}

function Clear-MicrosludgePendingAcknowledgment {
    param([string]$InstallRoot)

    Set-MicrosludgeUpdateState -InstallRoot $InstallRoot -Updates @{
        PendingAcknowledgment = @()
    } | Out-Null
}

function Compare-MicrosludgeVersion {
    param(
        [string]$Left,
        [string]$Right
    )

    function ConvertTo-MicrosludgeVersionParts {
        param([string]$Value)

        $core = ($Value -split '-')[0]
        $parts = @($core -split '\.' | ForEach-Object {
            $n = 0
            [void][int]::TryParse($_, [ref]$n)
            $n
        })
        while ($parts.Count -lt 3) {
            $parts += 0
        }
        return $parts
    }

    $leftParts = ConvertTo-MicrosludgeVersionParts -Value $Left
    $rightParts = ConvertTo-MicrosludgeVersionParts -Value $Right

    for ($i = 0; $i -lt 3; $i++) {
        if ($leftParts[$i] -gt $rightParts[$i]) { return 1 }
        if ($leftParts[$i] -lt $rightParts[$i]) { return -1 }
    }

    return 0
}

function Test-MicrosludgeUpdateAvailable {
    param(
        [string]$InstallRoot,
        [string]$CurrentVersion,
        [string]$RepoSlug = "jtcristina/Microsludge-Degoblin",
        [int]$CacheHours = 24,
        [switch]$Force
    )

    $state = Get-MicrosludgeUpdateState -InstallRoot $InstallRoot
    $now = Get-Date

    $shouldCheck = $Force.IsPresent
    if (-not $shouldCheck) {
        if (-not $state -or -not $state.LastGitHubCheckAt) {
            $shouldCheck = $true
        } else {
            try {
                $lastChecked = [datetime]$state.LastGitHubCheckAt
                if (($now - $lastChecked).TotalHours -ge $CacheHours) {
                    $shouldCheck = $true
                }
            } catch {
                $shouldCheck = $true
            }
        }
    }

    $latestVersion = if ($state) { $state.LatestKnownVersion } else { $null }

    if ($shouldCheck) {
        try {
            $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            try {
                $response = Invoke-RestMethod `
                    -Uri "https://api.github.com/repos/$RepoSlug/releases/latest" `
                    -Headers @{ "User-Agent" = "Microsludge-Degoblin" } `
                    -TimeoutSec 10 `
                    -ErrorAction Stop
            } finally {
                [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
            }

            $latestVersion = ($response.tag_name -replace '^v', '')
            Set-MicrosludgeUpdateState -InstallRoot $InstallRoot -Updates @{
                LastGitHubCheckAt = $now.ToString("o")
                LatestKnownVersion = $latestVersion
            } | Out-Null
        } catch {
            if (-not $state) {
                return [pscustomobject]@{
                    Checked = $false
                    UpdateAvailable = $false
                    LatestVersion = $null
                    CurrentVersion = $CurrentVersion
                    Error = $_.Exception.Message
                }
            }
        }
    }

    $updateAvailable = ($latestVersion -and (Compare-MicrosludgeVersion -Left $latestVersion -Right $CurrentVersion) -gt 0)

    return [pscustomobject]@{
        Checked = $shouldCheck
        UpdateAvailable = $updateAvailable
        LatestVersion = $latestVersion
        CurrentVersion = $CurrentVersion
    }
}

function Show-MicrosludgeBalloonNotification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info", "Warning")]
        [string]$Icon = "Info"
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        $notifyIcon.Visible = $true
        $notifyIcon.BalloonTipTitle = $Title
        $notifyIcon.BalloonTipText = $Message
        $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
        $notifyIcon.ShowBalloonTip(10000)

        Start-Sleep -Seconds 6
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Remove-MicrosludgeOldLogs {
    param(
        [string]$LogRoot,
        [int]$KeepMostRecent = 20,
        [int]$OlderThanDays = 90,
        [string]$ExcludePath,
        [scriptblock]$Logger
    )

    if (-not (Test-Path -LiteralPath $LogRoot)) {
        return
    }

    $excludedFullName = $null
    if ($ExcludePath) {
        try {
            $excludedFullName = (Resolve-Path -LiteralPath $ExcludePath -ErrorAction SilentlyContinue).Path
        } catch {
            $excludedFullName = $null
        }
    }

    $logs = @(Get-ChildItem -LiteralPath $LogRoot -Filter "*.log" -File -ErrorAction SilentlyContinue |
        Where-Object { -not $excludedFullName -or $_.FullName -ne $excludedFullName } |
        Sort-Object LastWriteTime -Descending)

    if ($logs.Count -eq 0) {
        return
    }

    $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
    $toRemove = New-Object System.Collections.Generic.List[object]

    foreach ($log in $logs) {
        if ($log.LastWriteTime -lt $cutoff) {
            $toRemove.Add($log)
        }
    }

    $overflow = @($logs | Select-Object -Skip $KeepMostRecent)
    foreach ($log in $overflow) {
        if (-not $toRemove.Contains($log)) {
            $toRemove.Add($log)
        }
    }

    foreach ($log in $toRemove) {
        try {
            Remove-Item -LiteralPath $log.FullName -Force -ErrorAction Stop
            if ($Logger) {
                & $Logger "Pruned old log: $($log.Name)"
            }
        } catch {
            if ($Logger) {
                & $Logger "WARNING: Could not prune old log '$($log.Name)': $($_.Exception.Message)"
            }
        }
    }
}

function Get-MicrosludgeRegistryValueState {
    param(
        [string]$Path,
        [string]$Name
    )

    $state = [ordered]@{
        Path = $Path
        Name = $Name
        Exists = $false
        Value = $null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]$state
    }

    try {
        $property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        $state.Exists = $true
        $state.Value = $property.$Name
    } catch {
        $state.Exists = $false
        $state.Value = $null
    }

    return [pscustomobject]$state
}

function Get-MicrosludgeWindowsAIDetection {
    $windowsAIPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI",
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    )

    $paintPolicyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint"
    $policyChecks = @(
        @{ Label = "Recall availability policy"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement" },
        @{ Label = "Recall snapshot policy"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
        @{ Label = "Recall snapshot policy"; Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis" },
        @{ Label = "Click to Do policy"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableClickToDo" },
        @{ Label = "Click to Do policy"; Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableClickToDo" },
        @{ Label = "Settings AI agent policy"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableSettingsAgent" },
        @{ Label = "Paint Cocreator policy"; Path = $paintPolicyPath; Name = "DisableCocreator" },
        @{ Label = "Paint Generative Fill policy"; Path = $paintPolicyPath; Name = "DisableGenerativeFill" },
        @{ Label = "Paint Image Creator policy"; Path = $paintPolicyPath; Name = "DisableImageCreator" }
    )

    $policyStates = foreach ($check in $policyChecks) {
        $state = Get-MicrosludgeRegistryValueState -Path $check.Path -Name $check.Name
        [pscustomobject]@{
            Label = $check.Label
            Path = $check.Path
            Name = $check.Name
            Exists = $state.Exists
            Value = $state.Value
        }
    }

    $optionalFeatures = @()
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
        if ($feature) {
            $optionalFeatures += [pscustomobject]@{
                Name = $feature.FeatureName
                State = $feature.State
            }
        }
    } catch {
        $optionalFeatures += [pscustomobject]@{
            Name = "Recall"
            State = "Unable to query: $($_.Exception.Message)"
        }
    }

    $appxPatterns = @(
        "*Recall*",
        "*ClickToDo*",
        "*Click*To*Do*",
        "*Copilot*",
        "*Paint*"
    )

    $appxPackages = @()
    foreach ($pattern in $appxPatterns) {
        try {
            $packages = @(Get-AppxPackage -AllUsers $pattern -ErrorAction SilentlyContinue |
                Select-Object Name, PackageFullName, Version)
            $appxPackages += $packages
        } catch {
            $appxPackages += [pscustomobject]@{
                Name = $pattern
                PackageFullName = "Unable to query: $($_.Exception.Message)"
                Version = $null
            }
        }
    }

    $appxPackages = @($appxPackages | Sort-Object Name, PackageFullName -Unique)

    $relatedProcesses = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -match "Cocreator|Recall|ClickToDo|WindowsAI"
        } |
        Select-Object ProcessName, Id, Path |
        Sort-Object ProcessName)

    return [pscustomobject]@{
        WindowsAIRegistryPaths = @($windowsAIPaths | Where-Object { Test-Path -LiteralPath $_ })
        PolicyStates = @($policyStates)
        OptionalFeatures = @($optionalFeatures)
        AppxPackages = @($appxPackages)
        RelatedProcesses = @($relatedProcesses)
    }
}

function Write-MicrosludgeWindowsAIReport {
    param(
        [object]$Detection,
        [scriptblock]$Writer
    )

    if (-not $Writer) {
        $Writer = { param($Message) Write-Host $Message }
    }

    & $Writer "WINDOWS AI DETECTION"

    if ($Detection.WindowsAIRegistryPaths.Count -gt 0) {
        & $Writer "WindowsAI policy registry paths present:"
        foreach ($path in $Detection.WindowsAIRegistryPaths) {
            & $Writer "  $path"
        }
    } else {
        & $Writer "WindowsAI policy registry paths present: none found"
    }

    & $Writer "Policy values:"
    foreach ($policy in $Detection.PolicyStates) {
        if ($policy.Exists) {
            & $Writer "  $($policy.Label): $($policy.Path)\$($policy.Name) = $($policy.Value)"
        } else {
            & $Writer "  $($policy.Label): $($policy.Path)\$($policy.Name) not set"
        }
    }

    if ($Detection.OptionalFeatures.Count -gt 0) {
        & $Writer "Optional features:"
        foreach ($feature in $Detection.OptionalFeatures) {
            & $Writer "  $($feature.Name): $($feature.State)"
        }
    } else {
        & $Writer "Optional features: Recall feature not found"
    }

    if ($Detection.AppxPackages.Count -gt 0) {
        & $Writer "Related Appx packages:"
        foreach ($package in $Detection.AppxPackages) {
            & $Writer "  $($package.Name) | $($package.Version) | $($package.PackageFullName)"
        }
    } else {
        & $Writer "Related Appx packages: none found"
    }

    if ($Detection.RelatedProcesses.Count -gt 0) {
        & $Writer "Related running processes:"
        foreach ($process in $Detection.RelatedProcesses) {
            & $Writer "  $($process.ProcessName) | PID $($process.Id) | $($process.Path)"
        }
    } else {
        & $Writer "Related running processes: none found"
    }
}

function Test-MicrosludgeWindowsAITargetFound {
    param([object]$Detection)

    if ($Detection.WindowsAIRegistryPaths.Count -gt 0) {
        return $true
    }

    if ($Detection.OptionalFeatures.Count -gt 0) {
        return $true
    }

    if ($Detection.RelatedProcesses.Count -gt 0) {
        return $true
    }

    $targetPackages = @($Detection.AppxPackages | Where-Object {
        $_.Name -match "Recall|ClickToDo|Copilot|Paint" -or
        $_.PackageFullName -match "Recall|ClickToDo|Copilot|Paint"
    })

    return ($targetPackages.Count -gt 0)
}
