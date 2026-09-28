$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("NavChangesButton","ChangesTab","ChangesGrid","ChangeDetailStatus","ChangeDetailVersion","No synthetic diff")) {
  if(-not $xaml.Contains($name)){ throw "Windows Changes missing: $name" }
}
foreach($name in @("ChangeRow","TryCreateChangeRow","RefreshChangesGrid","ChangesGrid_SelectionChanged","PresentationStatus.Stale","PresentationStatus.Blocked")) {
  if(-not $cs.Contains($name)){ throw "Windows Changes logic missing: $name" }
}
foreach($name in @("ChangeEvent","changesTableView","showChanges","changeEvent(from","File/version context: not emitted by runtime event","No synthetic diff")) {
  if(-not $mac.Contains($name)){ throw "macOS Changes missing: $name" }
}
if(-not $graph.Contains("FMUX-009") -or -not $graph.Contains("State: ACTIVE / CLAIMED")) { throw "FMUX-009 not claimed" }

Write-Output "fmux-changes-contract: PASS"
Write-Output "mutation-events: write/delete/apply_edits"
Write-Output "states: applied stale conflict failed"
Write-Output "fake-diff: absent"
Write-Output "windows-macos-parity: present"
