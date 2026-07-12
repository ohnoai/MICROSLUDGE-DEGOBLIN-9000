<#
Graphical launcher for Microsludge Degoblin.

The GUI is a front end only. It reads options, shows reports, and delegates the
actual changes to the existing scripts.
#>

param(
    [switch]$NoSplash,
    [switch]$SmokeTest,
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
$mainScript = Join-Path $scriptRoot "Microsludge-Degoblin.ps1"
$installerScript = Join-Path $scriptRoot "Install-Microsludge-DegoblinTask.ps1"
$uninstallerScript = Join-Path $scriptRoot "Uninstall-Microsludge-DegoblinTask.ps1"
$logRoot = Join-Path $repoRoot "Logs"
$assetRoot = Join-Path $repoRoot "Assets"
$headerImagePath = Join-Path $assetRoot "microsludge-degoblin-9000-header.png"
$splashImagePath = Join-Path $assetRoot "microsludge-degoblin-9000-splash.png"

if (-not (Test-Path -LiteralPath $helpers)) {
    throw "Helper script not found: $helpers"
}

. $helpers

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$packageVersion = Get-MicrosludgeVersion -Root $repoRoot
$installRoot = Get-MicrosludgeInstallRoot

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function New-MicrosludgeBitmap {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = New-Object System.Uri($resolvedPath)
    $bitmap.EndInit()
    $bitmap.Freeze()
    return $bitmap
}

function Show-MicrosludgeSplash {
    param([string]$Path)

    $bitmap = New-MicrosludgeBitmap -Path $Path
    if (-not $bitmap) {
        return
    }

    $image = New-Object System.Windows.Controls.Image
    $image.Source = $bitmap
    $image.Width = 760
    $image.Stretch = [System.Windows.Media.Stretch]::Uniform

    $border = New-Object System.Windows.Controls.Border
    $border.Background = [System.Windows.Media.Brushes]::Black
    $border.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $border.Child = $image

    $window = New-Object System.Windows.Window
    $window.Title = "Microsludge Degoblin 9000"
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $window.ShowInTaskbar = $false
    $window.Topmost = $true
    $window.Content = $border
    $null = $window.Show()
    Start-Sleep -Milliseconds 1800
    $window.Close()
}

function Format-GuiCommandLine {
    param(
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    $parts = @(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $ScriptPath)
    ) + $ExtraArgs

    return $parts -join " "
}

if (-not $NoSplash) {
    Show-MicrosludgeSplash -Path $splashImagePath
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Microsludge Degoblin 9000"
        Width="940"
        Height="720"
        MinWidth="840"
        MinHeight="650"
        WindowStartupLocation="CenterScreen"
        Background="#101416"
        FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="PanelBrush" Color="#151B1E"/>
        <SolidColorBrush x:Key="PanelBorderBrush" Color="#344147"/>
        <SolidColorBrush x:Key="TextBrush" Color="#EAF1EC"/>
        <SolidColorBrush x:Key="MutedBrush" Color="#9AA9A0"/>
        <Style TargetType="Button">
            <Setter Property="Height" Value="32"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Padding" Value="10,3"/>
            <Setter Property="Background" Value="#223036"/>
            <Setter Property="Foreground" Value="#F4F7F2"/>
            <Setter Property="BorderBrush" Value="#4F626A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource TextBrush}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,3,0,0"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style x:Key="GroupTitle" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#F4F7F2"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,5"/>
        </Style>
        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#315D38"/>
            <Setter Property="BorderBrush" Value="#78A868"/>
        </Style>
        <Style x:Key="ApplyButtonStyle" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#71401E"/>
            <Setter Property="BorderBrush" Value="#D47B2B"/>
        </Style>
        <Style x:Key="AdminButtonStyle" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Height" Value="44"/>
            <Setter Property="Padding" Value="18,5"/>
            <Setter Property="Background" Value="#9A351B"/>
            <Setter Property="Foreground" Value="#FFF7E6"/>
            <Setter Property="BorderBrush" Value="#FFB35C"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="Bold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#0B0E10" BorderBrush="#344147" BorderThickness="1" CornerRadius="6" Padding="10">
            <Image x:Name="HeaderImage" Height="118" Stretch="Uniform" HorizontalAlignment="Center"/>
        </Border>

        <Border x:Name="AdminNoticeBorder" Grid.Row="1" Margin="0,10,0,10" Background="#241812" BorderBrush="#D47B2B" BorderThickness="2" CornerRadius="6" Padding="10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="AdminStatusText"
                           Grid.Column="0"
                           Foreground="#FFF0D2"
                           FontSize="15"
                           FontWeight="SemiBold"
                           VerticalAlignment="Center"
                           Text="Checking admin status..."/>
                <Button x:Name="ElevateButton"
                        Grid.Column="1"
                        Width="190"
                        Margin="14,0,0,0"
                        Content="RUN AS ADMIN"
                        Style="{StaticResource AdminButtonStyle}"/>
            </Grid>
        </Border>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="292"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="6" Padding="12">
                <StackPanel>
                    <Button x:Name="GuideButton" Content="Guide me through this" Style="{StaticResource AccentButton}" HorizontalAlignment="Stretch" Margin="0,0,0,10" ToolTip="Walk through the options one at a time."/>

                    <TextBlock Text="Targets" Style="{StaticResource GroupTitle}"/>
                    <CheckBox x:Name="CheckCopilot" Content="Copilot" IsChecked="True"/>
                    <CheckBox x:Name="CheckOneDrive" Content="OneDrive startup" IsChecked="True"/>
                    <CheckBox x:Name="CheckEdge" Content="Edge background" IsChecked="True"/>
                    <CheckBox x:Name="CheckOutlook" Content="New Outlook" IsChecked="True"/>
                    <CheckBox x:Name="CheckConsumerContent" Content="Ads / widgets" IsChecked="True"/>

                    <Separator Margin="0,10,0,10" Background="#2A363B"/>

                    <TextBlock Text="Stronger" Style="{StaticResource GroupTitle}"/>
                    <CheckBox x:Name="CheckBlockOneDrive" Content="Block OneDrive sync"/>
                    <CheckBox x:Name="CheckRemoveOneDrive" Content="Uninstall OneDrive"/>
                    <CheckBox x:Name="CheckRemoveWidgets" Content="Remove Widgets package"/>
                    <CheckBox x:Name="CheckDisableEdgeUpdates" Content="Disable Edge updates"/>
                    <CheckBox x:Name="CheckWindowsAI" Content="Windows AI cleanup" IsEnabled="False" ToolTip="Run the AI report first." ToolTipService.ShowOnDisabled="True"/>

                    <Separator Margin="0,10,0,10" Background="#2A363B"/>

                    <TextBlock Text="Task" Style="{StaticResource GroupTitle}"/>
                    <CheckBox x:Name="CheckAlwaysApply" Content="Run at every logon" ToolTip="Unchecked means the task waits for Windows Update evidence."/>

                    <Separator Margin="0,10,0,10" Background="#2A363B"/>

                    <TextBlock Text="Selection" Style="{StaticResource GroupTitle}"/>
                    <Border Background="#0B0F10" BorderBrush="#2A363B" BorderThickness="1" CornerRadius="4" Padding="8" MinHeight="46">
                        <TextBlock x:Name="OptionSummaryText"
                                   Text="default"
                                   TextWrapping="NoWrap"
                                   TextTrimming="CharacterEllipsis"
                                   Foreground="#B7F7C1"
                                   FontSize="12"
                                   FontFamily="Consolas"/>
                    </Border>
                </StackPanel>
            </Border>

            <Grid Grid.Column="1" Margin="10,0,0,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <WrapPanel Grid.Row="0" Margin="0,0,0,10" HorizontalAlignment="Center">
                    <Button x:Name="RunReportButton" Content="AI report" Width="96" Style="{StaticResource AccentButton}"/>
                    <Button x:Name="DryRunButton" Content="Dry run" Width="86"/>
                    <Button x:Name="ApplyButton" Content="Apply" Width="86" Style="{StaticResource ApplyButtonStyle}"/>
                    <Button x:Name="InstallTaskButton" Content="Install task" Width="102"/>
                    <Button x:Name="UninstallTaskButton" Content="Remove task" Width="102"/>
                    <Button x:Name="OpenLogsButton" Content="Logs" Width="74"/>
                </WrapPanel>

                <TextBox x:Name="OutputBox"
                         Grid.Row="1"
                         Background="#070A0C"
                         Foreground="#D7FFE3"
                         BorderBrush="{StaticResource PanelBorderBrush}"
                         FontFamily="Consolas"
                         FontSize="12.5"
                         IsReadOnly="True"
                         TextWrapping="Wrap"
                         AcceptsReturn="True"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Auto"/>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

$xml = [xml]$xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)

$HeaderImage = $window.FindName("HeaderImage")
$AdminNoticeBorder = $window.FindName("AdminNoticeBorder")
$AdminStatusText = $window.FindName("AdminStatusText")
$ElevateButton = $window.FindName("ElevateButton")
$GuideButton = $window.FindName("GuideButton")
$CheckCopilot = $window.FindName("CheckCopilot")
$CheckOneDrive = $window.FindName("CheckOneDrive")
$CheckEdge = $window.FindName("CheckEdge")
$CheckOutlook = $window.FindName("CheckOutlook")
$CheckConsumerContent = $window.FindName("CheckConsumerContent")
$CheckBlockOneDrive = $window.FindName("CheckBlockOneDrive")
$CheckRemoveOneDrive = $window.FindName("CheckRemoveOneDrive")
$CheckRemoveWidgets = $window.FindName("CheckRemoveWidgets")
$CheckDisableEdgeUpdates = $window.FindName("CheckDisableEdgeUpdates")
$CheckWindowsAI = $window.FindName("CheckWindowsAI")
$CheckAlwaysApply = $window.FindName("CheckAlwaysApply")
$OptionSummaryText = $window.FindName("OptionSummaryText")
$RunReportButton = $window.FindName("RunReportButton")
$DryRunButton = $window.FindName("DryRunButton")
$ApplyButton = $window.FindName("ApplyButton")
$InstallTaskButton = $window.FindName("InstallTaskButton")
$UninstallTaskButton = $window.FindName("UninstallTaskButton")
$OpenLogsButton = $window.FindName("OpenLogsButton")
$OutputBox = $window.FindName("OutputBox")

$headerBitmap = New-MicrosludgeBitmap -Path $headerImagePath
if ($headerBitmap) {
    $HeaderImage.Source = $headerBitmap
}

$script:Busy = $false
$script:WindowsAITargetFound = $false
$script:AdminOnlyButtons = @(
    $RunReportButton,
    $DryRunButton,
    $ApplyButton,
    $InstallTaskButton,
    $UninstallTaskButton
)

function Add-GuiLog {
    param([string]$Message)

    $time = Get-Date -Format "HH:mm:ss"
    $OutputBox.AppendText("[$time] $Message`r`n")
    $OutputBox.ScrollToEnd()
}

function Add-GuiProcessOutput {
    param([string]$Message)

    if ($Message -match '^\[\d{2}:\d{2}:\d{2}\]') {
        $OutputBox.AppendText("$Message`r`n")
        $OutputBox.ScrollToEnd()
        return
    }

    Add-GuiLog $Message
}

function Add-GuiBanner {
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
        $OutputBox.AppendText("$line`r`n")
    }

    $OutputBox.AppendText("`r`n")
    $OutputBox.ScrollToEnd()
}

