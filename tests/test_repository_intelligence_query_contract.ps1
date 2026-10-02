$ErrorActionPreference = "Stop"

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.13.0") { throw "FMG-019 requires catalogVersion 1.13.0." }
if ($Catalog.tools.Count -ne 46) { throw "FMG-019 requires exactly 46 canonical tools; got $($Catalog.tools.Count)." }

foreach ($Name in @("repo_map", "symbol_search", "related_files")) {
    $Tool = @($Catalog.tools | Where-Object name -eq $Name)
    if ($Tool.Count -ne 1) { throw "Missing/duplicate FMG-019 tool: $Name" }
    if ($Tool[0].handler -ne "local_tools" -or $Tool[0].risk -ne "low" -or $Tool[0].effect -ne "read") {
        throw "$Name must remain a low-risk read-only local tool"
    }
    if (@($Tool[0].capabilities) -notcontains "filesystem.read") { throw "$Name must retain filesystem.read classification" }
    if ($Tool[0].definition.inputSchema.additionalProperties -ne $false) { throw "$Name input schema must fail closed on unknown fields" }
    if ($Tool[0].definition.annotations.readOnlyHint -ne $true -or
        $Tool[0].definition.annotations.destructiveHint -ne $false -or
        $Tool[0].definition.annotations.openWorldHint -ne $false) {
        throw "$Name annotations must remain read-only / non-destructive / closed-world"
    }
    $Out = $Tool[0].definition.outputSchema
    if ($Out.properties.grants_authority.const -ne $false) { throw "$Name must declare grants_authority=false" }
    if ($Out.properties.raw_source_persisted.const -ne $false) { throw "$Name must declare raw_source_persisted=false" }
}
$RepoMap = $Catalog.tools | Where-Object name -eq "repo_map"
if ($RepoMap.definition.inputSchema.properties.max_items.maximum -ne 500) { throw "repo_map max_items bound changed" }
$Symbol = $Catalog.tools | Where-Object name -eq "symbol_search"
if ($Symbol.definition.inputSchema.properties.max_results.maximum -ne 200 -or
    $Symbol.definition.inputSchema.properties.query.maxLength -ne 512) {
    throw "symbol_search bounds changed"
}
$Related = $Catalog.tools | Where-Object name -eq "related_files"
if ($Related.definition.inputSchema.properties.max_results.maximum -ne 200 -or
    $Related.definition.inputSchema.properties.min_score.minimum -ne 0 -or
    $Related.definition.inputSchema.properties.min_score.maximum -ne 1) {
    throw "related_files bounds changed"
}

$WinTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$WinQuery = Get-Content "windows/src/FileMCP.Core/RepositoryIntelligenceQuery.cs" -Raw
$WinTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$MacTools = Get-Content "macos/LocalMCPServer.swift" -Raw
$MacQuery = Get-Content "macos/RepositoryIntelligenceQuery.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Needle in @('"repo_map"', '"symbol_search"', '"related_files"')) {
    Require-Contains $WinTools $Needle "Windows LocalTools missing FMG-019 handler/budget surface: $Needle"
    Require-Contains $MacTools $Needle "macOS LocalTools missing FMG-019 handler/budget surface: $Needle"
}

foreach ($Needle in @(
    "AuthenticatedCursorCodec",
    "RequireQueryFreshAsync",
    "CaptureSourceStateRefAsync",
    "ArtifactContentClasses.ToolOutput",
    "raw_source_persisted",
    "grants_authority",
    "generation became stale",
    "after_artifact_publish",
    "DeleteAsync"
)) { Require-Contains $WinQuery $Needle "Windows FMG-019 invariant missing: $Needle" }

foreach ($Needle in @(
    "AuthenticatedCursorCodec",
    "requireQueryFresh",
    "captureSourceStateRef",
    "ArtifactContentClasses.toolOutput",
    "raw_source_persisted",
    "grants_authority",
    "generation became stale",
    "after_artifact_publish",
    "artifacts.delete"
)) { Require-Contains $MacQuery $Needle "macOS FMG-019 invariant missing: $Needle" }

# ContentRef delivery is not a query identity option: callers may continue the same map cursor
# while changing inline-vs-artifact delivery preference.
if ($WinQuery -match 'allowContentRef \? "artifact:on"') { throw "Windows repo_map cursor must not bind allow_content_ref" }
if ($MacQuery -match 'allowContentRef \? "artifact:on"') { throw "macOS repo_map cursor must not bind allow_content_ref" }

foreach ($Needle in @(
    "windows-repository-query: ok",
    "ambiguous exact symbols",
    "reports no symbol support",
    "Cursor generation is stale",
    "generation became stale",
    "authenticated ContentRef",
    "unavailable spill artifact",
    "ToolBudget output bound"
)) { Require-Contains $WinTests $Needle "Windows FMG-019 runtime proof missing: $Needle" }

foreach ($Needle in @(
    'print("swift-repository-query: ok")',
    'fmg019Map1Body["artifact_state"] as? String == "available"',
    'fmg019Symbols.structuredContent["ambiguous"] as? Bool == true',
    'fmg019NoSymbols.structuredContent["symbol_support"] as? Bool == false',
    '"generation is stale"',
    '"generation became stale"',
    'fmg019Unavailable.structuredContent["artifact_state"] as? String == "unavailable"',
    '"maxOutputItems": 2'
)) { Require-Contains $SwiftTests $Needle "macOS FMG-019 native proof missing: $Needle" }

foreach ($Path in @("build_macos_app.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    $Text = Get-Content $Path -Raw
    Require-Contains $Text "RepositoryIntelligenceQuery.swift" "$Path does not compile RepositoryIntelligenceQuery.swift"
}

Write-Host "repository-intelligence-query-contract: ok (catalog=1.13.0 tools=46 read-only query facade)"
