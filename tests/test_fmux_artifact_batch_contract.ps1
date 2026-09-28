$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$winXaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$winCs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$winServer = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/LocalMcpServer.cs")
$macApp = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$macServer = Get-Content -Raw (Join-Path $Root "macos/LocalMCPServer.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @(
  "NavArtifactsButton",
  "ArtifactsTab",
  "ArtifactBatchGrid",
  "ArtifactEntryGrid",
  "ArtifactBatchSummaryText",
  "ArtifactQuotaSummaryText",
  "ArtifactEntryDetailText"
)) {
  if(-not $winXaml.Contains($name)) { throw "Windows Artifact/Batch UX missing: $name" }
}

foreach($name in @(
  "ArtifactBatchRow",
  "ArtifactBatchEntryRow",
  "TryCaptureArtifactBatchRow",
  "RefreshArtifactBatchGrid",
  "ArtifactBatchGrid_SelectionChanged",
  "ArtifactEntryGrid_SelectionChanged",
  "MaxArtifactBatchRows = 100",
  "Quota usage remaining is not emitted by batch results"
)) {
  if(-not $winCs.Contains($name)) { throw "Windows Artifact/Batch logic missing: $name" }
}

foreach($name in @(
  "EmitArtifactBatchUiEventSafely",
  "[ArtifactBatchResult]",
  "content_ref_present",
  "content_ref_count",
  "quota_error_count",
  "expires_epoch_ms",
  "blob_id"
)) {
  if(-not $winServer.Contains($name)) { throw "Windows structured projection missing: $name" }
}

$winProjectionStart = $winServer.IndexOf("private void EmitArtifactBatchUiEventSafely")
$winProjectionEnd = $winServer.IndexOf("private async Task<ToolCallOutput> EvidenceStatusOutputAsync", $winProjectionStart)
if($winProjectionStart -lt 0 -or $winProjectionEnd -le $winProjectionStart) { throw "Windows projection helper bounds not found" }
$winProjection = $winServer.Substring($winProjectionStart, $winProjectionEnd - $winProjectionStart)
if($winProjection.Contains('["content"]')) { throw "Windows projection must not copy inline file content" }
if($winProjection.Contains('["content_ref"]')) { throw "Windows projection must not log raw ContentRef tokens" }

foreach($name in @(
  "ArtifactBatchEvent",
  "ArtifactBatchEntryEvent",
  "artifactBatchTableView",
  "artifactEntryTableView",
  "captureArtifactBatchEvent",
  "showArtifacts",
  "maxArtifactBatchEvents = 100",
  "Remaining quota is not emitted by the batch result"
)) {
  if(-not $macApp.Contains($name)) { throw "macOS Artifact/Batch UX missing: $name" }
}

foreach($name in @(
  "emitArtifactBatchUIEventSafely",
  "[ArtifactBatchResult]",
  "content_ref_present",
  "content_ref_count",
  "quota_error_count",
  "expires_epoch_ms",
  "blob_id"
)) {
  if(-not $macServer.Contains($name)) { throw "macOS structured projection missing: $name" }
}

$macProjectionStart = $macServer.IndexOf("private func emitArtifactBatchUIEventSafely")
$macProjectionEnd = $macServer.IndexOf("private func evidenceStatusOutput", $macProjectionStart)
if($macProjectionStart -lt 0 -or $macProjectionEnd -le $macProjectionStart) { throw "macOS projection helper bounds not found" }
$macProjection = $macServer.Substring($macProjectionStart, $macProjectionEnd - $macProjectionStart)
if($macProjection.Contains('"content"')) { throw "macOS projection must not copy inline file content" }
if($macProjection.Contains('entry["content_ref"]') -or $macProjection.Contains('item["content_ref"]')) { throw "macOS projection must not log raw ContentRef tokens" }

if(-not $graph.Contains("FMUX-014") -or -not $graph.Contains("State: ACTIVE / CLAIMED")) {
  throw "FMUX-014 is not ACTIVE / CLAIMED in task graph"
}

Write-Output "fmux-artifact-batch-contract: PASS"
Write-Output "contentref-metadata: sanitized"
Write-Output "expiry-quota-observation: present"
Write-Output "large-output-inspection: present"
Write-Output "batch-grouped-partial-results: present"
Write-Output "bounded-history: 100"
Write-Output "windows-macos-parity: present"
