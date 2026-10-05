$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$core = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/EvidenceCoordinator.cs")
$macApp = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$macEvidence = Get-Content -Raw (Join-Path $Root "macos/EvidenceSupport.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("NavEvidenceButton","EvidenceTab","EvidenceGrid","EvidenceDetailStatus","Server-owned verification records")) {
  if(-not $xaml.Contains($name)){ throw "Windows Evidence missing: $name" }
}
foreach($name in @("EvidenceRow","TryCaptureEvidenceRow","RefreshEvidenceGrid","EvidenceGrid_SelectionChanged","not-applicable","policy_hash","catalog_hash")) {
  if(-not $cs.Contains($name)){ throw "Windows Evidence logic missing: $name" }
}
if(-not $core.Contains("[EvidenceResult]")) { throw "Windows server evidence completion signal missing" }
foreach($name in @("EvidenceEvent","evidenceTableView","showEvidence","captureEvidenceEvent","not-applicable","policyHash","catalogHash")) {
  if(-not $macApp.Contains($name)){ throw "macOS Evidence missing: $name" }
}
if(-not $macEvidence.Contains("[EvidenceResult]")) { throw "macOS server evidence completion signal missing" }
foreach($state in @("passed","failed","stale","blocked","not-run","unknown","not-applicable")) {
  if(-not (($cs+$core+$macApp+$macEvidence).Contains($state))) { throw "Evidence state coverage missing: $state" }
}
$fmuxStart = $graph.IndexOf('## FMUX-010', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-011', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-010 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-010 lifecycle is not active/verified/done.' }

Write-Output "fmux-evidence-contract: PASS"
Write-Output "states: passed failed stale blocked not-run unknown N/A"
Write-Output "linkage: source policy catalog"
Write-Output "completion-signal: server-owned metadata only"
Write-Output "windows-macos-parity: present"
