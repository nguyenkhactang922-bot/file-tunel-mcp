$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot

$windowsXaml = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/MainWindow.xaml")
$windowsApp = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/App.xaml.cs")
$windowsStyles = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Resources/ComponentStyles.xaml")
$windowsTokens = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.App/Resources/DesignTokens.xaml")
$mac = Get-Content -Raw (Join-Path $Root "macos/FileMCPApp.swift")
$graph = Get-Content -Raw (Join-Path $Root "tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md")

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { throw $Message }
}

function Section-Between([string]$Text, [string]$Start, [string]$End) {
    $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
    if ($startIndex -lt 0) { throw "Missing section start: $Start" }
    $endIndex = $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
    if ($endIndex -lt 0) { throw "Missing section end: $End" }
    return $Text.Substring($startIndex, $endIndex - $startIndex)
}

# Windows: system theme/high-contrast truth, visible keyboard focus and semantic resources.
foreach ($needle in @(
    'SystemParameters.HighContrast',
    'SystemEvents.UserPreferenceChanged',
    'AppsUseLightTheme',
    'FileMcpSurfaceAppBrush',
    'FileMcpTextPrimaryBrush',
    'FileMcpAccentPrimaryBrush'
)) {
    Assert-Contains $windowsApp $needle "Windows accessibility/theme enforcement missing: $needle"
}
foreach ($needle in @(
    'Background="{DynamicResource FileMcpSurfaceAppBrush}"',
    'Foreground="{DynamicResource FileMcpTextPrimaryBrush}"',
    'FocusVisualStyle" Value="{DynamicResource FileMcpKeyboardFocusVisual}"',
    'AutomationProperties.Name="Home"',
    'AutomationProperties.Name="Repository intelligence"',
    'AutomationProperties.Name="Terminal PTY sessions"',
    'ResizeMode="CanResizeWithGrip"',
    'TextWrapping="Wrap"'
)) {
    Assert-Contains ($windowsXaml + $windowsStyles) $needle "Windows keyboard/accessibility/reflow contract missing: $needle"
}
Assert-Contains $windowsTokens 'FileMcpCodeTextBrush' 'Windows code text must use a semantic theme brush.'
Assert-Contains $windowsXaml 'Background="{DynamicResource FileMcpSurfaceCodeBrush}" Foreground="{DynamicResource FileMcpCodeTextBrush}"' 'Windows diagnostics code surface must follow semantic theme resources.'

# macOS: native system appearance, keyboard focusability/accessibility names and scalable window.
foreach ($needle in @(
    'button.setAccessibilityLabel(title)',
    'button.setAccessibilityHelp("Navigate to \(title)")',
    'button.refusesFirstResponder = false',
    'styleMask: [.titled, .closable, .miniaturizable, .resizable]',
    'window.contentMinSize = NSSize(width: Layout.windowWidth, height: Layout.collapsedWindowHeight)',
    'window.recalculateKeyViewLoop()',
    '.secondaryLabelColor',
    'NSTextField(wrappingLabelWithString:'
)) {
    Assert-Contains $mac $needle "macOS keyboard/accessibility/reflow contract missing: $needle"
}
Assert-NotContains $mac 'window.appearance =' 'macOS must follow system appearance instead of forcing a window theme.'
Assert-NotContains $mac 'NSApp.appearance =' 'macOS must follow system appearance instead of forcing an app theme.'

# Reduced motion: Windows has no decorative animation surface; the existing macOS loading border must be gated by the system reduce-motion preference.
foreach ($needle in @('<Storyboard', 'DoubleAnimation', 'ColorAnimation', 'ThicknessAnimation')) {
    Assert-NotContains $windowsXaml $needle "Windows decorative animation requires explicit reduced-motion handling: $needle"
}
foreach ($needle in @('NSAnimationContext', 'NSViewAnimation')) {
    Assert-NotContains $mac $needle "macOS decorative animation requires explicit reduced-motion handling: $needle"
}
Assert-Contains $mac 'accessibilityDisplayShouldReduceMotion' 'macOS loading animation must respect the system reduced-motion preference.'

$fmux017 = Section-Between $graph '## FMUX-017' '## FMUX-018'
Assert-Contains $fmux017 'Branch: `chatgpt/FMUX-017-accessibility`.' 'FMUX-017 graph must identify its implementation branch.'
if (-not $fmux017.Contains('State: ACTIVE / CLAIMED') -and -not $fmux017.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmux017.Contains('State: DONE / MAIN VERIFIED')) {
    throw 'FMUX-017 lifecycle must be active during verification or DONE / MAIN VERIFIED after closure.'
}

Write-Output "fmux-accessibility-theme-contract: PASS"
Write-Output "keyboard-focus: explicit/native"
Write-Output "theme: system light/dark/high-contrast aware"
Write-Output "accessible-navigation: named on Windows/macOS"
Write-Output "reflow: resizable windows + wrapping content"
Write-Output "reduced-motion: no decorative animation surface"
