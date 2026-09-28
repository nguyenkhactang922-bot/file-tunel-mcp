$ErrorActionPreference = "Stop"

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$WindowsStore = Get-Content "windows/src/FileMCP.Core/ArtifactContentStore.cs" -Raw
$WindowsTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$MacStore = Get-Content "macos/ArtifactContentStore.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw
$MacBuild = Get-Content "build_macos_app.sh" -Raw
$Verify = Get-Content ".github/workflows/verify.yml" -Raw

foreach ($Class in @("TOOL_OUTPUT", "PTY_OUTPUT", "CHECKPOINT", "QUARANTINE")) {
    Assert-Contains $WindowsStore $Class "Windows artifact store missing content class $Class"
    Assert-Contains $MacStore $Class "macOS artifact store missing content class $Class"
}

foreach ($Needle in @(
    "HMACSHA256",
    "WorkspaceAuthorityId",
    "ContentRef authentication failed",
    "ContentRef workspace mismatch",
    "ContentRef lease expired",
    "Artifact global quota exhausted",
    "Artifact workspace quota exhausted",
    "FileSystemAclExtensions.SetAccessControl",
    "FileOptions.WriteThrough",
    "VerifyBlobIntegrityAsync",
    "before-index-commit"
)) {
    Assert-Contains $WindowsStore $Needle "Windows FMG-014 invariant missing: $Needle"
}

foreach ($Needle in @(
    "HMAC<SHA256>",
    "workspaceAuthorityID",
    "ContentRef authentication failed",
    "ContentRef workspace mismatch",
    "ContentRef lease expired",
    "Artifact global quota exhausted",
    "Artifact workspace quota exhausted",
    ".posixPermissions",
    "verifyBlobIntegrity",
    "before-index-commit"
)) {
    Assert-Contains $MacStore $Needle "macOS FMG-014 invariant missing: $Needle"
}

foreach ($Needle in @(
    "windows-artifact-contentref-store: ok",
    "tampered ContentRef rejected",
    "cross-workspace ContentRef replay rejected",
    "artifact blob corruption rejected before serving bytes",
    "disk-full failure rolls back newly published blob",
    "concurrent puts deduplicate one content-addressed blob"
)) {
    Assert-Contains $WindowsTests $Needle "Windows FMG-014 negative test missing: $Needle"
}

foreach ($Needle in @(
    "swift-artifact-contentref-store: ok",
    'expectArtifactFailure("tamper"',
    'expectArtifactFailure("cross-workspace"',
    'expectArtifactFailure("corruption"',
    'expectArtifactFailure("disk full"',
    "concurrent puts did not deduplicate"
)) {
    Assert-Contains $SwiftTests $Needle "macOS FMG-014 negative test missing: $Needle"
}

Assert-Contains $MacBuild '"$ROOT/macos/ArtifactContentStore.swift"' "macOS build does not compile ArtifactContentStore.swift"
Assert-Contains $Verify "macos/ArtifactContentStore.swift" "Verify static typecheck does not compile ArtifactContentStore.swift"
Assert-Contains $SwiftTests "macos/ArtifactContentStore.swift" "macOS integration test does not compile ArtifactContentStore.swift"

if ($WindowsStore -match 'EvidenceStore|TelemetryPersistence|observability-v1|evidence-v1') {
    throw "ArtifactContentStore must remain independent from evidence/telemetry content stores."
}
if ($MacStore -match 'EvidenceStore|evidence-v1|observability') {
    throw "macOS ArtifactContentStore must remain independent from evidence/telemetry content stores."
}

Write-Host "artifact-contentref-contract: ok"
