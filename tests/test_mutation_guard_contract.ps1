$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Require-Marker([string]$Path, [string[]]$Markers) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing FMG-007 file: $Path" }
    $Text = Get-Content -LiteralPath $Path -Raw
    foreach ($Marker in $Markers) {
        if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
            throw "Missing FMG-007 marker '$Marker' in $Path."
        }
    }
}

Require-Marker "windows/src/FileMCP.Core/AuthorizedPathSnapshot.cs" @(
    "AuthorizedPathSnapshotService",
    "CaptureAncestorChain",
    "ExpectedLeafAbsent",
    "FileFlagOpenReparsePoint",
    "GetFileInformationByHandle",
    "ancestor identity changed",
    "target identity changed",
    "expected target leaf absence"
)
Require-Marker "macos/AuthorizedPathSnapshot.swift" @(
    "AuthorizedPathSnapshotService",
    "captureAncestorChain",
    "expectedLeafAbsent",
    "lstat(",
    "O_NOFOLLOW",
    "fstat(",
    "ancestor identity changed",
    "target identity changed",
    "expected target leaf absence"
)
Require-Marker "windows/tests/FileMCP.Core.Tests/Program.cs" @(
    "windows-mutation-guard: ok",
    "ancestor junction swap",
    "shared-root authority replacement",
    "leaf inserted after new-target authorization"
)
Require-Marker "tests/test_swift_runtime.sh" @(
    "swift-mutation-guard: ok",
    "ancestor symlink swap",
    "root authority replacement",
    "inserted leaf must fail"
)
foreach ($Path in @("build_macos_app.sh", "run_macos_dev.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    Require-Marker $Path @("macos/AuthorizedPathSnapshot.swift")
}

$Catalog = Get-Content contracts/tool_catalog.v1.json -Raw | ConvertFrom-Json
if ($Catalog.tools.Count -ne 22) { throw "Current catalog includes later tools; FMG-007 remains an internal mutation-safety primitive." }
if ($Catalog.catalogVersion -ne "1.5.0") { throw "FMG-008 catalog schema version is 1.5.0; Mutation Guard remains internal." }

Write-Host "mutation-guard-contract: ok (native identity + full ancestor chain + expected-leaf parity)"
