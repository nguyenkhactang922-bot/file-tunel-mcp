$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$win = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Presentation/FeedbackModels.cs")
$status = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Controls/StatusBadge.cs")
$notice = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Controls/InlineNotice.cs")
$empty = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Controls/EmptyState.cs")
$header = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Controls/PageHeader.cs")
$xaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$mac = Get-Content -Raw (Join-Path $Root "macos/FeedbackComponents.swift")
$build = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")

foreach($name in @("PresentationDataState","NotificationSurface","PresentationFeedback","NotificationPolicy")) {
    if(-not $win.Contains($name)){ throw "Windows feedback model missing: $name" }
}
foreach($name in @("class StatusBadge","class InlineNotice","class EmptyState","class PageHeader")) {
    $all=$status+$notice+$empty+$header
    if(-not $all.Contains($name)){ throw "Windows component missing: $name" }
}
if(-not $xaml.Contains('controls:StatusBadge x:Name="ShellStatusBadge"')) {
    throw "Windows shell does not consume StatusBadge."
}
foreach($name in @("FileMCPPresentationDataState","FileMCPNotificationSurface","FileMCPPresentationFeedback","FileMCPNotificationPolicy","FileMCPFeedbackComponents")) {
    if(-not $mac.Contains($name)){ throw "macOS feedback component missing: $name" }
}
if(-not $build.Contains('macos/FeedbackComponents.swift')) { throw "macOS build wiring missing FeedbackComponents.swift" }
if(-not $win.Contains("FirstLoad") -or -not $win.Contains("Refreshing") -or -not $win.Contains("Empty") -or -not $win.Contains("Partial") -or -not $win.Contains("Error") -or -not $win.Contains("Stale")) {
    throw "Canonical data-state coverage incomplete."
}
Write-Output "fmux-feedback-components-contract: PASS"
Write-Output "windows-components: StatusBadge InlineNotice EmptyState PageHeader"
Write-Output "macos-components: semantic parity present"
Write-Output "notification-policy: present"
Write-Output "loading-refresh-empty-error-stale: covered"
