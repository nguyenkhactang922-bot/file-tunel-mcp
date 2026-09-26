$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content contracts/tool_catalog.v1.json -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.3.0") { throw "Current mutation schema requires catalogVersion 1.3.0 while FMG-006 version outputs remain compatible." }
if ($Catalog.tools.Count -ne 21) { throw "Current catalog must retain FMG-006 contracts alongside later tools." }
foreach ($Name in @("read_file", "read_file_range")) {
    $Tool = @($Catalog.tools | Where-Object name -eq $Name)
    if ($Tool.Count -ne 1) { throw "Missing canonical $Name tool." }
    $Required = @($Tool[0].definition.outputSchema.required)
    foreach ($Field in @("version", "version_strength", "size_bytes")) {
        if ($Required -notcontains $Field) { throw "$Name output schema is missing required $Field." }
    }
    $Props = $Tool[0].definition.outputSchema.properties
    if ($Props.version.type -ne "string") { throw "$Name version must be an opaque string token." }
    if (@($Props.version_strength.enum) -notcontains "content") { throw "$Name must declare content-strength versions." }
}

function Require-Marker([string]$Path, [string[]]$Markers) {
    $Text = Get-Content $Path -Raw
    foreach ($Marker in $Markers) {
        if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
            throw "Missing FMG-006 marker '$Marker' in $Path."
        }
    }
}

Require-Marker "windows/src/FileMCP.Core/FileVersionService.cs" @(
    "HMACSHA256",
    "GetFileInformationByHandle",
    "ProcessSigningKey",
    "VersionFingerprint",
    "File changed since the version token was captured",
    "Target was replaced since the version token was captured"
)
Require-Marker "macos/FileVersionService.swift" @(
    "HMAC<SHA256>",
    "fstat(",
    "st_ino",
    "processSigningKey",
    "versionFingerprint",
    "File changed since the version token was captured",
    "Target was replaced since the version token was captured"
)
Require-Marker "windows/src/FileMCP.Core/SourceStateRef.cs" @(
    "source-state-v1",
    "head_scope_fingerprint",
    "tracked_dirty_fingerprint",
    "untracked_fingerprint",
    "catalog_hash",
    "policy_generation",
    "version_ref"
)
Require-Marker "macos/LocalMCPServer.swift" @(
    "captureSourceStateRef",
    "source-state-v1",
    "head_scope_fingerprint",
    "tracked_dirty_fingerprint",
    "untracked_fingerprint",
    "version_ref"
)

foreach ($Path in @("build_macos_app.sh", "run_macos_dev.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    Require-Marker $Path @("macos/FileVersionService.swift")
}
Require-Marker "windows/tests/FileMCP.Core.Tests/Program.cs" @("windows-file-version-source-state: ok")
Require-Marker "tests/test_swift_runtime.sh" @("swift-file-version-source-state: ok")

$WindowsSourceState = Get-Content windows/src/FileMCP.Core/SourceStateRef.cs -Raw
if ($WindowsSourceState -match '\["version"\]\s*=\s*versioned\.VersionToken') {
    throw "SourceStateRef must not persist process-local authenticated file-version tokens."
}
if ($WindowsSourceState -notmatch 'path_fingerprint' -or $WindowsSourceState -notmatch 'version_ref') {
    throw "SourceStateRef must persist only fingerprinted scoped file-version metadata."
}

Write-Host "file-version-source-state-contract: ok (catalog=1.3.0 strong-version + scoped-digest parity)"
