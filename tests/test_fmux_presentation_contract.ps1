$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$WindowsStatus = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Presentation/PresentationStatus.cs")
$WindowsNav = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Presentation/NavigationDestination.cs")
$WindowsApp = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/App.xaml")
$MacFoundation = Get-Content -Raw (Join-Path $Root "macos/PresentationFoundation.swift")
$MacBuild = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")

$statuses = @("Healthy","Connected","Starting","Running","Stopping","Stopped","Degraded","Warning","Blocked","Failed","Stale","Verifying","Passed","Cancelled","Expired","Unavailable")
foreach ($status in $statuses) {
    if ($WindowsStatus -notmatch [regex]::Escape("PresentationStatus.$status")) {
        throw "Windows presentation status missing: $status"
    }
}

$macStatuses = @("healthy","connected","starting","running","stopping","stopped","degraded","warning","blocked","failed","stale","verifying","passed","cancelled","expired","unavailable")
foreach ($status in $macStatuses) {
    if ($MacFoundation -notmatch [regex]::Escape("case .$status")) {
        throw "macOS presentation status missing: $status"
    }
}

$destinations = @("Home","Workspaces","Activity","Changes","Repository","Terminal","Recovery","Evidence","Connections","Settings")
foreach ($destination in $destinations) {
    if ($WindowsNav -notmatch [regex]::Escape("NavigationDestination.$destination")) {
        throw "Windows navigation destination missing: $destination"
    }
}

foreach ($required in @("Resources/DesignTokens.xaml","Resources/ComponentStyles.xaml")) {
    if ($WindowsApp -notmatch [regex]::Escape($required)) {
        throw "App.xaml missing merged resource: $required"
    }
}

if ($MacBuild -notmatch [regex]::Escape('macos/PresentationFoundation.swift')) {
    throw "macOS build script does not compile PresentationFoundation.swift"
}

Write-Output "fmux-presentation-contract: PASS"
Write-Output "statuses: 16/16 cross-platform"
Write-Output "navigation: 10 destinations"
Write-Output "windows-resources: merged"
Write-Output "macos-build-wiring: present"
