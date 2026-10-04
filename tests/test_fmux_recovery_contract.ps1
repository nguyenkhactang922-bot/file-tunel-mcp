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

$winXaml = Get-Content "windows/src/FileMCP.App/MainWindow.xaml" -Raw
$winApp = Get-Content "windows/src/FileMCP.App/MainWindow.xaml.cs" -Raw
$winRuntime = Get-Content "windows/src/FileMCP.Core/LocalMcpRuntime.cs" -Raw
$winServer = Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
$macApp = Get-Content "macos/FileMCPApp.swift" -Raw
$macRuntime = Get-Content "macos/LocalMCPRuntime.swift" -Raw
$macServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$graph = Get-Content "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md" -Raw

foreach ($needle in @(
    'x:Name="NavRecoveryButton"',
    'x:Name="RecoveryTab"',
    'x:Name="RecoveryQuarantineGrid"',
    'x:Name="RecoveryCheckpointGrid"',
    'x:Name="RecoveryRestoreQuarantineButton"',
    'x:Name="RecoveryPlanCheckpointButton"',
    'x:Name="RecoveryRestoreCheckpointButton"',
    'partial recovery is surfaced explicitly'
)) { Assert-Contains $winXaml $needle "Windows Recovery UI contract missing: $needle" }

foreach ($needle in @(
    'private async Task RefreshRecoveryAsync()',
    'CallPresentationRecoveryToolAsync("quarantine_list"',
    'CallPresentationRecoveryToolAsync("quarantine_get"',
    'CallPresentationRecoveryToolAsync("quarantine_restore"',
    'CallPresentationRecoveryToolAsync("checkpoint_list"',
    'CallPresentationRecoveryToolAsync("checkpoint_get"',
    'CallPresentationRecoveryToolAsync("checkpoint_restore"',
    '["dry_run"] = true',
    '["dry_run"] = false',
    '["history_mode"] = "preserve"',
    'MessageBoxImage.Warning',
    'HIGH SEVERITY: quarantine restore requires partial recovery',
    'HIGH SEVERITY: checkpoint restore requires partial recovery',
    '_recoveryPersistentNotice',
    'PathBox(row.Workspace).Text.Trim()'
)) { Assert-Contains $winApp $needle "Windows Recovery semantics missing: $needle" }

$winRecovery = Section-Between $winApp 'private async Task RefreshRecoveryAsync()' 'private static string JsonText'
foreach ($forbidden in @('"quarantine_delete"','"checkpoint_capture"','"checkpoint_delete"','"pty_write"','"run_command"','["replace_existing"]','["expected_target_version"]','["target_relative_path"]','AppendLog(')) {
    Assert-NotContains $winRecovery $forbidden "Windows Recovery UI must not expand authority or log recovery payloads: $forbidden"
}
Assert-Contains $winRuntime 'CallPresentationRecoveryToolAsync' 'Windows runtime Recovery presentation bridge missing.'
$winAllow = Section-Between $winServer 'PresentationRecoveryToolNames' 'UnauthenticatedOAuthDiscoveryPaths'
foreach ($tool in @('quarantine_list','quarantine_get','quarantine_restore','checkpoint_list','checkpoint_get','checkpoint_restore')) {
    Assert-Contains $winAllow ('"' + $tool + '"') "Windows Recovery bridge missing allowlisted tool: $tool"
}
foreach ($tool in @('quarantine_delete','checkpoint_capture','checkpoint_delete','pty_start','pty_write','run_command')) {
    Assert-NotContains $winAllow ('"' + $tool + '"') "Windows Recovery bridge exposes forbidden tool: $tool"
}
Assert-Contains $winServer 'metadata["presentation_grants_authority"] = false' 'Windows presentation metadata must declare no authority grant.'

foreach ($needle in @(
    'navigationButton("Recovery", action: #selector(showRecovery))',
    'NSTabViewItem(identifier: "recovery")',
    'private let recoveryQuarantineTableView = NSTableView()',
    'private let recoveryCheckpointTableView = NSTableView()',
    '@objc private func showRecovery()',
    'callPresentationRecoveryTool(name: "quarantine_list"',
    'callPresentationRecoveryTool(name: "quarantine_get"',
    'callPresentationRecoveryTool(name: "quarantine_restore"',
    'callPresentationRecoveryTool(name: "checkpoint_list"',
    'callPresentationRecoveryTool(name: "checkpoint_get"',
    'callPresentationRecoveryTool(name: "checkpoint_restore"',
    '"dry_run": true',
    '"dry_run": false',
    '"history_mode": "preserve"',
    'confirmRecovery(',
    'HIGH SEVERITY: quarantine restore requires partial recovery',
    'HIGH SEVERITY: checkpoint restore requires partial recovery',
    'recoveryPersistentNotice',
    'Workspace root:'
)) { Assert-Contains $macApp $needle "macOS Recovery semantics missing: $needle" }

$macRecovery = Section-Between $macApp '@objc private func showRecovery()' '@objc private func showArtifacts()'
foreach ($forbidden in @('"quarantine_delete"','"checkpoint_capture"','"checkpoint_delete"','"pty_write"','"run_command"','"replace_existing"','"expected_target_version"','"target_relative_path"','appendLog(')) {
    Assert-NotContains $macRecovery $forbidden "macOS Recovery UI must not expand authority or log recovery payloads: $forbidden"
}
Assert-Contains $macRuntime 'func callPresentationRecoveryTool' 'macOS runtime Recovery presentation bridge missing.'
$macAllow = Section-Between $macServer 'presentationRecoveryToolNames' 'private let port'
foreach ($tool in @('quarantine_list','quarantine_get','quarantine_restore','checkpoint_list','checkpoint_get','checkpoint_restore')) {
    Assert-Contains $macAllow ('"' + $tool + '"') "macOS Recovery bridge missing allowlisted tool: $tool"
}
foreach ($tool in @('quarantine_delete','checkpoint_capture','checkpoint_delete','pty_start','pty_write','run_command')) {
    Assert-NotContains $macAllow ('"' + $tool + '"') "macOS Recovery bridge exposes forbidden tool: $tool"
}
Assert-Contains $macServer 'metadata["presentation_grants_authority"] = false' 'macOS presentation metadata must declare no authority grant.'

$fmux013 = Section-Between $graph '## FMUX-013' '## FMUX-014'
Assert-Contains $fmux013 'Branch: `chatgpt/FMUX-013-recovery`.' 'FMUX-013 graph must identify its branch.'
if (-not $fmux013.Contains('State: ACTIVE / CLAIMED') -and
    -not $fmux013.Contains('State: ACTIVE / LOCAL VERIFIED') -and
    -not $fmux013.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-013 lifecycle must be active during verification or DONE / MAIN VERIFIED after closure.'
}

Write-Output "fmux-recovery-contract: PASS"
Write-Output "presentation-bridge-tools: quarantine_list quarantine_get quarantine_restore checkpoint_list checkpoint_get checkpoint_restore"
Write-Output "create-delete-authority: absent"
Write-Output "checkpoint-plan-before-restore: required"
Write-Output "quarantine-replace-override: absent"
Write-Output "partial-recovery-state: explicit/high-severity"
