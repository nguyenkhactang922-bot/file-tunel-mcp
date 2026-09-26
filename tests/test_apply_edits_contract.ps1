$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Catalog = Get-Content contracts/tool_catalog.v1.json -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.5.0") { throw "FMG-009 requires catalogVersion 1.5.0." }
if ($Catalog.tools.Count -ne 22) { throw "FMG-009 contracts remain present in the current 22-tool canonical catalog." }
$items = @($Catalog.tools | Where-Object name -eq "apply_edits")
if ($items.Count -ne 1) { throw "Missing canonical apply_edits tool." }
$tool = $items[0]
if ($tool.handler -ne "local_tools" -or $tool.risk -ne "high" -or $tool.effect -ne "write") { throw "apply_edits policy metadata mismatch." }
if (@($tool.capabilities) -notcontains "filesystem.write") { throw "apply_edits must require filesystem.write capability." }
$input = $tool.definition.inputSchema
foreach ($required in @("relative_path","expected_version","coordinate_system","edits")) {
    if (@($input.required) -notcontains $required) { throw "apply_edits missing required input: $required" }
}
if (@($input.properties.coordinate_system.enum) -notcontains "byte" -or @($input.properties.coordinate_system.enum) -notcontains "lineColumn") { throw "apply_edits coordinate systems are incomplete." }
if (@($input.properties.column_encoding.enum) -notcontains "utf8CodePoint") { throw "apply_edits lineColumn encoding must be utf8CodePoint." }
if ($input.properties.edits.minItems -ne 1 -or $input.properties.edits.maxItems -ne 1024) { throw "apply_edits edit-count bounds mismatch." }
if ($input.properties.dry_run.default -ne $false -or $input.properties.preserve_line_endings.default -ne $true -or $input.properties.preserve_bom.default -ne $true) { throw "apply_edits defaults mismatch." }

function Require-Marker([string]$Path, [string[]]$Markers) {
    $Text = Get-Content -LiteralPath $Path -Raw
    foreach ($Marker in $Markers) {
        if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) { throw "Missing FMG-009 marker '$Marker' in $Path" }
    }
}

Require-Marker "windows/src/FileMCP.Core/LocalTools.cs" @(
    '"apply_edits"',
    'ReadExpectedVersioned',
    'CompileEdits',
    'apply_edits contains overlapping ranges',
    '_policy.Authorize("apply_edits", preparedPolicy)',
    '_mutationGuard.Verify(snapshot)',
    '_fileVersions.VerifyExpectedVersion(relativePath, expectedVersion)',
    'stream.Flush(flushToDisk: true)',
    'File.Move(temp, target, true)',
    'after_commit',
    'cancelled_after_commit'
)
Require-Marker "macos/LocalMCPServer.swift" @(
    '"apply_edits"',
    'readExpectedVersioned',
    'compileEdits',
    'apply_edits contains overlapping ranges',
    'policy.authorize("apply_edits", prepared: preparedPolicy)',
    'mutationGuard.verify(snapshot)',
    'fileVersions.verifyExpectedVersion',
    'handle.synchronize()',
    'replaceItemAt(target, withItemAt: temp)',
    'after_commit',
    'cancelled_after_commit'
)
Require-Marker "windows/src/FileMCP.Core/FileVersionService.cs" @("ReadExpectedVersioned")
Require-Marker "macos/FileVersionService.swift" @("readExpectedVersioned")
Require-Marker "windows/tests/FileMCP.Core.Tests/Program.cs" @(
    "windows-apply-edits: ok",
    "same-offset insertions preserve request order",
    "overlapping edits",
    "UTF-8 boundary",
    "staging failure",
    "external writer",
    "path replacement",
    "cancellation before commit",
    "post-commit cancellation",
    "publish failure"
)
Require-Marker "tests/test_swift_runtime.sh" @(
    "swift-apply-edits: ok",
    "FMG-009 overlapping edits",
    "UTF-8 interior byte offset",
    "budget exhaustion",
    "external writer",
    "target replacement",
    "pre-commit cancellation",
    "cancelled_after_commit",
    "staging failure"
)

Write-Host "apply-edits-contract: ok (catalog=1.5.0 tools=22 version+guard+atomic+dry-run parity)"
