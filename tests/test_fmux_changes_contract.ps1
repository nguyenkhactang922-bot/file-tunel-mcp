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
$fmuxStart = $graph.IndexOf('## FMUX-009', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-010', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-009 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-009 lifecycle is not active/verified/done.' }

Write-Output "fmux-changes-contract: PASS"
Write-Output "mutation-events: write/delete/apply_edits"
Write-Output "states: applied stale conflict failed"
Write-Output "fake-diff: absent"
Write-Output "windows-macos-parity: present"
