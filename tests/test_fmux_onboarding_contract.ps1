$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$cs = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml.cs")
$contracts = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/Contracts.cs")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

foreach($needle in @("NavOnboardingButton","OnboardingTab","Welcome to FileMCP","Configure workspace","Choose policy","Configure connection","Test connection","Finish setup")) {
  if(-not $xaml.Contains($needle)){ throw "Windows onboarding missing: $needle" }
}
foreach($needle in @("InitializeOnboardingExperience","RefreshOnboardingExperience","HasExistingConfiguredSetup","AllEnabledWorkspacesRunning","OnboardingTestConnection_Click","OnboardingFinish_Click","_settings.OnboardingCompleted = true","Connect_Click(sender, e)")) {
  if(-not $cs.Contains($needle)){ throw "Windows onboarding logic missing: $needle" }
}
if(-not $contracts.Contains("public bool OnboardingCompleted { get; set; }")){ throw "Windows onboarding completion marker missing" }
if($cs.Contains("OnboardingApiKey") -or $cs.Contains("OnboardingCredentialStore")){ throw "Windows onboarding must not create a parallel credential store" }

foreach($needle in @("onboardingCompleted","Welcome to FileMCP","initializeOnboardingExperience","refreshOnboardingExperience","showOnboarding","testOnboardingConnection","finishOnboarding","storage.hasSavedAPIKey","startTunnel()","runtime reports Running")) {
  if(-not $mac.Contains($needle)){ throw "macOS onboarding missing: $needle" }
}
if($mac.Contains("OnboardingAPIKey") -or $mac.Contains("OnboardingCredentialStore")){ throw "macOS onboarding must not create a parallel credential store" }

$start = $graph.IndexOf("## FMUX-016", [StringComparison]::Ordinal)
$end = $graph.IndexOf("## FMUX-017", $start + 1, [StringComparison]::Ordinal)
if($start -lt 0 -or $end -lt 0){ throw "FMUX-016 graph section missing" }
$section = $graph.Substring($start, $end - $start)
if(-not $section.Contains("chatgpt/FMUX-016-onboarding")){ throw "FMUX-016 branch claim missing" }
if(-not $section.Contains("State: ACTIVE / CLAIMED") -and -not $section.Contains("State: ACTIVE / LOCAL VERIFIED") -and -not $section.Contains("State: DONE / MAIN VERIFIED")) {
  throw "FMUX-016 lifecycle state is invalid"
}

Write-Output "fmux-onboarding-contract: PASS"
Write-Output "first-run-marker: presentation-only"
Write-Output "credential-store: existing secure store reused"
Write-Output "connection-test: existing runtime start/connect + Running truth"
Write-Output "completion-handoff: Home"
