$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { $script:failures.Add($Message) }
}
function Require-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { $script:failures.Add($Message) }
}
function Require-Count([string]$Text, [string]$Needle, [int]$Expected, [string]$Message) {
    $count = [regex]::Matches($Text, [regex]::Escape($Needle)).Count
    if ($count -ne $Expected) { $script:failures.Add("$Message (expected=$Expected actual=$count)") }
}

$architecture = Get-Content -Raw 'docs/design/FMUX_PRODUCT_EXPERIENCE_ARCHITECTURE_V1.md'
$interaction = Get-Content -Raw 'docs/design/FMUX_INTERACTION_STATE_AND_FMG_MAPPING_V1.md'
$audit = Get-Content -Raw 'docs/audit/FMUX_FINAL_REPAIR_REAUDIT_2026-09-28.md'
$design = Get-Content -Raw 'docs/design/FMUX_DESIGN_SYSTEM_AND_COMPONENT_SPEC_V1.md'
$graph = Get-Content -Raw 'tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md'
$workflow = Get-Content -Raw '.github/workflows/verify.yml'
$winApp = Get-Content -Raw 'windows/src/FileMCP.App/MainWindow.xaml.cs'
$winXaml = Get-Content -Raw 'windows/src/FileMCP.App/MainWindow.xaml'
$winFeedback = Get-Content -Raw 'windows/src/FileMCP.App/Presentation/FeedbackModels.cs'
$macApp = Get-Content -Raw 'macos/FileMCPApp.swift'
$macFeedback = Get-Content -Raw 'macos/FeedbackComponents.swift'

# Frozen FMUX-019 authority must remain explicit.
foreach ($needle in @(
    'views do not invent runtime state',
    'feature availability is capability-driven',
    'labels for security-critical concepts',
    'action outcome semantics'
)) { Require-Contains $architecture $needle "FMUX-019 architecture authority missing: $needle" }
foreach ($needle in @(
    'Every data surface identifies one of:',
    'No raw exception string as the only UX.',
    'connected',
    'stale evidence cannot display as passed without stale marker.'
)) { Require-Contains $interaction $needle "FMUX-019 interaction/security authority missing: $needle" }
foreach ($needle in @('Fake capability risk','Cross-platform drift','safety language','capability availability','action outcome')) {
    Require-Contains $audit $needle "FMUX-019 repaired-audit authority missing: $needle"
}
foreach ($needle in @('all controls keyboard reachable;','failures show next action when known;','EmptyState')) {
    Require-Contains $design $needle "FMUX-019 design-system authority missing: $needle"
}

# Keep the previously MAIN VERIFIED FMUX foundation contracts alive as one aggregate gate.
$foundationContracts = @(
    'test_fmux_presentation_contract.ps1',
    'test_fmux_app_shell_contract.ps1',
    'test_fmux_feedback_components_contract.ps1',
    'test_fmux_home_contract.ps1',
    'test_fmux_workspaces_contract.ps1',
    'test_fmux_connections_contract.ps1',
    'test_fmux_settings_policy_contract.ps1',
    'test_fmux_structured_activity_contract.ps1',
    'test_fmux_changes_contract.ps1',
    'test_fmux_evidence_contract.ps1',
    'test_fmux_artifact_batch_contract.ps1'
)
foreach ($contract in $foundationContracts) {
    $full = Join-Path $PSScriptRoot $contract
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $failures.Add("Missing FMUX foundation contract: $contract")
        continue
    }
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $full | Out-Host
    if ($LASTEXITCODE -ne 0) { $failures.Add("FMUX foundation contract failed: $contract exit=$LASTEXITCODE") }
}

# Gate continuity: run FMUX-019 exactly once in each Windows native job; preserve native/core proof.
Require-Count $workflow './tests/test_fmux_cross_platform_adversarial_gate.ps1' 2 'FMUX-019 adversarial gate must be wired exactly once in Windows x64 and native Windows ARM64 Verify jobs'
foreach ($needle in @(
    './tests/test_advanced_adversarial_gate.ps1',
    './tests/test_windows_runtime.ps1',
    './tests/test_windows_app.ps1',
    './tests/test_windows_app.ps1 -Architecture arm64',
    './build_macos_app.sh',
    './tests/test_swift_runtime.sh'
)) { Require-Contains $workflow $needle "FMUX-019 core/native regression proof missing from Verify: $needle" }

