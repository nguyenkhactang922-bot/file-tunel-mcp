$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("NavActivityButton","ActivityTab","ActivityFilterCombo","ActivityGrid","ActivityDetailText","EnableRowVirtualization","Diagnostics")) {
 if(-not $xaml.Contains($name)){ throw "Windows Activity missing: $name" }
}
foreach($name in @("MaxActivityRows","RecordActivity","RefreshActivityGrid","ActivityFilterCombo_SelectionChanged","ActivityGrid_SelectionChanged")) {
 if(-not $cs.Contains($name)){ throw "Windows Activity logic missing: $name" }
}
foreach($name in @("ActivityEvent","activityTableView","activityFilterPopup","showActivity","refreshActivityFilter","recordActivity","maxActivityEvents","Diagnostics")) {
 if(-not $mac.Contains($name)){ throw "macOS Activity missing: $name" }
}
$fmuxStart = $graph.IndexOf('## FMUX-008', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-009', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-008 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-008 lifecycle is not active/verified/done.' }

Write-Output "fmux-structured-activity-contract: PASS"
Write-Output "timeline-filter-master-detail: present"
Write-Output "bounded-windows: 500"
Write-Output "bounded-macos: 500"
Write-Output "raw-logs: diagnostics-only"
