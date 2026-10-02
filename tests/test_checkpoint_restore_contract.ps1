$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Require-Marker([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.13.0") { throw "FMG-022 requires catalogVersion 1.13.0." }
if ($Catalog.tools.Count -ne 46) { throw "FMG-022 requires exactly 46 canonical tools." }
$Restore = @($Catalog.tools | Where-Object name -eq "checkpoint_restore")
if ($Restore.Count -ne 1) { throw "Canonical checkpoint_restore is missing or duplicated." }
$Restore = $Restore[0]
if ($Restore.risk -ne "high" -or $Restore.effect -ne "write") {
    throw "checkpoint_restore must remain high-risk write."
}
foreach ($Capability in @("filesystem.read", "filesystem.write", "filesystem.delete", "git.index.write", "workspace.checkpoint")) {
    if ($Restore.capabilities -notcontains $Capability) { throw "checkpoint_restore missing capability $Capability." }
}
$Input = $Restore.definition.inputSchema
foreach ($Property in @("checkpoint_ref", "history_mode", "dry_run")) {
    if ($null -eq $Input.properties.$Property) { throw "checkpoint_restore input missing $Property." }
}
if ($Input.required -notcontains "checkpoint_ref") { throw "checkpoint_restore must require checkpoint_ref." }
if ($Input.properties.history_mode.default -ne "preserve") { throw "checkpoint_restore default history_mode must be preserve." }
if (@($Input.properties.history_mode.enum) -notcontains "move") { throw "checkpoint_restore history_mode must support explicit move." }
if ($Input.properties.dry_run.default -ne $false) { throw "checkpoint_restore dry_run must default false." }
$Output = $Restore.definition.outputSchema
foreach ($Property in @(
    "checkpoint_ref", "state", "repository_relative_path", "history_mode",
    "original_head_oid", "target_head_oid", "rollback_checkpoint_ref",
    "path_count", "skipped_count", "recovered_incomplete", "error", "rollback_error"
)) {
    if ($null -eq $Output.properties.$Property) { throw "checkpoint_restore output missing $Property." }
}
foreach ($State in @("planned", "restored", "rolled_back", "partial_recovery_required")) {
    if (@($Output.properties.state.enum) -notcontains $State) { throw "checkpoint_restore state missing $State." }
}
if ($Restore.definition.annotations.readOnlyHint -ne $false -or
    $Restore.definition.annotations.destructiveHint -ne $true -or
    $Restore.definition.annotations.openWorldHint -ne $false) {
    throw "checkpoint_restore annotations drifted."
}

$Windows = Get-Content "windows/src/FileMCP.Core/WorkspaceCheckpointRestore.cs" -Raw
$WindowsCapture = Get-Content "windows/src/FileMCP.Core/WorkspaceCheckpointService.cs" -Raw
$WindowsPolicy = Get-Content "windows/src/FileMCP.Core/ServerPolicy.cs" -Raw
$WindowsTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$WindowsRuntime = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$Mac = Get-Content "macos/WorkspaceCheckpoint.swift" -Raw
$MacPolicy = Get-Content "macos/ServerPolicy.swift" -Raw
$MacTools = Get-Content "macos/LocalMCPServer.swift" -Raw
$SwiftRuntime = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Needle in @(
    "RestoreAsync", "RecoverIncompleteRestoreAsync", "BuildRestorePlanAsync",
    "EnsureRollbackCoverage", "ApplyRestorePlanAsync", "VerifyRestorePlanAsync",
    "partial_recovery_required", "restore-active-v1.json",
    "Repository changed after checkpoint restore plan validation",
    "update-index", "hash-object", "update-ref",
    "history_mode=move requires explicit custom high-risk local policy",
    "WorkspaceCheckpointCrashForTestsException"
)) {
    Require-Marker $Windows $Needle "Windows FMG-022 invariant missing: $Needle"
}
foreach ($Needle in @(
    "func restore(", "recoverIncompleteRestore", "buildRestorePlan",
    "ensureRollbackCoverage", "applyRestorePlan", "verifyRestorePlan",
    "partial_recovery_required", "restore-active-v1.json",
    "Repository changed after checkpoint restore plan validation",
    "update-index", "hash-object", "update-ref",
    "history_mode=move requires explicit custom high-risk local policy",
    "WorkspaceCheckpointCrashForTestsError"
)) {
    Require-Marker $Mac $Needle "macOS FMG-022 invariant missing: $Needle"
}
foreach ($Text in @($WindowsCapture, $Mac)) {
    Require-Marker $Text "index_mode" "Checkpoint schema v2 must expose index_mode for exact staged restore."
}
Require-Marker $WindowsPolicy "AllowsExplicitHistoryMove" "Windows explicit history-move policy gate missing."
Require-Marker $MacPolicy "allowsExplicitHistoryMove" "macOS explicit history-move policy gate missing."
Require-Marker $WindowsTools '"checkpoint_restore"' "Windows LocalTools does not expose checkpoint_restore."
Require-Marker $MacTools '"checkpoint_restore"' "macOS LocalTools does not expose checkpoint_restore."
Require-Marker $WindowsRuntime "windows-checkpoint-restore-only-tests: ok" "Windows FMG-022 targeted acceptance marker missing."
Require-Marker $WindowsRuntime "simulated rollback failure" "Windows rollback-failure acceptance missing."
Require-Marker $WindowsRuntime "simulated checkpoint restore crash" "Windows crash-recovery acceptance missing."
Require-Marker $SwiftRuntime "swift-workspace-checkpoint-restore: ok" "macOS FMG-022 native acceptance marker missing."
foreach ($Needle in @(
    "checkpoint restore rollback",
    "history move restore",
    "checkpoint restore crash recovery",
    "partial recovery retains rollback checkpoint"
)) {
    if ($SwiftRuntime.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "macOS FMG-022 negative acceptance missing: $Needle"
    }
}

Write-Host "checkpoint-restore-contract: ok (catalog=1.13.0 tools=46 transactional parity)"
