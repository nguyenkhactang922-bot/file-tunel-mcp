$ErrorActionPreference = "Stop"

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
$windowsServer = Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
$macApp = Get-Content "macos/FileMCPApp.swift" -Raw
$macServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$graph = Get-Content "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md" -Raw

foreach ($needle in @(
    'x:Name="NavRepositoryButton"',
    'x:Name="RepositoryTab"',
    'x:Name="RepositoryResultGrid"',
    'x:Name="RepositoryItemGrid"',
    'x:Name="RepositoryProviderText"',
    'x:Name="RepositorySummaryText"',
    'x:Name="RepositorySourceText"',
    'Provider completeness is heuristic and never grants authority or exhaustive source truth.'
)) {
    Assert-Contains $windowsXaml $needle "Windows Repository UI contract missing: $needle"
}

foreach ($needle in @(
    'private sealed record RepositoryResultRow(',
    'private sealed record RepositoryItemRow(',
    'private const int MaxRepositoryRows = 100;',
    'TryCaptureRepositoryRow(line, workspace);',
    'private void RefreshRepositoryGrid()',
    'private void RepositoryResultGrid_SelectionChanged',
    'private void NavigateRepository_Click',
    '[RepositoryIntelligenceResult] '
)) {
    Assert-Contains $windowsApp $needle "Windows Repository presentation missing: $needle"
}

foreach ($needle in @(
    'EmitRepositoryIntelligenceUiEventSafely(name, output.StructuredContent);',
    'private void EmitRepositoryIntelligenceUiEventSafely',
    '[RepositoryIntelligenceResult] '
)) {
    Assert-Contains $windowsServer $needle "Windows Repository projection missing: $needle"
}
$windowsProjection = Section-Between $windowsServer 'private void EmitRepositoryIntelligenceUiEventSafely' 'private void EmitArtifactBatchUiEventSafely'
Assert-NotContains $windowsProjection 'structuredContent["content_ref"]' 'Windows Repository projection must not copy raw ContentRef tokens.'
Assert-NotContains $windowsProjection 'structuredContent["content"]' 'Windows Repository projection must not copy raw source/content.'
Assert-NotContains $windowsProjection 'structuredContent["next_cursor"]' 'Windows Repository projection must not copy authenticated cursors.'
Assert-Contains $windowsProjection 'projectedEntries.Count >= 200' 'Windows Repository projection must bound displayed entries.'

foreach ($needle in @(
    'private struct RepositoryResultEvent',
    'private struct RepositoryItemEvent',
    'private let maxRepositoryEvents = 100',
    'private let repositoryResultTableView = NSTableView()',
    'private let repositoryItemTableView = NSTableView()',
    'captureRepositoryIntelligenceEvent(from: line, workspace: workspace)',
    'private func captureRepositoryIntelligenceEvent',
    '@objc private func showRepository()',
    'navigationButton("Repository", action: #selector(showRepository))',
    'NSTabViewItem(identifier: "repository")',
    'Provider completeness is heuristic and never grants authority or exhaustive source truth.'
)) {
    Assert-Contains $macApp $needle "macOS Repository presentation missing: $needle"
}

foreach ($needle in @(
    'emitRepositoryIntelligenceUIEventSafely(toolName: toolName, structuredContent: structuredContent)',
    'private func emitRepositoryIntelligenceUIEventSafely',
    '[RepositoryIntelligenceResult] '
)) {
    Assert-Contains $macServer $needle "macOS Repository projection missing: $needle"
}
$macProjection = Section-Between $macServer 'private func emitRepositoryIntelligenceUIEventSafely' 'private func emitArtifactBatchUIEventSafely'
Assert-NotContains $macProjection 'structuredContent["content_ref"]' 'macOS Repository projection must not copy raw ContentRef tokens.'
Assert-NotContains $macProjection 'structuredContent["content"]' 'macOS Repository projection must not copy raw source/content.'
Assert-NotContains $macProjection 'structuredContent["next_cursor"]' 'macOS Repository projection must not copy authenticated cursors.'
Assert-Contains $macProjection 'sourceEntries.prefix(200)' 'macOS Repository projection must bound displayed entries.'

$fmux011 = Section-Between $graph '## FMUX-011' '## FMUX-012'
Assert-Contains $fmux011 'Branch: `chatgpt/FMUX-011-repository-intelligence`.' 'FMUX-011 graph must identify its branch.'
if (-not $fmux011.Contains('State: ACTIVE / CLAIMED') -and -not $fmux011.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-011 lifecycle must be either active during verification or DONE / MAIN VERIFIED after closure.'
}

Write-Host "fmux-repository-intelligence-contract: ok"
