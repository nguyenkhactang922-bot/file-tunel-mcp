$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$win = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/RepositoryIntelligenceService.cs")
$winTools = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/LocalTools.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/RepositoryIntelligence.swift")
$macTools = Get-Content -Raw (Join-Path $Root "macos/LocalMCPServer.swift")
$catalog = Get-Content -Raw (Join-Path $Root "contracts/tool_catalog.v1.json") | ConvertFrom-Json
$buildMac = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")
$verify = Get-Content -Raw (Join-Path $Root ".github/workflows/verify.yml")
$swiftRuntime = Get-Content -Raw (Join-Path $Root "tests/test_swift_runtime.sh")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md")

foreach($token in @(
  "IRepositoryIntelligenceProvider",
  "LexicalSymbolProvider",
  "HeuristicCompleteness",
  "RepositoryIntelligenceService",
  "CacheSchemaVersion",
  "MaxTrackedFiles = 20_000",
  '["ls-files", "-z", "--cached"]',
  "source_state_id",
  "binary_or_non_utf8",
  "CleanupStaleGenerations",
  "Repository intelligence cache must be outside the workspace"
)) {
  if(-not $win.Contains($token)) { throw "Windows repository intelligence contract missing: $token" }
}

foreach($token in @(
  "RepositoryIntelligenceProvider",
  "LexicalSymbolProvider",
  "heuristicCompleteness",
  "RepositoryIntelligenceService",
  "cacheSchemaVersion",
  "maxTrackedFiles = 20_000",
  "source_state_id",
  "binary_or_non_utf8",
  "cleanupStaleGenerations",
  "Repository intelligence cache must be outside the workspace"
)) {
  if(-not $mac.Contains($token)) { throw "macOS repository intelligence contract missing: $token" }
}

if(-not $winTools.Contains("GetRepositoryIntelligenceAsync")) { throw "Windows LocalTools does not wire repository intelligence core" }
if(-not $macTools.Contains("getRepositoryIntelligence")) { throw "macOS LocalTools does not wire repository intelligence core" }

if(-not $buildMac.Contains("macos/RepositoryIntelligence.swift")) { throw "macOS release build does not compile repository intelligence" }
if(-not $verify.Contains("macos/RepositoryIntelligence.swift")) { throw "native Verify typecheck does not compile repository intelligence" }
if(($swiftRuntime.Split("macos/RepositoryIntelligence.swift").Count - 1) -lt 2) { throw "Swift runtime compile bundles do not include repository intelligence" }
if(-not $swiftRuntime.Contains("swift-repository-intelligence-core: ok")) { throw "Swift runtime lacks FMG-018 behavior proof" }

if($catalog.catalogVersion -ne "1.9.0") { throw "FMG-018 must not bump canonical catalog before FMG-019" }
if($catalog.tools.Count -ne 31) { throw "FMG-018 must retain 31 canonical tools" }
$names = @($catalog.tools | ForEach-Object { $_.name })
foreach($future in @("repo_map","symbol_search","related_files")) {
  if($names -contains $future) { throw "$future belongs to FMG-019, not FMG-018" }
}

if($graph -notmatch '(?s)## FMG-018 - Repository Intelligence Core / Cache\s+State: CLAIMED / ACTIVE') {
  throw "FMG-018 task graph is not CLAIMED / ACTIVE"
}
if($graph -notmatch '(?s)## FMG-019 - repo_map / symbol_search / related_files\s+State: BLOCKED') {
  throw "FMG-019 must remain BLOCKED until FMG-018 MAIN VERIFIED"
}

Write-Output "repository-intelligence-contract: PASS"
Write-Output "provider: lexical / heuristic"
Write-Output "cache: metadata-only / SourceStateRef-bound / rebuildable"
Write-Output "inventory: Git-tracked / ignored-segment policy / bounded"
Write-Output "tool-surface: unchanged (1.9.0 / 31 tools)"
Write-Output "FMG-019 facade: still blocked"
