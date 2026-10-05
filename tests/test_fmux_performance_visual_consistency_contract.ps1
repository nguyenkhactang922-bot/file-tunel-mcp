$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot

$windowsXaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$windowsCode = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$windowsSmoke = Get-Content -Raw (Join-Path $Root "tests/test_windows_app.ps1")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$workflow = Get-Content -Raw (Join-Path $Root ".github/workflows/verify.yml")
$design = Get-Content -Raw (Join-Path $Root "docs/design/FMUX_DESIGN_SYSTEM_AND_COMPONENT_SPEC_V1.md")
$audit = Get-Content -Raw (Join-Path $Root "docs/audit/FMUX_FINAL_REPAIR_REAUDIT_2026-09-28.md")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { throw $Message }
}

function Assert-NotMatch([string]$Text, [string]$Pattern, [string]$Message) {
    if ([regex]::IsMatch($Text, $Pattern)) { throw $Message }
}

# Frozen product authority for this gate.
foreach ($needle in @(
    'No feature view may introduce arbitrary product color literals except charts/data series registered in the chart palette.',
    'background refresh must not steal focus;',
    'avoid auto-scrolling if the user has moved away from live tail.'
)) {
    Assert-Contains $design $needle "FMUX-018 design authority missing: $needle"
}
foreach ($needle in @(
    'bounded in-memory view window',
    'virtualized/list-efficient rendering where applicable',
    'throttled/coalesced refresh',
    'no forced live-tail when user scrolls away'
)) {
    Assert-Contains $audit $needle "FMUX-018 repaired-audit invariant missing: $needle"
}

# Windows live surfaces: bounded models, virtualized grids, coalesced presentation refresh.
foreach ($needle in @(
    'private const int TerminalReadWindowBytes = 16 * 1024;',
    'private const int MaxTerminalOutputCharacters = 64 * 1024;',
    'private const int MaxActivityRows = 500;',
    'private const int MaxChangeRows = 250;',
    'private const int MaxEvidenceRows = 500;',
    'private const int MaxRepositoryRows = 100;',
    'private const int MaxArtifactBatchRows = 100;',
    '_livePresentationRefreshScheduled',
    'ScheduleLivePresentationRefresh()',
    'Dispatcher.BeginInvoke(DispatcherPriority.Background',
    'FlushLivePresentationRefresh()',
    'MainTabs.SelectedIndex == MainTabs.Items.Count - 1',
    'ApplyTextPreservingLiveTail(TerminalOutputText, combined);',
    'ApplyTextPreservingLiveTail(LogBox, _logBuffer);'
)) {
    Assert-Contains $windowsCode $needle "Windows FMUX-018 performance/live-tail contract missing: $needle"
}
if ([regex]::Matches($windowsXaml, 'EnableRowVirtualization="True"').Count -lt 8) {
    throw 'Windows FMUX live/data grids must retain row virtualization across presentation surfaces.'
}
Assert-NotContains $windowsCode 'TerminalOutputText.ScrollToEnd();' 'Windows Terminal must not force live-tail after the user scrolls away.'
Assert-NotContains $windowsCode 'LogBox.ScrollToEnd();' 'Windows Diagnostics must not force live-tail after the user scrolls away.'

# Windows visual consistency: feature views consume semantic resources, not raw palette literals.
Assert-NotMatch $windowsXaml '#[0-9A-Fa-f]{6,8}' 'Windows feature XAML contains a raw product color literal instead of a semantic resource.'
Assert-NotContains $windowsXaml 'Foreground="Gray"' 'Windows feature XAML contains Gray instead of FileMcpTextSecondaryBrush.'
Assert-Contains $windowsXaml 'Stroke="{DynamicResource FileMcpStatusInfoBrush}"' 'Calls chart must use semantic info brush.'
Assert-Contains $windowsXaml 'Stroke="{DynamicResource FileMcpStatusSuccessBrush}"' 'Token chart must use semantic success brush.'

# macOS: bounded live models, native list-efficient tables, coalesced UI flush, semantic system colors and preserved live-tail.
foreach ($needle in @(
    'private let terminalReadWindowBytes = 16 * 1024',
    'private let maxTerminalOutputCharacters = 64 * 1024',
    'private let maxActivityEvents = 500',
    'private let maxChangeEvents = 250',
    'private let maxEvidenceEvents = 500',
    'private let maxRepositoryEvents = 100',
    'private let maxArtifactBatchEvents = 100',
    'private var logFlushScheduled = false',
    'DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)',
    '(tabs.selectedTabViewItem?.identifier as? String) == "log"',
    'refreshSelectedLiveEventViews()',
    'replaceTextPreservingLiveTail(combined, in: terminalOutputView)',
    'replaceTextPreservingLiveTail(logBuffer, in: logView)',
    'backgroundColor = .textBackgroundColor',
    'textColor = .textColor'
)) {
    Assert-Contains $mac $needle "macOS FMUX-018 performance/visual contract missing: $needle"
}
Assert-NotContains $mac 'terminalOutputView.scrollToEndOfDocument(nil)' 'macOS Terminal must not force live-tail after the user scrolls away.'
Assert-NotContains $mac 'logView.scrollToEndOfDocument(nil)' 'macOS Diagnostics must not force live-tail after the user scrolls away.'
Assert-NotContains $mac 'NSColor(calibratedWhite:' 'macOS code surfaces must follow semantic system appearance instead of fixed calibrated colors.'

# Startup/render regression remains proven by the existing native lanes rather than a synthetic duplicate launcher.
foreach ($needle in @(
    './tests/test_windows_app.ps1',
    './tests/test_windows_app.ps1 -Architecture arm64',
    './build_macos_app.sh'
)) {
    Assert-Contains $workflow $needle "Native startup/build regression proof missing from Verify: $needle"
}
foreach ($needle in @(
    'MainWindowHandle',
    'MainWindowTitle -eq "FileMCP"',
    'windows-app-startup-${Architecture}: ok'
)) {
    Assert-Contains $windowsSmoke $needle "Windows packaged startup smoke marker missing: $needle"
}

$fmux018Start = $graph.IndexOf('## FMUX-018', [StringComparison]::Ordinal)
$fmux019Start = $graph.IndexOf('## FMUX-019', [StringComparison]::Ordinal)
if ($fmux018Start -lt 0 -or $fmux019Start -le $fmux018Start) { throw 'FMUX-018 task graph section missing.' }
$fmux018 = $graph.Substring($fmux018Start, $fmux019Start - $fmux018Start)
Assert-Contains $fmux018 'Branch: `chatgpt/FMUX-018-performance-visual-consistency`.' 'FMUX-018 graph branch claim missing.'
if (-not $fmux018.Contains('State: ACTIVE / CLAIMED') -and -not $fmux018.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmux018.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-018 lifecycle must be active during verification or DONE / MAIN VERIFIED after closure.'
}

Write-Output 'fmux-performance-visual-consistency-contract: PASS'
Write-Output 'live-lists: bounded + row-efficient'
Write-Output 'refresh: coalesced; no forced live-tail'
Write-Output 'visual-tokens: semantic feature palette'
Write-Output 'startup-render-regression: native Verify/build/smoke retained'
