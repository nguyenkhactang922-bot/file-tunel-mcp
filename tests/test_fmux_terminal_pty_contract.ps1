$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { throw $Message }
}

function Section-Between([string]$Text, [string]$Start, [string]$End) {
    $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
    if ($startIndex -lt 0) { throw "Missing section start: $Start" }
    $endIndex = $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
    if ($endIndex -lt 0) { throw "Missing section end: $End" }
    return $Text.Substring($startIndex, $endIndex - $startIndex)
}

$windowsXaml = Get-Content "windows/src/FileMCP.App/MainWindow.xaml" -Raw
$windowsApp = Get-Content "windows/src/FileMCP.App/MainWindow.xaml.cs" -Raw
$windowsRuntime = Get-Content "windows/src/FileMCP.Core/LocalMcpRuntime.cs" -Raw
$windowsServer = Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
$macApp = Get-Content "macos/FileMCPApp.swift" -Raw
$macRuntime = Get-Content "macos/LocalMCPRuntime.swift" -Raw
$macServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$graph = Get-Content "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md" -Raw

foreach ($needle in @(
    'x:Name="NavTerminalButton"',
    'x:Name="TerminalTab"',
    'x:Name="TerminalSessionGrid"',
    'x:Name="TerminalOutputText"',
    'x:Name="TerminalCtrlCButton"',
    'x:Name="TerminalStopButton"',
    'x:Name="TerminalResizeButton"',
    'Output is read in bounded windows and is not copied into FileMCP activity/evidence telemetry.'
)) {
    Assert-Contains $windowsXaml $needle "Windows Terminal UI contract missing: $needle"
}

foreach ($needle in @(
    'private sealed record TerminalSessionRow(',
    'private const int TerminalReadWindowBytes = 16 * 1024;',
    'private const int MaxTerminalOutputCharacters = 64 * 1024;',
    'private async Task RefreshTerminalAsync(bool readSelectedOutput)',
    'private async Task ReadTerminalOutputAsync(TerminalSessionRow row)',
    'private async void TerminalCtrlC_Click',
    'private async void TerminalStop_Click',
    'private async void TerminalResize_Click',
    'presentation_grants_authority=false'
)) {
    Assert-Contains $windowsApp $needle "Windows Terminal presentation missing: $needle"
}

foreach ($needle in @(
    'CallPresentationPtyToolAsync(',
    'PresentationPolicyMetadata()'
)) {
    Assert-Contains $windowsRuntime $needle "Windows runtime presentation bridge missing: $needle"
}
$windowsBridge = Section-Between $windowsServer 'private static readonly HashSet<string> PresentationPtyToolNames' 'private static readonly HashSet<string> UnauthenticatedOAuthDiscoveryPaths'
foreach ($tool in @('pty_list','pty_read','pty_resize','pty_signal','pty_stop')) {
    Assert-Contains $windowsBridge ('"' + $tool + '"') "Windows presentation PTY allowlist missing: $tool"
}
Assert-NotContains $windowsBridge '"pty_start"' 'Windows presentation bridge must not expose pty_start.'
Assert-NotContains $windowsBridge '"pty_write"' 'Windows presentation bridge must not expose pty_write.'
Assert-Contains $windowsServer 'metadata["presentation_grants_authority"] = false;' 'Windows presentation bridge must declare no authority grant.'
$windowsUiSection = Section-Between $windowsApp 'private async Task RefreshTerminalAsync' 'private void TryCaptureArtifactBatchRow'
Assert-NotContains $windowsUiSection 'AppendLog(' 'Windows Terminal UI must not copy PTY output into diagnostics/activity logs.'
Assert-NotContains $windowsUiSection 'pty_write' 'Windows Terminal UI must not expose stdin writing.'
Assert-NotContains $windowsUiSection 'pty_start' 'Windows Terminal UI must not start new PTY sessions.'

foreach ($needle in @(
    'private struct TerminalSessionEvent',
    'private let terminalTableView = NSTableView()',
    'private let terminalOutputView = NSTextView()',
    'private let terminalReadWindowBytes = 16 * 1024',
    'private let maxTerminalOutputCharacters = 64 * 1024',
    '@objc private func showTerminal()',
    '@objc private func terminalSendCtrlC()',
    '@objc private func terminalStopSession()',
    '@objc private func terminalResizeSession()',
    'navigationButton("Terminal", action: #selector(showTerminal))',
    'NSTabViewItem(identifier: "terminal")',
    'presentation_grants_authority=false'
)) {
    Assert-Contains $macApp $needle "macOS Terminal presentation missing: $needle"
}
foreach ($needle in @(
    'callPresentationPtyTool(name:',
    'presentationPolicyMetadata()'
)) {
    Assert-Contains $macRuntime $needle "macOS runtime presentation bridge missing: $needle"
}
$macBridge = Section-Between $macServer 'private static let presentationPtyToolNames' 'private let port'
foreach ($tool in @('pty_list','pty_read','pty_resize','pty_signal','pty_stop')) {
    Assert-Contains $macBridge ('"' + $tool + '"') "macOS presentation PTY allowlist missing: $tool"
}
Assert-NotContains $macBridge '"pty_start"' 'macOS presentation bridge must not expose pty_start.'
Assert-NotContains $macBridge '"pty_write"' 'macOS presentation bridge must not expose pty_write.'
Assert-Contains $macServer 'metadata["presentation_grants_authority"] = false' 'macOS presentation bridge must declare no authority grant.'
$macUiSection = Section-Between $macApp '@objc private func showTerminal()' '@objc private func showArtifacts()'
Assert-NotContains $macUiSection 'appendLog(' 'macOS Terminal UI must not copy PTY output into diagnostics/activity logs.'
Assert-NotContains $macUiSection 'pty_write' 'macOS Terminal UI must not expose stdin writing.'
Assert-NotContains $macUiSection 'pty_start' 'macOS Terminal UI must not start new PTY sessions.'

Assert-Contains $graph '## FMUX-012' 'FMUX-012 task is missing from the frozen task graph.'
if (-not $graph.Contains('State: ACTIVE / CLAIMED') -and -not $graph.Contains('State: ACTIVE / LOCAL VERIFIED')) {
    throw 'FMUX-012 must remain active while implementation is under verification.'
}
Assert-Contains $graph 'chatgpt/FMUX-012-terminal-pty' 'FMUX-012 graph must identify the active branch.'

Write-Output "fmux-terminal-pty-contract: PASS"
Write-Output "presentation-bridge-tools: pty_list pty_read pty_resize pty_signal pty_stop"
Write-Output "stdin/start-authority: absent"
Write-Output "bounded-output: 16KiB read / 64KiB display"
Write-Output "restart-resume: unsupported and explicit"
