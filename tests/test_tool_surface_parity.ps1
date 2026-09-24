$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$CatalogPath = "contracts/tool_catalog.v1.json"
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
    throw "Canonical tool catalog is missing: $CatalogPath"
}
$Catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
if ($Catalog.schemaVersion -ne 1) { throw "Unexpected catalog schemaVersion: $($Catalog.schemaVersion)" }
if ($Catalog.catalogVersion -ne "1.0.0") { throw "Unexpected catalogVersion: $($Catalog.catalogVersion)" }
if ($Catalog.instructionVersion -ne "1.0.0") { throw "Unexpected instructionVersion: $($Catalog.instructionVersion)" }
if ($Catalog.protocolVersions.modern -ne "2026-07-28") { throw "Canonical modern protocol drifted." }
$Tools = @($Catalog.tools)
if ($Tools.Count -ne 19) { throw "Expected 19 canonical tools, got $($Tools.Count)." }
$Names = @($Tools | ForEach-Object { [string]$_.name })
if (($Names | Sort-Object -Unique).Count -ne $Names.Count) { throw "Canonical tool names are not unique." }

$WindowsSource = @(
    Get-Content "windows/src/FileMCP.Core/CanonicalToolCatalog.cs" -Raw
    Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
    Get-Content "windows/src/FileMCP.Core/CodexSkillRegistry.cs" -Raw
    Get-Content "windows/src/FileMCP.Core/LocalMcpServer.cs" -Raw
) -join "`n"
$MacSource = @(
    Get-Content "macos/ToolCatalog.swift" -Raw
    Get-Content "macos/LocalMCPServer.swift" -Raw
) -join "`n"

foreach ($Tool in $Names) {
    $Quoted = '"' + $Tool + '"'
    if ($WindowsSource.IndexOf($Quoted, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows handler/wiring source is missing canonical tool '$Tool'."
    }
    if ($MacSource.IndexOf($Quoted, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS handler/wiring source is missing canonical tool '$Tool'."
    }
}

$WindowsProject = Get-Content "windows/src/FileMCP.Core/FileMCP.Core.csproj" -Raw
if ($WindowsProject.IndexOf('contracts\tool_catalog.v1.json', [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
    $WindowsProject.IndexOf('FileMCP.Contracts.tool_catalog.v1.json', [StringComparison]::Ordinal) -lt 0) {
    throw "Windows project does not embed the canonical catalog."
}
foreach ($Marker in @(
    'CanonicalToolCatalog.ToolDefinitions("local_tools"',
    'CanonicalToolCatalog.ToolDefinitions("skills"',
    'CanonicalToolCatalog.ToolDefinition("filemcp_observability_connect")',
    'CanonicalToolCatalog.ValidateHandlerCoverage',
    'CanonicalToolCatalog.ValidateProtocolContract',
    '["catalog"] = CanonicalToolCatalog.Metadata'
)) {
    if ($WindowsSource.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows canonical catalog wiring missing marker: $Marker"
    }
}
foreach ($Marker in @(
    'CanonicalToolCatalog.shared.toolDefinitions(handler: "local_tools"',
    'CanonicalToolCatalog.shared.toolDefinitions(handler: "skills")',
    'CanonicalToolCatalog.shared.toolDefinition(named: "filemcp_observability_connect")',
    'validateHandlerCoverage(handler:',
    'validateProtocolContract(modern:',
    '"catalog": CanonicalToolCatalog.shared.metadata'
)) {
    if ($MacSource.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS canonical catalog wiring missing marker: $Marker"
    }
}

if ((Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw).IndexOf('private static JsonObject Tool(', [StringComparison]::Ordinal) -ge 0) {
    throw "Windows still contains an alternate hard-coded tool schema builder."
}
if ((Get-Content "macos/LocalMCPServer.swift" -Raw).IndexOf('private func tool(', [StringComparison]::Ordinal) -ge 0) {
    throw "macOS still contains an alternate hard-coded tool schema builder."
}

foreach ($Source in @($WindowsSource, $MacSource)) {
    if ($Source.IndexOf('filemcp_observability_connect', [StringComparison]::Ordinal) -lt 0) {
        throw "A platform is missing observability-connect handler coverage."
    }
    if ($Source.IndexOf('_filemcp_chat', [StringComparison]::Ordinal) -lt 0 -and
        $Source.IndexOf('CorrelationArgument', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "A platform is missing the reserved correlation facade wiring."
    }
}

$MacBuild = Get-Content "build_macos_app.sh" -Raw
$MacTests = Get-Content "tests/test_swift_runtime.sh" -Raw
if ($MacBuild.IndexOf('macos/ToolCatalog.swift', [StringComparison]::Ordinal) -lt 0 -or
    $MacBuild.IndexOf('Contents/Resources/tool_catalog.v1.json', [StringComparison]::Ordinal) -lt 0) {
    throw "macOS build does not compile/package the canonical catalog."
}
if ($MacTests.IndexOf('macos/ToolCatalog.swift', [StringComparison]::Ordinal) -lt 0) {
    throw "macOS runtime tests do not compile the canonical catalog loader."
}

$CatalogText = [System.IO.File]::ReadAllText((Resolve-Path $CatalogPath))
if ($CatalogText.Length -gt 0 -and [int][char]$CatalogText[0] -eq 0xFEFF) { $CatalogText = $CatalogText.Substring(1) }
$NormalizedCatalogText = $CatalogText.Replace(([string][char]13 + [string][char]10), [string][char]10).Replace([string][char]13, [string][char]10)
$CatalogBytes = [System.Text.Encoding]::UTF8.GetBytes($NormalizedCatalogText)
$Sha = [System.Security.Cryptography.SHA256]::Create()
try { $HashBytes = $Sha.ComputeHash($CatalogBytes) } finally { $Sha.Dispose() }
$Hash = ([System.BitConverter]::ToString($HashBytes)).Replace("-", "").ToLowerInvariant()
if ($Hash.Length -ne 64) { throw "Canonical catalog SHA-256 is invalid." }
Write-Host "tool-surface-parity: ok (canonical=$($Tools.Count), sha256=$Hash)"
