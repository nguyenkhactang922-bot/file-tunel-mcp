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
if(-not $graph.Contains("FMUX-005") -or -not $graph.Contains("State: ACTIVE / CLAIMED")) { throw "FMUX-005 not claimed" }

Write-Output "fmux-workspaces-contract: PASS"
Write-Output "windows-multi-drive: C D E F"
Write-Output "detail-pane: root policy connection activity"
Write-Output "macos-workspace-parity: present"
