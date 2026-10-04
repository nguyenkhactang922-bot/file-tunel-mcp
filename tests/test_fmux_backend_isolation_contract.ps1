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

$winTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$winServer = Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
$winRuntime = Get-Content "windows/src/FileMCP.Core/LocalMcpRuntime.cs" -Raw
$winXaml = Get-Content "windows/src/FileMCP.App/MainWindow.xaml" -Raw
$winApp = Get-Content "windows/src/FileMCP.App/MainWindow.xaml.cs" -Raw
$macServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$macRuntime = Get-Content "macos/LocalMCPRuntime.swift" -Raw
$macApp = Get-Content "macos/FileMCPApp.swift" -Raw
$graph = Get-Content "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md" -Raw

foreach ($needle in @(
    'PresentationExecutionBackendMetadata()',
    '["backend_id"] = descriptor.Id',
    '["backend_version"] = descriptor.Version',
    '["backend_capabilities"] = capabilities',
    '["backend_workspace_mode"] = descriptor.WorkspaceMode',
    '["backend_environment_mode"] = descriptor.EnvironmentMode',
    '["backend_network_mode"] = descriptor.NetworkMode',
    '["backend_resource_mode"] = descriptor.ResourceMode',
    '["backend_available"] = health.Available',
    '["backend_state"] = health.State',
    '["backend_isolation_active"] = descriptor.Capabilities.Contains(ExecutionBackendCapabilities.Isolation',
    '["docker_selected"] = string.Equals(descriptor.Id, DockerExecutionBackend.BackendId',
    '"not-selected"',
    '["presentation_grants_authority"] = false'
)) { Assert-Contains $winTools $needle "Windows backend truth projection missing: $needle" }
foreach ($needle in @('"image_digest"', '"network_policy"', '"resource_policy"')) {
    Assert-Contains $winTools $needle "Windows backend projection missing bounded metadata: $needle"
}
Assert-Contains $winServer 'PresentationExecutionBackendMetadata()' 'Windows server presentation snapshot missing.'
Assert-Contains $winRuntime 'PresentationExecutionBackendMetadata()' 'Windows runtime presentation snapshot missing.'

foreach ($needle in @(
    'x:Name="NavBackendButton"', 'x:Name="BackendTab"', 'x:Name="BackendGrid"',
    'x:Name="BackendSummaryText"', 'x:Name="BackendDetailText"', 'x:Name="BackendStatusText"',
    'Read-only execution backend truth. Presentation never selects or expands backend authority.'
)) { Assert-Contains $winXaml $needle "Windows Backend / Isolation UI missing: $needle" }
foreach ($needle in @(
    'private sealed record BackendStatusRow(', 'RefreshBackendGrid()', 'runtime.PresentationExecutionBackendMetadata()',
    'NavigateBackend_Click', 'BackendGrid_SelectionChanged', 'BackendRefresh_Click',
    'Docker not selected means not probed, not available.'
)) { Assert-Contains $winApp $needle "Windows Backend / Isolation presentation missing: $needle" }

$winBackendUi = Section-Between $winApp 'private void RefreshBackendGrid()' 'private async Task RefreshTerminalAsync'
Assert-NotContains $winBackendUi 'DockerExecutionBackendConfiguration' 'Windows Backend UI must not mutate Docker configuration.'
Assert-NotContains $winBackendUi 'ExecutionBackendMode' 'Windows Backend UI must not select execution backend mode.'
Assert-NotContains $winBackendUi 'Process.Start' 'Windows Backend UI must not invoke Docker or external process directly.'
Assert-NotContains $winBackendUi 'docker ' 'Windows Backend UI must not issue Docker CLI commands.'

foreach ($needle in @(
    'func presentationExecutionBackendMetadata() throws -> [String: Any]',
    '"backend_id": descriptor.id', '"backend_version": descriptor.version',
    '"backend_capabilities": descriptor.capabilities.sorted()',
    '"backend_workspace_mode": descriptor.workspaceMode',
    '"backend_environment_mode": descriptor.environmentMode',
    '"backend_network_mode": descriptor.networkMode',
    '"backend_resource_mode": descriptor.resourceMode',
    '"backend_available": health.available', '"backend_state": health.state',
    '"backend_isolation_active": descriptor.capabilities.contains(ExecutionBackendCapabilities.isolation)',
    '"docker_selected": descriptor.id == DockerExecutionBackend.backendID',
    '"presentation_grants_authority": false'
)) { Assert-Contains $macServer $needle "macOS backend truth projection missing: $needle" }
Assert-Contains $macRuntime 'func presentationExecutionBackendMetadata() throws -> [String: Any]' 'macOS runtime presentation snapshot missing.'
foreach ($needle in @(
    'backendSummaryLabel', 'backendDetailLabel', 'backendStatusLabel', 'backendRefreshButton',
    'title: "Backend / Isolation"', 'navigationButton("Backend", action: #selector(showBackend))',
    'NSTabViewItem(identifier: "backend")', '@objc private func showBackend()',
    'runtime.presentationExecutionBackendMetadata()',
    'presentation_grants_authority=false', 'not selected / not probed'
)) { Assert-Contains $macApp $needle "macOS Backend / Isolation presentation missing: $needle" }
$macBackendUi = Section-Between $macApp '@objc private func showBackend()' '@objc private func showArtifacts()'
Assert-NotContains $macBackendUi 'DockerExecutionBackendConfiguration' 'macOS Backend UI must not mutate Docker configuration.'
Assert-NotContains $macBackendUi 'executionBackendMode' 'macOS Backend UI must not select execution backend mode.'
Assert-NotContains $macBackendUi 'Process(' 'macOS Backend UI must not launch Docker or processes.'
Assert-NotContains $macBackendUi 'docker ' 'macOS Backend UI must not issue Docker CLI commands.'

$fmux015 = Section-Between $graph '## FMUX-015' '## FMUX-016'
Assert-Contains $fmux015 'Branch: `chatgpt/FMUX-015-backend-isolation-ux`.' 'FMUX-015 graph must identify the active branch.'
if (-not $fmux015.Contains('State: ACTIVE / CLAIMED') -and
    -not $fmux015.Contains('State: ACTIVE / LOCAL VERIFIED') -and
    -not $fmux015.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-015 lifecycle must be active during verification or DONE / MAIN VERIFIED after closure.'
}

Write-Output "fmux-backend-isolation-contract: PASS"
Write-Output "authority: read-only presentation; no backend selector or Docker control"
Write-Output "docker-truth: selected backend health only; host means not-selected/not-probed"
Write-Output "projection: backend identity/status + isolation/network/resource/image metadata"