function Show-GuiMessage {
    param(
        [string]$Message,
        [string]$Title = "Microsludge Degoblin 9000",
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )

    [System.Windows.MessageBox]::Show($window, $Message, $Title, [System.Windows.MessageBoxButton]::OK, $Icon) | Out-Null
}

function Confirm-GuiAction {
    param(
        [string]$Message,
        [string]$Title = "Confirm"
    )

    $result = [System.Windows.MessageBox]::Show($window, $Message, $Title, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Invoke-GuiRestorePointOffer {
    $result = [System.Windows.MessageBox]::Show(
        $window,
        "Create a Windows restore point before applying cleanup?`r`n`r`nRecommended. This can fail if System Protection is off or Windows recently created a restore point.",
        "Create restore point?",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
        Add-GuiLog "Restore point skipped by user."
        return $true
    }

    Add-GuiLog ""
    Set-GuiBusy $true
    $created = $false
    try {
        $created = New-MicrosludgeRestorePoint -Writer {
            param([string]$Message)
            Add-GuiLog $Message
        }
    } finally {
        Set-GuiBusy $false
    }

    if ($created) {
        return $true
    }

    $continueResult = [System.Windows.MessageBox]::Show(
        $window,
        "Restore point was not created.`r`n`r`nContinue applying cleanup anyway?",
        "Restore point failed",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    return $continueResult -eq [System.Windows.MessageBoxResult]::Yes
}

function Get-GuiSwitchValues {
    return @{
        AlwaysApply = [bool]$CheckAlwaysApply.IsChecked
        BlockOneDrive = [bool]$CheckBlockOneDrive.IsChecked
        RemoveOneDrive = [bool]$CheckRemoveOneDrive.IsChecked
        RemoveWidgets = [bool]$CheckRemoveWidgets.IsChecked
        DisableEdgeUpdates = [bool]$CheckDisableEdgeUpdates.IsChecked
        DisableWindowsAI = ($CheckWindowsAI.IsEnabled -and [bool]$CheckWindowsAI.IsChecked)
        SkipCopilot = -not [bool]$CheckCopilot.IsChecked
        SkipOneDrive = -not [bool]$CheckOneDrive.IsChecked
        SkipEdge = -not [bool]$CheckEdge.IsChecked
        SkipOutlook = -not [bool]$CheckOutlook.IsChecked
        SkipConsumerContent = -not [bool]$CheckConsumerContent.IsChecked
    }
}

function Set-GuiSwitchValues {
    param([hashtable]$Values)

    $CheckAlwaysApply.IsChecked = [bool]$Values.AlwaysApply
    $CheckBlockOneDrive.IsChecked = [bool]$Values.BlockOneDrive
    $CheckRemoveOneDrive.IsChecked = [bool]$Values.RemoveOneDrive
    $CheckRemoveWidgets.IsChecked = [bool]$Values.RemoveWidgets
    $CheckDisableEdgeUpdates.IsChecked = [bool]$Values.DisableEdgeUpdates
    $CheckWindowsAI.IsChecked = [bool]$Values.DisableWindowsAI
    $CheckCopilot.IsChecked = -not [bool]$Values.SkipCopilot
    $CheckOneDrive.IsChecked = -not [bool]$Values.SkipOneDrive
    $CheckEdge.IsChecked = -not [bool]$Values.SkipEdge
    $CheckOutlook.IsChecked = -not [bool]$Values.SkipOutlook
    $CheckConsumerContent.IsChecked = -not [bool]$Values.SkipConsumerContent
    Update-GuiSummary
}

function Get-GuiCleanupArgs {
    $values = Get-GuiSwitchValues
    return @(Get-MicrosludgeSwitchArgumentList -Values $values -Names (Get-MicrosludgeCleanupSwitchNames))
}

function Get-GuiWrapperArgs {
    $values = Get-GuiSwitchValues
    return @(Get-MicrosludgeSwitchArgumentList -Values $values -Names (Get-MicrosludgeWrapperSwitchNames))
}

function Update-GuiSummary {
    $values = Get-GuiSwitchValues
    $summary = Get-MicrosludgeOptionSummary -Values $values -Names (Get-MicrosludgeWrapperSwitchNames)
    $OptionSummaryText.Text = $summary
    $OptionSummaryText.ToolTip = $summary
}

function Set-GuiBorderColor {
    param(
        [object]$Border,
        [string]$Background,
        [string]$BorderBrush
    )

    $converter = New-Object System.Windows.Media.BrushConverter
    $Border.Background = $converter.ConvertFromString($Background)
    $Border.BorderBrush = $converter.ConvertFromString($BorderBrush)
}

function Update-GuiState {
    $isAdmin = Test-MicrosludgeIsAdmin
    if ($isAdmin) {
        $AdminStatusText.Text = "ADMIN MODE ON - cleanup controls are enabled."
        $AdminStatusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        Set-GuiBorderColor -Border $AdminNoticeBorder -Background "#102017" -BorderBrush "#78A868"
        $ElevateButton.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $AdminStatusText.Text = "NOT ADMIN - click RUN AS ADMIN before reports, dry run, apply, or task install."
        $AdminStatusText.Foreground = [System.Windows.Media.Brushes]::Khaki
        Set-GuiBorderColor -Border $AdminNoticeBorder -Background "#241812" -BorderBrush "#D47B2B"
        $ElevateButton.Visibility = [System.Windows.Visibility]::Visible
    }

    foreach ($button in $script:AdminOnlyButtons) {
        $button.IsEnabled = ($isAdmin -and -not $script:Busy)
    }

    $OpenLogsButton.IsEnabled = -not $script:Busy
    $GuideButton.IsEnabled = -not $script:Busy
    $ElevateButton.IsEnabled = (-not $isAdmin -and -not $script:Busy)
    $CheckWindowsAI.IsEnabled = ($isAdmin -and -not $script:Busy -and $script:WindowsAITargetFound)
}

function Set-GuiBusy {
    param([bool]$Busy)

    $script:Busy = $Busy
    if ($Busy) {
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
    } else {
        $window.Cursor = $null
    }

    Update-GuiState
}

function Assert-GuiAdmin {
    if (Test-MicrosludgeIsAdmin) {
        return $true
    }

    Show-GuiMessage -Message "Relaunch as Administrator first. Windows blocks the report and cleanup paths without elevation." -Icon Warning
    return $false
}

function Invoke-GuiScript {
    param(
        [string]$Label,
        [string]$ScriptPath,
        [string[]]$ExtraArgs
    )

    if (-not (Assert-GuiAdmin)) {
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Add-GuiLog "Missing script: $ScriptPath"
        Show-GuiMessage -Message "Missing script: $ScriptPath" -Icon Error
        return
    }

    $commandLine = Format-GuiCommandLine -ScriptPath $ScriptPath -ExtraArgs $ExtraArgs
    Add-GuiLog ""
    Add-GuiLog $Label
    Add-GuiLog $commandLine

    Set-GuiBusy $true
    try {
        $runArgs = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $ScriptPath
        ) + $ExtraArgs

        & powershell.exe @runArgs *>&1 |
            ForEach-Object {
                Add-GuiProcessOutput "$_"
            }

        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        Add-GuiLog "Exit code: $exitCode"
    } catch {
        Add-GuiLog "ERROR: $($_.Exception.Message)"
        Show-GuiMessage -Message $_.Exception.Message -Icon Error
    } finally {
        Set-GuiBusy $false
    }
}

function Invoke-GuiWindowsAIReport {
    if (-not (Assert-GuiAdmin)) {
        return $false
    }

    Add-GuiLog ""
    Add-GuiLog "Running Windows AI detection report."
    Set-GuiBusy $true
    $success = $false
    try {
        $reportLines = New-Object System.Collections.Generic.List[string]
        $detection = Get-MicrosludgeWindowsAIDetection
        Write-MicrosludgeWindowsAIReport -Detection $detection -Writer {
            param([string]$Message)
            $reportLines.Add($Message)
        }

        foreach ($line in $reportLines) {
            Add-GuiLog $line
        }

        $script:WindowsAITargetFound = Test-MicrosludgeWindowsAITargetFound -Detection $detection
        if ($script:WindowsAITargetFound) {
            $CheckWindowsAI.Content = "Windows AI cleanup"
            $CheckWindowsAI.ToolTip = "Available. The report found Windows AI targets."
            Add-GuiLog "Windows AI cleanup option enabled."
        } else {
            $CheckWindowsAI.IsChecked = $false
            $CheckWindowsAI.Content = "Windows AI cleanup"
            $CheckWindowsAI.ToolTip = "Omitted. The report did not find Windows AI targets."
            Add-GuiLog "Windows AI cleanup option omitted because no targets were found."
        }

        $success = $true
    } catch {
        Add-GuiLog "ERROR: $($_.Exception.Message)"
        Show-GuiMessage -Message $_.Exception.Message -Icon Error
    } finally {
        Set-GuiBusy $false
        Update-GuiSummary
    }

    return $success
}

function Start-GuiWizard {
    if (-not $script:WindowsAITargetFound -and (Test-MicrosludgeIsAdmin)) {
        $result = [System.Windows.MessageBox]::Show(
            $window,
            "Run the Windows AI detection report before the guide starts? It changes nothing and lets the guide show or omit the Windows AI option correctly.",
            "Run AI report first?",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $null = Invoke-GuiWindowsAIReport
        }
    }

    $originalSwitchValues = Get-GuiSwitchValues
    $steps = New-Object System.Collections.Generic.List[object]
    $steps.Add([pscustomobject]@{
        Title = "Start here"
        Body = "This guide only sets the checkboxes on the main screen. It does not make changes by itself. After the guide, run Dry run first so you can see what would happen before using Apply."
        ChoiceText = $null
        Control = $null
    })
    $steps.Add([pscustomobject]@{
        Title = "Copilot"
        Body = "This removes Copilot Appx packages where possible and sets policies that turn Copilot off for the current user and the machine. Leave this on if you do not use Copilot."
        ChoiceText = "Include Copilot cleanup"
        Control = $CheckCopilot
    })
    $steps.Add([pscustomobject]@{
        Title = "OneDrive startup"
        Body = "This stops OneDrive from popping back into startup and kills the running OneDrive process during cleanup. It does not uninstall OneDrive and does not block file sync by itself."
        ChoiceText = "Include OneDrive startup cleanup"
        Control = $CheckOneDrive
    })
    $steps.Add([pscustomobject]@{
        Title = "Edge background behavior"
        Body = "This sets policies for Edge background mode, startup boost, first-run experience, sidebar behavior, and removes GameAssist. It does not remove Edge itself."
        ChoiceText = "Include Edge background cleanup"
        Control = $CheckEdge
    })
    $steps.Add([pscustomobject]@{
        Title = "New Outlook"
        Body = "This removes the new Microsoft.OutlookForWindows app package where possible. It does not target classic Outlook from Microsoft Office."
        ChoiceText = "Include New Outlook cleanup"
        Control = $CheckOutlook
    })
    $steps.Add([pscustomobject]@{
        Title = "Ads, suggestions, and widgets"
        Body = "This turns off Microsoft consumer-content suggestions, ad ID behavior, tailored experiences, search highlights, activity upload, widgets/news policy, and similar Windows nags. It also stops the Widgets platform background process each run."
        ChoiceText = "Include ads, suggestions, and widgets cleanup"
        Control = $CheckConsumerContent
    })
    $steps.Add([pscustomobject]@{
        Title = "Block OneDrive sync"
        Body = "This is stronger than startup cleanup. It sets the machine policy that blocks OneDrive file sync. Leave this off if the person uses OneDrive."
        ChoiceText = "Block OneDrive file sync"
        Control = $CheckBlockOneDrive
    })
    $steps.Add([pscustomobject]@{
        Title = "Uninstall OneDrive"
        Body = "This tries to run the local OneDrive uninstaller. Pick this only when OneDrive should be removed, not merely quieted."
        ChoiceText = "Uninstall OneDrive"
        Control = $CheckRemoveOneDrive
    })
    $steps.Add([pscustomobject]@{
        Title = "Remove Widgets package"
        Body = "This is stronger than the default widgets cleanup, which only stops the background process each run. This removes the Widgets Platform Runtime Appx package outright. Windows Update may reinstall it later, which is exactly the kind of resurfacing this tool watches for."
        ChoiceText = "Remove Widgets Platform Runtime package"
        Control = $CheckRemoveWidgets
    })
    $steps.Add([pscustomobject]@{
        Title = "Disable Edge updates"
        Body = "This disables Microsoft Edge update tasks and services. It is opt-in because it can also affect WebView2 update freshness."
        ChoiceText = "Disable Edge update services and tasks"
        Control = $CheckDisableEdgeUpdates
    })

    if ($script:WindowsAITargetFound) {
        $steps.Add([pscustomobject]@{
            Title = "Windows AI cleanup"
            Body = "The report found Windows AI related targets. This sets policies for Recall availability and snapshots, Click to Do, Settings AI agent, and Paint AI features. It does not remove Recall feature bits."
            ChoiceText = "Include Windows AI cleanup"
            Control = $CheckWindowsAI
        })
    } else {
        $steps.Add([pscustomobject]@{
            Title = "Windows AI cleanup"
            Body = "This option stays off until the AI report finds related targets. Run AI report from the main window if you want the tool to check Recall, Click to Do, Settings AI agent, Paint AI policy targets, packages, and related processes."
            ChoiceText = $null
            Control = $null
        })
    }

    $steps.Add([pscustomobject]@{
        Title = "Scheduled task behavior"
        Body = "This only matters when you click Install task. Install task copies the runnable package to C:\ProgramData\Microsludge-Degoblin. Off means the task runs after logon only when Windows Update evidence is found. On means it runs at every logon."
        ChoiceText = "Run the scheduled task at every logon"
        Control = $CheckAlwaysApply
    })
    $steps.Add([pscustomobject]@{
        Title = "Review"
        Body = "Selections are now set on the main screen. Best next step: click Dry run. If the log looks right, use Apply for a one-time cleanup or Install task for future cleanup. Apply will offer to create a Windows restore point first."
        ChoiceText = $null
        Control = $null
    })

    $wizardXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Microsludge Degoblin Guided Setup"
        Width="620"
        Height="430"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner"
        Background="#101416"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Height" Value="32"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Padding" Value="12,3"/>
            <Setter Property="Background" Value="#223036"/>
            <Setter Property="Foreground" Value="#F4F7F2"/>
            <Setter Property="BorderBrush" Value="#4F626A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0">
            <TextBlock x:Name="WizardStepText" Foreground="#9AA9A0" FontSize="12"/>
            <TextBlock x:Name="WizardTitleText" Foreground="#F4F7F2" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,12"/>
        </StackPanel>

        <Border Grid.Row="1" Background="#151B1E" BorderBrush="#344147" BorderThickness="1" CornerRadius="6" Padding="16">
            <StackPanel>
                <TextBlock x:Name="WizardBodyText" Foreground="#EAF1EC" FontSize="14" TextWrapping="Wrap" LineHeight="22"/>
                <CheckBox x:Name="WizardChoiceCheck" Foreground="#B7F7C1" FontSize="14" FontWeight="SemiBold" Margin="0,22,0,0"/>
            </StackPanel>
        </Border>

        <DockPanel Grid.Row="2" Margin="0,14,0,0" LastChildFill="False">
            <Button x:Name="WizardCancelButton" Content="Cancel" Width="86" DockPanel.Dock="Left"/>
            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                <Button x:Name="WizardBackButton" Content="Back" Width="82"/>
                <Button x:Name="WizardNextButton" Content="Next" Width="82" Background="#315D38" BorderBrush="#78A868"/>
            </StackPanel>
        </DockPanel>
    </Grid>
</Window>
'@

    $wizardXml = [xml]$wizardXaml
    $wizardReader = New-Object System.Xml.XmlNodeReader $wizardXml
    $wizardWindow = [Windows.Markup.XamlReader]::Load($wizardReader)
    $wizardWindow.Owner = $window

    $WizardStepText = $wizardWindow.FindName("WizardStepText")
    $WizardTitleText = $wizardWindow.FindName("WizardTitleText")
    $WizardBodyText = $wizardWindow.FindName("WizardBodyText")
    $WizardChoiceCheck = $wizardWindow.FindName("WizardChoiceCheck")
    $WizardCancelButton = $wizardWindow.FindName("WizardCancelButton")
    $WizardBackButton = $wizardWindow.FindName("WizardBackButton")
    $WizardNextButton = $wizardWindow.FindName("WizardNextButton")

    $state = @{ Index = 0; Completed = $false }

    $saveStep = {
        $step = $steps[[int]$state["Index"]]
        if ($step.Control -and $WizardChoiceCheck.Visibility -eq [System.Windows.Visibility]::Visible) {
            $step.Control.IsChecked = [bool]$WizardChoiceCheck.IsChecked
            Update-GuiSummary
        }
    }

    $showStep = {
        $index = [int]$state["Index"]
        $step = $steps[$index]
        $WizardStepText.Text = "Step $($index + 1) of $($steps.Count)"
        $WizardTitleText.Text = $step.Title
        $WizardBodyText.Text = $step.Body

        if ($step.Control) {
            $WizardChoiceCheck.Visibility = [System.Windows.Visibility]::Visible
            $WizardChoiceCheck.Content = $step.ChoiceText
            $WizardChoiceCheck.IsChecked = [bool]$step.Control.IsChecked
        } else {
            $WizardChoiceCheck.Visibility = [System.Windows.Visibility]::Collapsed
            $WizardChoiceCheck.IsChecked = $false
            $WizardChoiceCheck.Content = ""
        }

        $WizardBackButton.IsEnabled = $index -gt 0
        if ($index -eq ($steps.Count - 1)) {
            $WizardNextButton.Content = "Done"
        } else {
            $WizardNextButton.Content = "Next"
        }
    }

    $WizardCancelButton.Add_Click({
        $wizardWindow.Close()
    })

    $WizardBackButton.Add_Click({
        & $saveStep
        if ([int]$state["Index"] -gt 0) {
            $state["Index"] = [int]$state["Index"] - 1
            & $showStep
        }
    })

    $WizardNextButton.Add_Click({
        & $saveStep
        if ([int]$state["Index"] -ge ($steps.Count - 1)) {
            $state["Completed"] = $true
            $wizardWindow.Close()
            return
        }

        $state["Index"] = [int]$state["Index"] + 1
        & $showStep
    })

    & $showStep
    $wizardWindow.ShowDialog() | Out-Null

    if ([bool]$state["Completed"]) {
        Add-GuiLog "Guided setup complete. Click Dry run to preview the selected cleanup."
        Update-GuiSummary
    } else {
        Set-GuiSwitchValues -Values $originalSwitchValues
        Add-GuiLog "Guided setup cancelled. Selections restored."
    }
}

$optionControls = @(
    $CheckCopilot,
    $CheckOneDrive,
    $CheckEdge,
    $CheckOutlook,
    $CheckConsumerContent,
    $CheckBlockOneDrive,
    $CheckRemoveOneDrive,
    $CheckRemoveWidgets,
    $CheckDisableEdgeUpdates,
    $CheckWindowsAI,
    $CheckAlwaysApply
)

foreach ($control in $optionControls) {
    $control.Add_Checked({ Update-GuiSummary })
    $control.Add_Unchecked({ Update-GuiSummary })
}

Set-GuiSwitchValues -Values @{
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

$ElevateButton.Add_Click({
    $argList = @(
        "-NoProfile",
        "-WindowStyle",
        "Hidden",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ('"{0}"' -f $PSCommandPath)
    )
    $argList += Get-MicrosludgeSwitchArgumentList -Values (Get-GuiSwitchValues) -Names (Get-MicrosludgeWrapperSwitchNames)

    Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join " ") -Verb RunAs -WindowStyle Hidden -WorkingDirectory $repoRoot
    $window.Close()
})

$GuideButton.Add_Click({
    Start-GuiWizard
})

$RunReportButton.Add_Click({
    $null = Invoke-GuiWindowsAIReport
})

$DryRunButton.Add_Click({
    $args = Get-GuiCleanupArgs
    Invoke-GuiScript -Label "Running dry run." -ScriptPath $mainScript -ExtraArgs $args
})

$ApplyButton.Add_Click({
    $args = @("-Apply") + (Get-GuiCleanupArgs)
    $message = "Apply the selected cleanup now?"
    if ([bool]$CheckRemoveOneDrive.IsChecked) {
        $message += "`r`n`r`nOneDrive uninstall is selected."
    }

    if (Confirm-GuiAction -Message $message -Title "Apply cleanup") {
        if (-not (Invoke-GuiRestorePointOffer)) {
            Add-GuiLog "Apply cancelled before cleanup."
            return
        }

        $args += "-SkipRestorePoint"
        Invoke-GuiScript -Label "Applying selected cleanup." -ScriptPath $mainScript -ExtraArgs $args
    }
})

$InstallTaskButton.Add_Click({
    $args = Get-GuiWrapperArgs
    $message = "Install the scheduled task with the selected options?`r`n`r`nThe runnable package will be copied to:`r`n$installRoot"
    if ([bool]$CheckAlwaysApply.IsChecked) {
        $message += "`r`n`r`nIt will run at every logon."
    } else {
        $message += "`r`n`r`nIt will run only when Windows Update evidence is found."
    }

    if ([bool]$CheckRemoveOneDrive.IsChecked) {
        $message += "`r`n`r`nOneDrive uninstall is selected for future task runs."
    }

    if (Confirm-GuiAction -Message $message -Title "Install scheduled task") {
        Invoke-GuiScript -Label "Installing scheduled task." -ScriptPath $installerScript -ExtraArgs $args
    }
})

$UninstallTaskButton.Add_Click({
    if (Confirm-GuiAction -Message "Remove the Microsludge Degoblin scheduled task and installed ProgramData copy?" -Title "Uninstall scheduled task") {
        Invoke-GuiScript -Label "Removing scheduled task and installed package copy." -ScriptPath $uninstallerScript -ExtraArgs @()
        $repoFullPath = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd("\")
        $installFullPath = [System.IO.Path]::GetFullPath($installRoot).TrimEnd("\")
        if ($repoFullPath -eq $installFullPath) {
            Add-GuiLog "Closing installed GUI so package removal can finish."
            $window.Close()
        }
    }
})

$OpenLogsButton.Add_Click({
    if (-not (Test-Path -LiteralPath $logRoot)) {
        New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    }

    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $logRoot)
})

$window.Add_ContentRendered({
    Add-GuiBanner
    Add-GuiLog "Microsludge Degoblin GUI ready."
    Add-GuiLog "Version: $packageVersion"
    if (Test-Path -LiteralPath $installRoot) {
        $installedVersion = Get-MicrosludgeVersion -Root $installRoot
        if ($installedVersion -ne "unknown" -and $packageVersion -ne "unknown" -and $installedVersion -ne $packageVersion) {
            Add-GuiLog "WARNING: Installed scheduled-task copy is version $installedVersion. This package is version $packageVersion. Reinstall the task to refresh the installed copy."
        }
    }
    Add-GuiLog "Run the AI report before enabling Windows AI cleanup."

    $updateState = Get-MicrosludgeUpdateState -InstallRoot $installRoot
    if ($updateState) {
        if ($updateState.LatestKnownVersion -and $updateState.LatestKnownVersion -ne $packageVersion) {
            Add-GuiLog "NOTICE: v$($updateState.LatestKnownVersion) is available on GitHub (you have v$packageVersion)."
        }

        $pending = @($updateState.PendingAcknowledgment)
        if ($pending.Count -gt 0) {
            $lines = foreach ($switchName in $pending) {
                "  -$switchName : $(Get-MicrosludgeSwitchDescription -Name $switchName)"
            }
            Add-GuiLog "NOTICE: new option(s) since your last install: $($pending -join ', ')"

            Show-GuiMessage `
                -Title "New cleanup option(s) available" `
                -Message "This version added option(s) not in your saved configuration:`r`n`r`n$($lines -join "`r`n")`r`n`r`nThey stay off by default. Check the Stronger section to turn any on, then reinstall the scheduled task to save the choice." `
                -Icon Information

            Clear-MicrosludgePendingAcknowledgment -InstallRoot $installRoot
        }
    }

    Update-GuiState
    Update-GuiSummary
})

$window.Add_Closing({
    param($sender, $eventArgs)

    if (-not $script:Busy) {
        return
    }

    $result = [System.Windows.MessageBox]::Show(
        $window,
        "A command is still running. Close the GUI anyway?`r`n`r`nCleanup may keep running in a hidden PowerShell process.",
        "Command still running",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($result -ne [System.Windows.MessageBoxResult]::Yes) {
        $eventArgs.Cancel = $true
    }
})

Update-GuiState
Update-GuiSummary

if ($SmokeTest) {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $timer.Add_Tick({
        $timer.Stop()
        $window.Close()
    })
    $timer.Start()
}

$window.ShowDialog() | Out-Null
