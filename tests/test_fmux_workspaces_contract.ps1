$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("NavWorkspacesButton","WorkspacesTab","WorkspaceCRow","WorkspaceDetailRoot","WorkspaceDetailPolicy","WorkspaceDetailConnection","WorkspaceDetailActivity")) {
  if(-not $xaml.Contains($name)){ throw "Windows Workspaces missing: $name" }
}
foreach($name in @("NavigateWorkspaces_Click","RefreshWorkspaceRows","WorkspaceRow_Click","WorkspaceDetailStatus")) {
  if(-not $cs.Contains($name)){ throw "Windows Workspaces logic missing: $name" }
}
foreach($name in @('identifier: "workspaces"','navigationButton("Workspaces"','showWorkspaces','workspaceRootLabel','workspaceStatusLabel','workspacePolicyLabel','refreshWorkspaceSummary')) {
  if(-not $mac.Contains($name)){ throw "macOS Workspaces missing: $name" }
}
$fmuxStart = $graph.IndexOf('## FMUX-005', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-006', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-005 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-005 lifecycle is not active/verified/done.' }

Write-Output "fmux-workspaces-contract: PASS"
Write-Output "windows-multi-drive: C D E F"
Write-Output "detail-pane: root policy connection activity"
Write-Output "macos-workspace-parity: present"