# Error contract: a caught exception must never be the entire user-facing UX.
Require-NotContains $winApp 'System.Windows.MessageBox.Show(this, ex.Message' 'Windows settings-load failure still exposes raw exception as the only UX'
Require-NotContains $winApp 'ShowError(ex.Message);' 'Windows caught exception still routes raw exception as the only UX'
Require-Contains $winApp 'ShowOperationalError(' 'Windows structured operational-error helper missing'
Require-Contains $winFeedback 'TechnicalDetail' 'Windows presentation feedback must retain optional technical detail'
Require-NotContains $macApp 'showError(error.localizedDescription)' 'macOS caught exception still routes raw exception as the only UX'
Require-Contains $macApp 'showOperationalError(' 'macOS structured operational-error helper missing'
Require-Contains $macFeedback 'technicalDetail' 'macOS presentation feedback must retain optional technical detail'

# Offline/error/empty/stale truth exists on both platforms; no synthetic success fallback.
foreach ($needle in @('No runtime is connected.','PresentationStatus.Stale','PresentationStatus.Unavailable','PresentationStatus.Failed')) {
    Require-Contains ($winXaml + $winApp) $needle "Windows offline/stale/error state missing: $needle"
}
foreach ($needle in @('No runtime is connected.','Disconnected','PTY backend unavailable.','Recovery data unavailable without expanding authority.')) {
    Require-Contains $macApp $needle "macOS offline/unavailable state missing: $needle"
}

# Keyboard-only completion must remain possible through native focus/action semantics.
foreach ($needle in @('PreviewKeyDown += OnPreviewKeyDown','AutomationProperties.Name="Home"','AutomationProperties.Name="Terminal PTY sessions"')) {
    Require-Contains ($winXaml + $winApp) $needle "Windows keyboard/accessibility path missing: $needle"
}
foreach ($needle in @('button.setAccessibilityLabel(title)','button.refusesFirstResponder = false','window.recalculateKeyViewLoop()')) {
    Require-Contains $macApp $needle "macOS keyboard/accessibility path missing: $needle"
}

# Feature/security language must remain truthful and non-authoritative.
foreach ($forbidden in @('Coming soon','Not implemented','Fake control','Fake state')) {
    Require-NotContains ($winXaml + $winApp + $macApp) $forbidden "Production presentation contains fake-capability wording: $forbidden"
}
foreach ($needle in @('presentation_grants_authority=false','Presentation grants no authority.','Docker not selected means not probed, not available.')) {
    Require-Contains ($winXaml + $winApp) $needle "Windows security-language invariant missing: $needle"
}
foreach ($needle in @('presentation_grants_authority=false','Presentation grants no authority.','Docker availability is not inferred while disconnected.')) {
    Require-Contains $macApp $needle "macOS security-language invariant missing: $needle"
}

$fmux019Start = $graph.IndexOf('## FMUX-019', [StringComparison]::Ordinal)
$fmux020Start = $graph.IndexOf('## FMUX-020', [StringComparison]::Ordinal)
if ($fmux019Start -lt 0 -or $fmux020Start -le $fmux019Start) {
    $failures.Add('FMUX-019 task graph section missing')
} else {
    $fmux019 = $graph.Substring($fmux019Start, $fmux020Start - $fmux019Start)
    Require-Contains $fmux019 'Branch: `chatgpt/FMUX-019-cross-platform-adversarial`.' 'FMUX-019 graph branch claim missing'
    if (-not $fmux019.Contains('State: ACTIVE / CLAIMED') -and -not $fmux019.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmux019.Contains('State: DONE / MAIN VERIFIED')) {
        $failures.Add('FMUX-019 lifecycle is not active/verified/done')
    }
}

if ($failures.Count -gt 0) {
    Write-Error ("fmux-cross-platform-ux-adversarial-gate: FAIL`n - " + ($failures -join "`n - "))
    exit 1
}

Write-Output 'fmux-cross-platform-ux-adversarial-gate: PASS'
Write-Output 'foundation-contracts: 11/11 live through aggregate gate'
Write-Output 'parity: Windows/macOS taxonomy/state/security/action truth retained'
Write-Output 'error-ux: structured operational failures; technical detail secondary'
Write-Output 'keyboard/offline/feature-gating/core-regression: retained'