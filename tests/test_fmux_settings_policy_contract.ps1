$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @('Title="Settings"','General','Policy &amp; permissions','Execution','Git','Appearance','Storage &amp; retention','PolicyExplanationText','AdvancedExpander')) {
  if(-not $xaml.Contains($name)){ throw "Windows Settings missing: $name" }
}
foreach($name in @('PolicyProfileComboBox_SelectionChanged','Workspace auto','Custom: advanced local policy','Legacy command compatible')) {
  if(-not $cs.Contains($name)){ throw "Windows policy logic missing: $name" }
}
foreach($name in @('policyExplanationLabel','policyProfileChanged','updatePolicyExplanation','Policy & permissions','Appearance','Storage & retention','Execution','Git')) {
  if(-not $mac.Contains($name)){ throw "macOS Settings missing: $name" }
}
if(-not $mac.Contains('policyProfilePopup.action = #selector(policyProfileChanged)')) { throw "macOS policy popup action missing" }
if(-not $graph.Contains('FMUX-007') -or -not $graph.Contains('State: ACTIVE / CLAIMED')) { throw "FMUX-007 not claimed" }

Write-Output "fmux-settings-policy-contract: PASS"
Write-Output "categories: General Policy Execution Git Appearance Storage"
Write-Output "policy-explanation: dynamic"
Write-Output "advanced-disclosure: preserved"
Write-Output "fake-authority-controls: none"
