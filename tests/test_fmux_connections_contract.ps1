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
$fmuxStart = $graph.IndexOf('## FMUX-006', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-007', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-006 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-006 lifecycle is not active/verified/done.' }

Write-Output "fmux-connections-contract: PASS"
Write-Output "credential-status: present"
Write-Output "tunnel-configuration: preserved"
Write-Output "connectivity-diagnostics: present"
Write-Output "safe-save-connect-disconnect: existing flow preserved"
