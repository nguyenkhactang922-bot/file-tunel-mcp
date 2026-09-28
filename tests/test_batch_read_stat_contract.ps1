$ErrorActionPreference = "Stop"

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.7.0") { throw "FMG-015 requires catalog version 1.7.0" }
if ($Catalog.tools.Count -ne 25) { throw "FMG-015 requires exactly 25 canonical tools; got $($Catalog.tools.Count)" }

foreach ($Name in @("batch_stat", "batch_read")) {
    $Tool = @($Catalog.tools | Where-Object name -eq $Name)
    if ($Tool.Count -ne 1) { throw "Missing/duplicate canonical tool: $Name" }
    if ($Tool[0].handler -ne "local_tools") { throw "$Name must use local_tools handler" }
}
$BatchStat = $Catalog.tools | Where-Object name -eq "batch_stat"
$BatchRead = $Catalog.tools | Where-Object name -eq "batch_read"
if (@($BatchStat.definition.inputSchema.required) -notcontains "paths") { throw "batch_stat schema must require paths" }
if (@($BatchRead.definition.inputSchema.required) -notcontains "requests") { throw "batch_read schema must require requests" }
if ($BatchStat.definition.inputSchema.additionalProperties -ne $false -or $BatchRead.definition.inputSchema.additionalProperties -ne $false) {
    throw "batch schemas must fail closed on unknown top-level arguments"
}

$Win = Get-Content "windows/src/FileMCP.Core/BatchFileService.cs" -Raw
$WinTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$WinVersion = Get-Content "windows/src/FileMCP.Core/FileVersionService.cs" -Raw
$Mac = Get-Content "macos/BatchFileService.swift" -Raw
$MacServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$MacVersion = Get-Content "macos/FileVersionService.swift" -Raw
$WinTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Needle in @(
    "MaxBatchEntries = 1024",
    "TryVisitEntry",
    "TryScanFile",
    "ReadVersioned",
    "allow_content_ref",
    "ArtifactContentClasses.ToolOutput",
    "new MemoryStream(versioned.Data, writable: false)",
    "contains unknown field",
    "budget_exhausted",
    "file_changed",
    "artifact_quota",
    "completed_count",
    "truncation_reason"
)) { Require-Contains $Win $Needle "Windows FMG-015 invariant missing: $Needle" }

foreach ($Needle in @(
    "maxBatchEntries = 1024",
    "tryVisitEntry",
    "tryScanFile",
    "readVersioned",
    "allow_content_ref",
    "ArtifactContentClasses.toolOutput",
    "InputStream(data: versioned.data)",
    "contains unknown field",
    "budget_exhausted",
    "file_changed",
    "artifact_quota",
    "completed_count",
    "truncation_reason"
)) { Require-Contains $Mac $Needle "macOS FMG-015 invariant missing: $Needle" }

foreach ($Needle in @("after_first_chunk", "VerifyCurrentContentHash")) {
    Require-Contains $WinVersion $Needle "Windows strong-read hardening missing: $Needle"
}
foreach ($Needle in @("after_first_chunk", "verifyCurrentContentHash")) {
    Require-Contains $MacVersion $Needle "macOS strong-read hardening missing: $Needle"
}

foreach ($Needle in @('"batch_stat"', '"batch_read"', "BatchFileService")) {
    Require-Contains $WinTools $Needle "Windows LocalTools missing FMG-015 handler: $Needle"
    Require-Contains $MacServer $Needle "macOS LocalMCPServer missing FMG-015 handler: $Needle"
}

foreach ($Needle in @(
    "batch_stat preserves duplicate paths deterministically",
    "batch_read aggregate bytes budget cannot be bypassed by multiple entries",
    "batch_read cancellation returns explicit partial result",
    "batch_read detects individual file mutation during strong read",
    "batch_read reports artifact quota exhaustion per entry without widening authority",
    "batch_read ContentRef is bound to strong-version snapshot bytes, not reopened path bytes",
    "windows-batch-read-stat: ok"
)) { Require-Contains $WinTests $Needle "Windows FMG-015 test missing: $Needle" }

foreach ($Needle in @(
    "mcp-batch-stat: ok",
    "mcp-batch-read: ok",
    "mcp-batch-budget: ok",
    "swift-file-version-mid-read-mutation: ok",
    "macos/BatchFileService.swift",
    "macos/ArtifactContentStore.swift"
)) { Require-Contains $SwiftTests $Needle "macOS FMG-015 test/wiring missing: $Needle" }

foreach ($Path in @("build_macos_app.sh", ".github/workflows/verify.yml")) {
    $Text = Get-Content $Path -Raw
    Require-Contains $Text "macos/BatchFileService.swift" "$Path does not compile BatchFileService.swift"
    Require-Contains $Text "macos/ArtifactContentStore.swift" "$Path does not compile ArtifactContentStore.swift"
}

Write-Host "batch-read-stat-contract: ok (catalog=1.7.0 tools=25)"
