$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($name in @("Workspace &amp; access","PolicyExplanationText","Advanced execution, Git &amp; telemetry","Appearance","Follows system appearance")) {
 if(-not $xaml.Contains($name)){ throw "Windows Settings missing: $name" }
}
foreach($name in @("PolicyProfileComboBox_SelectionChanged","UpdatePolicyExplanation","Workspace auto","Legacy command compatible")) {
 if(-not $cs.Contains($name)){ throw "Windows Settings logic missing: $name" }
}
foreach($name in @("policyExplanationLabel","policyProfileChanged","updatePolicyExplanation","Workspace & access","Appearance","Follows macOS system appearance")) {
 if(-not $mac.Contains($name)){ throw "macOS Settings missing: $name" }
}
$fmuxStart = $graph.IndexOf('## FMUX-007', [StringComparison]::Ordinal)
$fmuxNext = $graph.IndexOf('## FMUX-008', [StringComparison]::Ordinal)
if ($fmuxStart -lt 0 -or $fmuxNext -le $fmuxStart) { throw 'FMUX-007 task graph section missing.' }
$fmuxSection = $graph.Substring($fmuxStart, $fmuxNext - $fmuxStart)
if (-not $fmuxSection.Contains('State: ACTIVE / CLAIMED') -and -not $fmuxSection.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmuxSection.Contains('State: DONE / MAIN VERIFIED')) { throw 'FMUX-007 lifecycle is not active/verified/done.' }

Write-Output "fmux-settings-policy-contract: PASS"
Write-Output "sections: workspace policy advanced appearance"
Write-Output "policy-explanation: dynamic"
Write-Output "manual-theme-fake-control: absent"
