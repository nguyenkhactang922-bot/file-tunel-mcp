$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content contracts/tool_catalog.v1.json -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.3.0") { throw "FMG-008 requires catalogVersion 1.3.0." }
if ($Catalog.tools.Count -ne 21) { throw "Current catalog includes FMG-009 apply_edits; FMG-008 tool contracts must remain present." }

function Tool([string]$Name) {
    $items = @($Catalog.tools | Where-Object name -eq $Name)
    if ($items.Count -ne 1) { throw "Missing canonical tool: $Name" }
    return $items[0]
}
function Has-Property($Tool, [string]$Name) { return $null -ne $Tool.definition.inputSchema.properties.PSObject.Properties[$Name] }
function Is-Required($Tool, [string]$Name) { return @($Tool.definition.inputSchema.required) -contains $Name }
function Require-Marker([string]$Path, [string[]]$Markers) {
    $Text = Get-Content -LiteralPath $Path -Raw
    foreach ($Marker in $Markers) {
        if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) { throw "Missing FMG-008 marker '$Marker' in $Path" }
    }
}

$write = Tool "write_file"
$deleteFile = Tool "delete_file"
$deleteDirectory = Tool "delete_directory"
if (-not (Has-Property $write "expected_version") -or (Is-Required $write "expected_version")) { throw "write_file expected_version must be optional." }
if (-not (Has-Property $deleteFile "expected_version") -or (Is-Required $deleteFile "expected_version")) { throw "delete_file expected_version must be optional." }
if (-not (Has-Property $deleteFile "dry_run") -or (Is-Required $deleteFile "dry_run")) { throw "delete_file dry_run must be optional." }
if (-not (Has-Property $deleteDirectory "dry_run") -or (Is-Required $deleteDirectory "dry_run")) { throw "delete_directory dry_run must be optional." }
if (Has-Property $deleteDirectory "expected_version") { throw "FMG-008 must not invent a whole-tree file version token for delete_directory." }
if ($write.risk -ne "high" -or $write.effect -ne "write") { throw "write_file policy class changed unexpectedly." }
if ($deleteFile.risk -ne "high" -or $deleteFile.effect -ne "delete") { throw "delete_file policy class changed unexpectedly." }
if ($deleteDirectory.risk -ne "high" -or $deleteDirectory.effect -ne "delete") { throw "delete_directory policy class changed unexpectedly." }

Require-Marker "windows/src/FileMCP.Core/LocalTools.cs" @(
    "PrepareMutationCommit",
    "_policy.Authorize(toolName, preparedPolicy)",
    "_mutationGuard.Verify(snapshot)",
    "VerifyExpectedVersion",
    "cancellationToken.ThrowIfCancellationRequested()",
    "Dry run: would delete"
)
Require-Marker "macos/LocalMCPServer.swift" @(
    "prepareMutationCommit",
    "policy.authorize(toolName, prepared: preparedPolicy)",
    "mutationGuard.verify(snapshot)",
    "verifyExpectedVersion",
    "requireMutationContinuation",
    "Dry run: would delete"
)
Require-Marker "windows/tests/FileMCP.Core.Tests/Program.cs" @(
    "windows-existing-mutation-hardening: ok",
    "stale expected_version overwrite",
    "delete race replacement",
    "cancellation before commit",
    "policy removal before commit"
)
Require-Marker "tests/test_swift_runtime.sh" @(
    "swift-existing-mutation-hardening: ok",
    "stale expected_version overwrite",
    "delete race must fail",
    "pre-commit cancellation",
    "policy removal before commit"
)

Write-Host "existing-mutation-hardening-contract: ok (catalog=1.3.0 tools=21 expected-version + guard + policy + cancellation + dry-run parity)"
