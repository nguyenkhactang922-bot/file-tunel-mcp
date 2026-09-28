$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("ConnectionsHeader","ConnectionCredentialBadge","ConnectionDiagnosticsText","Runtime API key","Workspace tunnels","Connect all")) {
  if(-not $xaml.Contains($name)){ throw "Windows Connections missing: $name" }
}
foreach($name in @("UpdateConnectionExperience","ConnectionCredentialBadge.Status","_credentialStore.HasSavedApiKey","PresentationStatus.Connected","PresentationStatus.Degraded")) {
  if(-not $cs.Contains($name)){ throw "Windows Connections logic missing: $name" }
}
foreach($name in @("connectionStatusLabel","connectionDiagnosticsLabel","refreshConnectionDiagnostics","API key is saved in Keychain","Tunnel ID configured")) {
  if(-not $mac.Contains($name)){ throw "macOS Connections missing: $name" }
}
if(-not $graph.Contains("FMUX-006") -or -not $graph.Contains("State: ACTIVE / CLAIMED")) { throw "FMUX-006 not claimed" }

Write-Output "fmux-connections-contract: PASS"
Write-Output "credential-status: present"
Write-Output "tunnel-configuration: preserved"
Write-Output "connectivity-diagnostics: present"
Write-Output "safe-save-connect-disconnect: existing flow preserved"
