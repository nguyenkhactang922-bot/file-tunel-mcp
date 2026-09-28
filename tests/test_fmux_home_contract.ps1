$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("HomeHeader","HomeActiveWorkspacesText","HomeRunningWorkText","HomeRecentEventText","Connections","Settings")) {
  if(-not $xaml.Contains($name)) { throw "Windows Home missing: $name" }
}
foreach($name in @("UpdateHomeSummary","_lastImportantEvent","PresentationStatus.Healthy","PresentationStatus.Degraded")) {
  if(-not $cs.Contains($name)) { throw "Windows Home logic missing: $name" }
}
foreach($name in @('identifier: "home"','navigationButton("Home"','showHome','homeWorkspaceLabel','homeRecentEventLabel','refreshHomeSummary')) {
  if(-not $mac.Contains($name)) { throw "macOS Home missing: $name" }
}
if(-not $graph.Contains("FMUX-004") -or -not $graph.Contains("State: ACTIVE / CLAIMED")) {
  throw "FMUX-004 not claimed."
}
Write-Output "fmux-home-contract: PASS"
Write-Output "health-workspace-running-recent-event: covered"
Write-Output "quick-actions: Connections Settings"
Write-Output "windows-macos-home-parity: present"
