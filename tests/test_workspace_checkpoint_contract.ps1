$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.12.0") { throw "FMG-021 requires catalogVersion 1.12.0." }
if ($Catalog.tools.Count -ne 45) { throw "FMG-021 requires exactly 45 canonical tools." }

$Names = @($Catalog.tools | ForEach-Object { $_.name })
$CheckpointNames = @("checkpoint_capture", "checkpoint_list", "checkpoint_get", "checkpoint_delete")
foreach ($Name in $CheckpointNames) {
    if ($Names -notcontains $Name) { throw "Missing FMG-021 canonical tool: $Name" }
}
if ($Names -contains "checkpoint_restore") { throw "FMG-022 restore must remain blocked until FMG-021 is MAIN VERIFIED." }

$Capture = $Catalog.tools | Where-Object name -eq "checkpoint_capture"
if ($Capture.risk -ne "medium" -or $Capture.effect -ne "write") { throw "checkpoint_capture policy metadata mismatch." }
if ($Capture.capabilities -notcontains "workspace.checkpoint" -or $Capture.capabilities -notcontains "filesystem.read") {
    throw "checkpoint_capture must have the explicit checkpoint + filesystem-read capabilities."
}
$CaptureProps = $Capture.definition.inputSchema.properties
foreach ($Property in @("repo_path", "include_untracked", "include_ignored", "include_generated", "ttl_seconds", "max_files", "max_total_bytes")) {
    if ($null -eq $CaptureProps.$Property) { throw "checkpoint_capture input missing $Property." }
}
if ($CaptureProps.include_ignored.default -ne $false -or $CaptureProps.include_generated.default -ne $false) {
    throw "Ignored/generated checkpoint payloads must be excluded by default."
}

$Get = $Catalog.tools | Where-Object name -eq "checkpoint_get"
foreach ($Property in @("excluded_count", "include_untracked", "include_ignored", "include_generated", "entries", "index_fingerprint")) {
    if ($null -eq $Get.definition.outputSchema.properties.$Property) { throw "checkpoint_get output missing $Property." }
}
$EntryProps = $Get.definition.outputSchema.properties.entries.items.properties
foreach ($Property in @("relative_path", "staged", "unstaged", "untracked", "ignored", "generated", "index_sha256", "worktree_sha256", "index_excluded_reason", "worktree_excluded_reason")) {
    if ($null -eq $EntryProps.$Property) { throw "checkpoint entry metadata missing $Property." }
}

$Windows = Get-Content "windows/src/FileMCP.Core/WorkspaceCheckpointService.cs" -Raw
$WindowsGit = Get-Content "windows/src/FileMCP.Core/WorkspaceCheckpointGit.cs" -Raw
$WindowsTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$Mac = Get-Content "macos/WorkspaceCheckpoint.swift" -Raw
$MacTools = Get-Content "macos/LocalMCPServer.swift" -Raw
$SwiftRuntime = Get-Content "tests/test_swift_runtime.sh" -Raw
$WindowsRuntime = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$Workflow = Get-Content ".github/workflows/verify.yml" -Raw
$MacBuild = Get-Content "build_macos_app.sh" -Raw

foreach ($Needle in @(
    "ArtifactContentClasses.Checkpoint",
    "captureGuardStateId",
    "Repository changed while checkpoint capture was in progress",
    "IndexContentRef",
    "WorktreeContentRef",
    "IndexExcludedReason",
    "WorktreeExcludedReason",
    "IsGeneratedPath",
    "includeGenerated",
    "Checkpoint refuses symlink/reparse entry"
)) {
    if ($Windows.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw "Windows FMG-021 invariant missing: $Needle" }
}
foreach ($Needle in @(
    "ArtifactContentClasses.checkpoint",
    "guardStateID",
    "Repository changed while checkpoint capture was in progress",
    "indexContentRef",
    "worktreeContentRef",
    "indexExcludedReason",
    "worktreeExcludedReason",
    "isGeneratedPath",
    "includeGenerated",
    "Checkpoint refuses symlink/reparse entry"
)) {
    if ($Mac.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw "macOS FMG-021 invariant missing: $Needle" }
}

foreach ($Name in $CheckpointNames) {
    if ($WindowsTools.IndexOf('"' + $Name + '"', [StringComparison]::Ordinal) -lt 0) { throw "Windows LocalTools missing $Name." }
    if ($MacTools.IndexOf('"' + $Name + '"', [StringComparison]::Ordinal) -lt 0) { throw "macOS LocalTools missing $Name." }
}

if ($WindowsGit.IndexOf("cat-file", [StringComparison]::Ordinal) -lt 0) { throw "Windows staged checkpoint bytes must come from the Git index blob." }
if ($MacTools.IndexOf("cat-file", [StringComparison]::Ordinal) -lt 0) { throw "macOS staged checkpoint bytes must come from the Git index blob." }
if ($MacTools.IndexOf('chmod(stdoutURL.path, S_IRUSR | S_IWUSR)', [StringComparison]::Ordinal) -lt 0) {
    throw "macOS staged Git blob temp output must be current-user-only."
}

foreach ($Forbidden in @("PromptText", "ChatTranscript", "TaskTranscript", "ToolTranscript")) {
    if ($Windows.IndexOf($Forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
        $Mac.IndexOf($Forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Checkpoint manifests must not persist prompt/chat/task/tool transcript fields: $Forbidden"
    }
}

if ($WindowsRuntime.IndexOf("windows-checkpoint-only-tests: ok", [StringComparison]::Ordinal) -lt 0) {
    throw "Windows FMG-021 behavioral acceptance marker missing."
}
if ($SwiftRuntime.IndexOf("swift-workspace-checkpoint: ok", [StringComparison]::Ordinal) -lt 0) {
    throw "macOS FMG-021 behavioral acceptance marker missing."
}
if ([regex]::IsMatch($SwiftRuntime, 'precondition\(\s*(?:\(\()?try\s+cp', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
    throw "FMG-021 Swift acceptance must hoist throwing calls out of precondition autoclosures."
}
foreach ($Needle in @("include_generated", "oversized file", "disk-full checkpoint", "ignored files require explicit opt-in")) {
    if ($WindowsRuntime.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Windows FMG-021 negative/opt-in test missing: $Needle"
    }
}
foreach ($Needle in @("include_generated", "oversized file", "checkpoint disk full", "ignored capture requires explicit opt-in")) {
    if ($SwiftRuntime.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "macOS FMG-021 negative/opt-in test missing: $Needle"
    }
}

if ($Workflow.IndexOf("macos/WorkspaceCheckpoint.swift", [StringComparison]::Ordinal) -lt 0) {
    throw "macOS Verify typecheck does not include WorkspaceCheckpoint.swift."
}
if ($MacBuild.IndexOf('macos/WorkspaceCheckpoint.swift', [StringComparison]::Ordinal) -lt 0) {
    throw "macOS app build does not include WorkspaceCheckpoint.swift."
}

Write-Host "workspace-checkpoint-contract: ok (catalog=1.12.0 tools=45 capture-only parity)"
