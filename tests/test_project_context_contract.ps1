$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content contracts/tool_catalog.v1.json -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.5.0") { throw "FMG-010 requires catalogVersion 1.5.0." }
if ($Catalog.tools.Count -ne 22) { throw "FMG-010 expects 22 canonical tools." }
$Tool = @($Catalog.tools | Where-Object name -eq "project_context")
if ($Tool.Count -ne 1) { throw "Missing canonical project_context tool." }
$Tool = $Tool[0]
if ($Tool.handler -ne "local_tools" -or $Tool.risk -ne "low" -or $Tool.effect -ne "read") { throw "project_context policy metadata drifted." }
if (@($Tool.capabilities) -notcontains "filesystem.read") { throw "project_context must require filesystem.read capability." }
$AvailabilityNames = @($Tool.availability.PSObject.Properties | ForEach-Object { $_.Name })
if ($AvailabilityNames -contains "requiresCommands") { throw "project_context must not require command authority." }
if (-not $Tool.definition.annotations.readOnlyHint -or $Tool.definition.annotations.destructiveHint -or $Tool.definition.annotations.openWorldHint) { throw "project_context annotations must remain read-only/non-destructive/non-open-world." }
$Input = $Tool.definition.inputSchema
if ($Input.properties.max_lines.maximum -ne 500 -or $Input.properties.max_lines.default -ne 120) { throw "project_context max_lines bounds drifted." }
if ($Input.properties.include_skills.default -ne $true) { throw "project_context include_skills default drifted." }
$Output = $Tool.definition.outputSchema.properties
if ($Output.grants_authority.const -ne $false) { throw "project_context must be schema-level non-authoritative." }
if ($Output.skill_instructions_included.const -ne $false) { throw "project_context must not inline skill instructions." }
if (@($Output.source_trust.enum) -notcontains "repository_untrusted") { throw "project_context trust marker drifted." }

function Require-Marker([string]$Path, [string[]]$Markers) {
    $Text = Get-Content $Path -Raw
    foreach ($Marker in $Markers) {
        if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) { throw "Missing FMG-010 marker '$Marker' in $Path." }
    }
}

Require-Marker "windows/src/FileMCP.Core/ProjectContextService.cs" @(
    'SchemaVersion = "1.0.0"',
    'MaxInstructionBytes = 256 * 1024',
    'MaxAggregateInstructionBytes = 1024 * 1024',
    'AGENTS.override.md',
    'AGENTS.md',
    'repository_untrusted',
    'grants_authority',
    'never grant or expand FileMCP authority',
    'AuthenticatedCursorCodec',
    'load_codex_skill',
    'instructions_included',
    'ComputeDigest',
    'ResolveForDeletion',
    'GetAttributesWithoutFollowingFinalTarget',
    '_pathGuard.Verify'
)
Require-Marker "macos/ProjectContextService.swift" @(
    'schemaVersion = "1.0.0"',
    'maxInstructionBytes = 256 * 1024',
    'maxAggregateInstructionBytes',
    'AGENTS.override.md',
    'AGENTS.md',
    'repository_untrusted',
    'grants_authority',
    'never grant or expand FileMCP authority',
    'AuthenticatedCursorCodec',
    'load_codex_skill',
    'instructions_included',
    'computeDigest',
    'lstat(',
    'pathGuard.captureExisting',
    'pathGuard.verify'
)
Require-Marker "windows/src/FileMCP.Core/CodexSkillRegistry.cs" @('SnapshotMetadata()', 'CodexSkillMetadata')
Require-Marker "macos/LocalMCPServer.swift" @('snapshotMetadata()', 'CodexSkillMetadata', 'skillRegistry: activeSkills', 'case "project_context"')
Require-Marker "windows/src/FileMCP.Core/LocalTools.cs" @('"project_context"', 'ProjectContextService')
Require-Marker "tests/test_swift_runtime.sh" @('swift-project-context: ok', 'mcp-project-context: ok')
Require-Marker "windows/tests/FileMCP.Core.Tests/Program.cs" @('windows-project-context: ok')

foreach ($Path in @("build_macos_app.sh", "run_macos_dev.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    Require-Marker $Path @("macos/ProjectContextService.swift")
}

$WindowsContext = Get-Content windows/src/FileMCP.Core/ProjectContextService.cs -Raw
$MacContext = Get-Content macos/ProjectContextService.swift -Raw
foreach ($Text in @($WindowsContext, $MacContext)) {
    if ($Text -match 'instructions_included[^\r\n]*true') { throw "Project Context must never mark skill instructions as inlined." }
}

Write-Host "project-context-contract: ok (catalog=1.5.0 tools=22 provenance+digest+cursor+no-authority parity)"
