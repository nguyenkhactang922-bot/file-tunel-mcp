$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw
$WindowsProtocol = Get-Content "windows/src/FileMCP.Core/EvidenceProtocol.cs" -Raw
$WindowsStore = Get-Content "windows/src/FileMCP.Core/EvidenceStore.cs" -Raw
$WindowsCoordinator = Get-Content "windows/src/FileMCP.Core/EvidenceCoordinator.cs" -Raw
$WindowsServer = Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
$WindowsEnvelope = Get-Content "windows/src/FileMCP.Core/ToolResultEnvelope.cs" -Raw
$WindowsTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw

$MacSupport = Get-Content "macos/EvidenceSupport.swift" -Raw
$MacServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$MacEnvelope = Get-Content "macos/ToolResultEnvelope.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Marker in @(
    '"catalogVersion": "1.13.0"',
    '"name": "evidence_get"',
    '"pattern": "^ev_[0-9a-f]{32}$"'
)) {
    if ($Catalog.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Evidence catalog marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'public const string MetadataKey = "io.filemcp/evidence"',
    '"tool.success"',
    '"process.exit_zero"',
    'process.exit_zero evidence is only supported for exec_process'
)) {
    if ($WindowsProtocol.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows evidence protocol marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'evidence-v1.sqlite3',
    'DefaultRetention = TimeSpan.FromDays(30)',
    'DefaultMaxRecords = 10_000',
    'DefaultMaxStoreBytes = 32L * 1024 * 1024',
    'operation_state=''running''',
    'verification_state=''unknown'''
)) {
    if ($WindowsStore.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows evidence store marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'CanonicalToolCatalog.CatalogHash',
    'CaptureSourceStateRefAsync',
    'CaptureProjectContextDigest',
    'verification = "stale"',
    'verification = "unknown"'
)) {
    if ($WindowsCoordinator.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows evidence coordinator marker missing: $Marker"
    }
}

foreach ($Marker in @(
    '"evidence_get"',
    'EvidenceRequestSpec.Parse',
    'BeginAsync(evidenceRequest',
    'CompleteAsync(',
    'EvidenceRequestSpec.MetadataKey'
)) {
    if ($WindowsServer.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows evidence server marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'NewOperationId()',
    'operationId ?? NewOperationId()'
)) {
    if ($WindowsEnvelope.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows operation identity marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'static let metadataKey = "io.filemcp/evidence"',
    'static let defaultRetention: TimeInterval = 30 * 24 * 60 * 60',
    'static let defaultMaxRecords = 10_000',
    'static let defaultMaxStoreBytes = 32 * 1024 * 1024',
    'Evidence storage-size quota is exhausted',
    'Evidence record-count quota is exhausted by active records'
)) {
    if ($MacSupport.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS evidence support marker missing: $Marker"
    }
}

foreach ($Marker in @(
    '"evidence_get"',
    'EvidenceRequestSpec.parse',
    'evidenceCoordinator.begin',
    'evidenceCoordinator.complete',
    'EvidenceRequestSpec.metadataKey'
)) {
    if ($MacServer.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS evidence server marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'static func newOperationID()',
    'operationID ?? newOperationID()'
)) {
    if ($MacEnvelope.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS operation identity marker missing: $Marker"
    }
}

# Durable evidence records must not define raw payload/command/credential fields.
foreach ($Forbidden in @(
    'string? Stdout',
    'string? Stderr',
    'string? Command',
    'string? Prompt',
    'string? Credential',
    'var stdout:',
    'var stderr:',
    'var command:',
    'var prompt:',
    'var credential:'
)) {
    if ($WindowsStore.IndexOf($Forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Forbidden raw payload field found in Windows evidence store: $Forbidden"
    }
    if ($MacSupport.IndexOf($Forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Forbidden raw payload field found in macOS evidence store: $Forbidden"
    }
}

foreach ($Marker in @(
    'windows-evidence-freshness: ok',
    'stdout PASS cannot override nonzero structured exit',
    'terminal persistence failure never returns passed',
    'durable evidence excludes stdout/argv sentinel'
)) {
    if ($WindowsTests.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows evidence adversarial marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'swift-evidence-store: ok',
    'mcp-evidence-nonzero-privacy: ok',
    'mcp-evidence-freshness: ok',
    'mcp-evidence-required-mode: ok',
    'FMG011_SECRET_OUTPUT_DO_NOT_PERSIST'
)) {
    if ($SwiftTests.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS evidence adversarial marker missing: $Marker"
    }
}

foreach ($Path in @(
    "build_macos_app.sh",
    "run_macos_dev.sh",
    ".github/workflows/verify.yml",
    "tests/test_swift_runtime.sh"
)) {
    $Text = Get-Content $Path -Raw
    if ($Text.IndexOf("macos/EvidenceSupport.swift", [StringComparison]::Ordinal) -lt 0) {
        throw "macOS evidence source is not wired into: $Path"
    }
}

Write-Host "metadata-evidence-contract: ok (catalog=1.13.0 states=freshness/privacy/bounds cross-platform)"
