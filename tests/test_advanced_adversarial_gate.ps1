$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

function Require-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) { throw $Message }
}

function Require-Regex([string]$Text, [string]$Pattern, [string]$Message) {
    if (-not [regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.13.0") { throw "FMG-025 requires frozen catalog version 1.13.0." }
if ($Catalog.tools.Count -ne 46) { throw "FMG-025 requires exactly 46 canonical tools; got $($Catalog.tools.Count)." }

$Workflow = Get-Content ".github/workflows/verify.yml" -Raw
$WindowsRuntime = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$SwiftRuntime = Get-Content "tests/test_swift_runtime.sh" -Raw
$ArtifactContract = Get-Content "tests/test_artifact_contentref_contract.ps1" -Raw
$PtyContract = Get-Content "tests/test_persistent_pty_contract.ps1" -Raw
$CheckpointContract = Get-Content "tests/test_workspace_checkpoint_contract.ps1" -Raw
$RepoIntelContract = Get-Content "tests/test_repository_intelligence_contract.ps1" -Raw
$EvidenceContract = Get-Content "tests/test_evidence_contract.ps1" -Raw
$DockerEvidence = Get-Content "docs/evidence/FMG-024_OPTIONAL_DOCKER_ISOLATED_BACKEND_EVIDENCE.md" -Raw

$MacMatch = [regex]::Match($Workflow, '(?ms)^  verify-macos:\s*.*?(?=^  verify-windows:)')
$WindowsMatch = [regex]::Match($Workflow, '(?ms)^  verify-windows:\s*.*?(?=^  verify-windows-arm64:)')
$ArmMatch = [regex]::Match($Workflow, '(?ms)^  verify-windows-arm64:\s*.*\z')
if (-not $MacMatch.Success -or -not $WindowsMatch.Success -or -not $ArmMatch.Success) {
    throw "FMG-025 could not isolate all three native Verify jobs."
}
$MacJob = $MacMatch.Value
$WindowsJob = $WindowsMatch.Value
$ArmJob = $ArmMatch.Value

$AdvancedContracts = @(
    "test_artifact_contentref_contract.ps1",
    "test_batch_read_stat_contract.ps1",
    "test_quarantine_restore_contract.ps1",
    "test_edit_adapters_contract.ps1",
    "test_repository_intelligence_contract.ps1",
    "test_repository_intelligence_query_contract.ps1",
    "test_persistent_pty_contract.ps1",
    "test_workspace_checkpoint_contract.ps1",
    "test_checkpoint_restore_contract.ps1",
    "test_execution_backend_contract.ps1",
    "test_docker_backend_contract.ps1"
)

foreach ($Contract in $AdvancedContracts) {
    $Path = Join-Path "tests" $Contract
    if (-not (Test-Path $Path -PathType Leaf)) { throw "FMG-025 advanced contract missing: $Contract" }
    Require-Contains $WindowsJob ("./tests/" + $Contract) "Windows x64 Verify is missing advanced contract: $Contract"
    Require-Contains $ArmJob ("./tests/" + $Contract) "Native Windows ARM64 Verify is missing advanced contract: $Contract"
    $Count = [regex]::Matches($Workflow, [regex]::Escape("./tests/" + $Contract)).Count
    if ($Count -ne 2) { throw "FMG-025 requires each advanced PowerShell contract exactly once in Windows x64 and once in ARM64; $Contract count=$Count." }
}

foreach ($Source in @(
    "macos/ArtifactContentStore.swift",
    "macos/BatchFileService.swift",
    "macos/QuarantineService.swift",
    "macos/EditAdapterService.swift",
    "macos/RepositoryIntelligence.swift",
    "macos/RepositoryIntelligenceQuery.swift",
    "macos/PersistentPty.swift",
    "macos/WorkspaceCheckpoint.swift",
    "macos/ExecutionBackend.swift",
    "macos/DockerExecutionBackend.swift"
)) {
    Require-Contains $MacJob $Source "macOS native Verify typecheck is missing advanced source: $Source"
}
Require-Contains $MacJob "./tests/test_swift_runtime.sh" "macOS native Verify must execute the Swift adversarial runtime suite."
Require-Contains $MacJob "./build_macos_app.sh" "macOS native Verify must build the packaged app after adversarial runtime tests."

# The advanced gate does not rerun the expensive suites. It proves they are CI-wired,
# while each task-specific contract continues to own its detailed negative markers.
foreach ($FoundationGate in @(
    "./tests/test_tool_surface_parity.ps1",
    "./tests/test_file_version_source_state_contract.ps1",
    "./tests/test_mutation_guard_contract.ps1",
    "./tests/test_existing_mutation_hardening_contract.ps1",
    "./tests/test_apply_edits_contract.ps1",
    "./tests/test_evidence_contract.ps1"
)) {
    Require-Contains $WindowsJob $FoundationGate "FMG-025 must preserve foundation gate wiring: $FoundationGate"
}

Require-Contains $ArtifactContract "ArtifactContentStore must remain independent from evidence/telemetry content stores." "FMG-025 artifact privacy guard is missing."
Require-Contains $ArtifactContract "macOS ArtifactContentStore must remain independent from evidence/telemetry content stores." "FMG-025 macOS artifact privacy guard is missing."
Require-Contains $PtyContract "Windows PTY code must not emit PTY bytes into evidence/telemetry" "FMG-025 Windows PTY privacy guard is missing."
Require-Contains $PtyContract "macOS PTY code must not emit PTY bytes into evidence/telemetry" "FMG-025 macOS PTY privacy guard is missing."
foreach ($Forbidden in @("PromptText", "ChatTranscript", "TaskTranscript", "ToolTranscript")) {
    Require-Contains $CheckpointContract $Forbidden "FMG-025 checkpoint transcript exclusion guard is missing: $Forbidden"
}
Require-Contains $RepoIntelContract "does not persist raw full-source" "FMG-025 repository-intelligence raw-source privacy proof is missing."
Require-Contains $RepoIntelContract "corrupted cache is deleted" "FMG-025 repository-intelligence corruption proof is missing."
Require-Contains $RepoIntelContract "giant repository indexing is deterministically bounded" "FMG-025 repository-intelligence scale proof is missing."
Require-Contains $EvidenceContract "Durable evidence records must not define raw payload/command/credential fields." "FMG-025 durable evidence privacy guard is missing."
Require-Contains $EvidenceContract "durable evidence excludes stdout/argv sentinel" "FMG-025 Windows evidence privacy runtime proof is missing."
Require-Contains $EvidenceContract "FMG011_SECRET_OUTPUT_DO_NOT_PERSIST" "FMG-025 macOS evidence privacy runtime proof is missing."

foreach ($Marker in @(
    "windows-artifact-contentref-store: ok",
    "windows-quarantine-restore: ok",
    "windows-repository-intelligence: ok",
    "windows-checkpoint-only-tests: ok",
    "windows-checkpoint-restore-only-tests: ok",
    "windows-execution-backend: ok",
    "windows-docker-backend: ok"
)) {
    Require-Contains $WindowsRuntime $Marker "FMG-025 Windows adversarial runtime marker missing: $Marker"
}
foreach ($Marker in @(
    "swift-artifact-contentref-store: ok",
    "swift-quarantine-restore: ok",
    "swift-repository-intelligence: ok",
    "swift-persistent-pty: ok",
    "swift-workspace-checkpoint: ok",
    "swift-workspace-checkpoint-restore: ok",
    "swift-execution-backend: ok",
    "swift-docker-backend: ok"
)) {
    Require-Contains $SwiftRuntime $Marker "FMG-025 macOS adversarial runtime marker missing: $Marker"
}

Require-Contains $DockerEvidence "ENVIRONMENT-BLOCKED" "FMG-025 must preserve explicit Docker live-proof environment block."
Require-Regex $DockerEvidence '(?im)no (?:live )?Docker PASS is claimed' "FMG-025 Docker evidence must explicitly reject fake live PASS."

# The aggregate gate itself must be enforced in both Windows-native jobs. The macOS job
# remains independently authoritative through the Swift runtime suite checked above.
foreach ($Job in @($WindowsJob, $ArmJob)) {
    Require-Contains $Job "./tests/test_advanced_adversarial_gate.ps1" "FMG-025 aggregate adversarial gate is not wired into a Windows native Verify job."
}
$SelfCount = [regex]::Matches($Workflow, [regex]::Escape("./tests/test_advanced_adversarial_gate.ps1")).Count
if ($SelfCount -ne 2) { throw "FMG-025 aggregate gate must run exactly once in Windows x64 and once in native ARM64; count=$SelfCount." }

Write-Host "advanced-adversarial-gate: ok (FMG-014..024 parity/privacy/security/runtime wiring)"
Write-Host "catalog: 1.13.0 / 46 tools"
Write-Host "native-jobs: macOS + Windows x64 + Windows ARM64"
Write-Host "docker-live-proof: environment-blocked unless a real engine is available"
