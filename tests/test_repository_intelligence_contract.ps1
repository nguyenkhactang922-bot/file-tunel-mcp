$ErrorActionPreference = "Stop"

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}
function Require-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -ge 0) { throw $Message }
}

$Win = Get-Content "windows/src/FileMCP.Core/RepositoryIntelligence.cs" -Raw
$WinTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$Mac = Get-Content "macos/RepositoryIntelligence.swift" -Raw
$MacTools = Get-Content "macos/LocalMCPServer.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw
$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json

foreach ($Needle in @(
    "interface IRepositoryIntelligenceProvider",
    "class LexicalSymbolProvider",
    'Completeness => "heuristic"',
    "CaptureSourceStateRefAsync",
    '"ls-files", "--cached", "-z"',
    "before_source_state_recheck",
    "Repository changed while intelligence index was being built",
    "raw_source_persisted",
    "grants_authority",
    "cache_status",
    "stale_deleted",
    "corrupt_deleted",
    "max_tracked_files"
)) { Require-Contains $Win $Needle "Windows FMG-018 invariant missing: $Needle" }

foreach ($Needle in @(
    "protocol RepositoryIntelligenceProvider",
    "final class LexicalSymbolProvider",
    'let completeness = "heuristic"',
    "RepositoryIntelligenceService",
    '["ls-files", "--cached", "-z", "--"]',
    "before_source_state_recheck",
    "Repository changed while intelligence index was being built",
    "raw_source_persisted",
    "grants_authority",
    "cache_status",
    "stale_deleted",
    "corrupt_deleted",
    "max_tracked_files"
)) { Require-Contains $Mac $Needle "macOS FMG-018 invariant missing: $Needle" }

Require-NotContains $Win "_policy.Authorize" "Repository intelligence must never participate in authorization."
Require-NotContains $Mac "policy.authorize" "Repository intelligence must never participate in authorization."

foreach ($Needle in @(
    "windows-repository-intelligence: ok",
    "baseline read_file remains independent",
    "does not persist raw full-source",
    "stale SourceStateRef invalidates",
    "corrupted cache is deleted",
    "parser/profile mismatch invalidates",
    "giant repository indexing is deterministically bounded",
    "SourceStateRef is revalidated"
)) { Require-Contains $WinTests $Needle "Windows FMG-018 proof missing: $Needle" }

foreach ($Needle in @(
    "swift-repository-intelligence: ok",
    "RAW_SECRET_MARKER_FMG018",
    "maxTrackedFiles = 2",
    "before_source_state_recheck",
    "Repository changed while intelligence index was being built"
)) { Require-Contains $SwiftTests $Needle "macOS FMG-018 proof missing: $Needle" }

foreach ($Path in @("build_macos_app.sh", ".github/workflows/verify.yml", "tests/test_swift_runtime.sh")) {
    $Text = Get-Content $Path -Raw
    Require-Contains $Text "RepositoryIntelligence.swift" "$Path does not compile RepositoryIntelligence.swift"
}

if ($Catalog.catalogVersion -ne "1.13.0" -or $Catalog.tools.Count -ne 46) {
    throw "FMG-018 core invariants must remain compatible with the current 1.13.0 / 41-tool public catalog."
}

Require-Contains $MacTools "func captureRepositoryIntelligence(" "macOS LocalTools internal FMG-018 bridge missing."
Require-Contains $MacTools "self.gitRepo(path)" "macOS FMG-018 must reuse existing safe gitRepo authority."
Require-Contains $MacTools "self.runGit(" "macOS FMG-018 must reuse existing safe runGit authority."
Require-Contains $MacTools "self.captureSourceStateRef(repoPath: path)" "macOS FMG-018 must reuse existing SourceStateRef authority."

Write-Host "repository-intelligence-contract: ok (metadata-cache, SourceStateRef-bound, no-authority, FMG-019-compatible)"
