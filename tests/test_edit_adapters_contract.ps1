$ErrorActionPreference = "Stop"

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.12.0") { throw "FMG-017 requires catalogVersion 1.12.0." }
if ($Catalog.tools.Count -ne 45) { throw "FMG-017 requires exactly 45 canonical tools; got $($Catalog.tools.Count)." }

$Canonical = @($Catalog.tools | Where-Object name -eq "apply_edits")
if ($Canonical.Count -ne 1) { throw "Canonical apply_edits is missing or duplicated." }
foreach ($Name in @("apply_search_replace", "apply_unified_diff")) {
    $Tool = @($Catalog.tools | Where-Object name -eq $Name)
    if ($Tool.Count -ne 1) { throw "Missing/duplicate FMG-017 tool: $Name" }
    if ($Tool[0].handler -ne "local_tools" -or $Tool[0].risk -ne "high" -or $Tool[0].effect -ne "write") {
        throw "$Name policy classification changed unexpectedly"
    }
    if (@($Tool[0].capabilities) -notcontains "filesystem.write") { throw "$Name must retain filesystem.write authority classification" }
    if ($Tool[0].definition.inputSchema.additionalProperties -ne $false) { throw "$Name input schema must fail closed on unknown arguments" }

    $AdapterOut = $Tool[0].definition.outputSchema | ConvertTo-Json -Depth 30 -Compress
    $CanonicalOut = $Canonical[0].definition.outputSchema | ConvertTo-Json -Depth 30 -Compress
    if ($AdapterOut -ne $CanonicalOut) { throw "$Name output schema must be exactly canonical apply_edits output" }
}

$Search = $Catalog.tools | Where-Object name -eq "apply_search_replace"
foreach ($Required in @("relative_path","expected_version","search","replacement")) {
    if (@($Search.definition.inputSchema.required) -notcontains $Required) { throw "apply_search_replace must require $Required" }
}
$Diff = $Catalog.tools | Where-Object name -eq "apply_unified_diff"
foreach ($Required in @("relative_path","expected_version","unified_diff")) {
    if (@($Diff.definition.inputSchema.required) -notcontains $Required) { throw "apply_unified_diff must require $Required" }
}

$WinService = Get-Content "windows/src/FileMCP.Core/EditAdapterService.cs" -Raw
$WinTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$MacService = Get-Content "macos/EditAdapterService.swift" -Raw
$MacTools = Get-Content "macos/LocalMCPServer.swift" -Raw
$WinTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Needle in @(
    "matched zero locations",
    "is ambiguous: matched",
    "malformed hunk",
    "contains overlapping hunks",
    "path header escapes the workspace",
    "ReadExpectedVersioned",
    "TryContinue",
    "TryScanFile"
)) { Require-Contains $WinService $Needle "Windows FMG-017 compiler invariant missing: $Needle" }

foreach ($Needle in @(
    "matched zero locations",
    "is ambiguous: matched",
    "malformed hunk",
    "contains overlapping hunks",
    "path header escapes the workspace",
    "readExpectedVersioned",
    "tryContinue",
    "tryScanFile"
)) { Require-Contains $MacService $Needle "macOS FMG-017 compiler invariant missing: $Needle" }

foreach ($Forbidden in @("File.Write", "File.Move", "File.Delete", "File.Replace", "FileStream(", "Directory.")) {
    if ($WinService.IndexOf($Forbidden, [StringComparison]::Ordinal) -ge 0) { throw "Windows edit adapter must never mutate filesystem directly: $Forbidden" }
}
foreach ($Forbidden in @("FileManager.default.moveItem", "FileManager.default.replaceItemAt", "FileManager.default.removeItem", ".write(to:")) {
    if ($MacService.IndexOf($Forbidden, [StringComparison]::Ordinal) -ge 0) { throw "macOS edit adapter must never mutate filesystem directly: $Forbidden" }
}

foreach ($Needle in @('"apply_search_replace"', '"apply_unified_diff"', "_editAdapters.CompileSearchReplace", "_editAdapters.CompileUnifiedDiff", "return ApplyEdits(")) {
    Require-Contains $WinTools $Needle "Windows LocalTools FMG-017 canonical delegation missing: $Needle"
}
foreach ($Needle in @('"apply_search_replace"', '"apply_unified_diff"', "editAdapters.compileSearchReplace", "editAdapters.compileUnifiedDiff", "return try applyEdits(")) {
    Require-Contains $MacTools $Needle "macOS LocalTools FMG-017 canonical delegation missing: $Needle"
}

foreach ($Needle in @(
    "windows-edit-adapters: ok",
    "preview exactly matches equivalent canonical apply_edits preview",
    "fails closed on zero match",
    "fails closed on multiple matches",
    "rejects stale source",
    "rejects path header escape",
    "rejects overlapping hunks",
    "cancellation fails before compilation/write",
    "inherit apply_edits BOM and CRLF"
)) { Require-Contains $WinTests $Needle "Windows FMG-017 runtime proof missing: $Needle" }

foreach ($Needle in @(
    "swift-edit-search-replace: ok",
    "swift-edit-unified-diff: ok",
    "swift-edit-adapter-negative: ok"
)) { Require-Contains $SwiftTests $Needle "macOS FMG-017 native proof missing: $Needle" }

foreach ($Path in @("build_macos_app.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    $Text = Get-Content $Path -Raw
    Require-Contains $Text "EditAdapterService.swift" "$Path does not compile EditAdapterService.swift"
}

Write-Host "edit-adapters-contract: ok (catalog=1.12.0 tools=45 compile-only -> apply_edits parity)"
