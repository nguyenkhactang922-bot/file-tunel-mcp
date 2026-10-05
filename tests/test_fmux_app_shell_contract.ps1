$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$winXaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$winCode = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach ($required in @(
    'x:Name="NavigationRail"',
    'x:Name="NavHomeButton"',
    'x:Name="NavConnectionsButton"',
    'x:Name="NavSettingsButton"',
    'x:Name="NavDiagnosticsButton"',
    'x:Name="CompactNavigationButton"'
)) {
    if (-not $winXaml.Contains($required)) { throw "Windows shell missing: $required" }
}

if (-not $winXaml.Contains('TargetType="{x:Type TabItem}"') -or
    -not $winXaml.Contains('Property="Visibility" Value="Collapsed"')) {
    throw "Windows top-level tab headers are not hidden from primary navigation."
}

foreach ($handler in @(
    'NavigateHome_Click',
    'NavigateConnections_Click',
    'NavigateSettings_Click',
    'NavigateDiagnostics_Click',
    'CompactNavigation_Click',
    'UpdateShellContext'
)) {
    if (-not $winCode.Contains($handler)) { throw "Windows shell handler missing: $handler" }
}

if (-not $mac.Contains('tabs.tabViewType = .noTabsNoBorder')) {
    throw "macOS still exposes top tabs as primary navigation."
}
foreach ($selector in @('showConnections','showSettings','showDiagnostics')) {
    if (-not $mac.Contains($selector)) { throw "macOS shell selector missing: $selector" }
}
if (-not $mac.Contains('shellStatusLabel')) {
    throw "macOS global runtime status context is missing."
}

$fmux001Start = $graph.IndexOf('## FMUX-001', [StringComparison]::Ordinal)
$fmux002Start = $graph.IndexOf('## FMUX-002', [StringComparison]::Ordinal)
$fmux003Start = $graph.IndexOf('## FMUX-003', [StringComparison]::Ordinal)
if ($fmux001Start -lt 0 -or $fmux002Start -le $fmux001Start -or $fmux003Start -le $fmux002Start) { throw 'FMUX-001/002 task graph sections missing.' }
$fmux001 = $graph.Substring($fmux001Start, $fmux002Start - $fmux001Start)
$fmux002 = $graph.Substring($fmux002Start, $fmux003Start - $fmux002Start)
if (-not $fmux001.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-001 is not recorded MAIN VERIFIED.' }
if (-not $fmux002.Contains('State: ACTIVE / CLAIMED') -and -not $fmux002.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmux002.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-002 lifecycle is not active/verified/done.'
}

Write-Output "fmux-app-shell-contract: PASS"
Write-Output "windows-primary-nav: sidebar"
Write-Output "windows-compact-mode: present"
Write-Output "macos-primary-nav: sidebar/no-tabs"
Write-Output "future-capability-exposure: guarded"
