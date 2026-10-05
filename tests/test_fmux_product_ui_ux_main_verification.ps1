$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { $script:failures.Add($Message) }
}
function Require-Count([string]$Text, [string]$Needle, [int]$Expected, [string]$Message) {
    $count = [regex]::Matches($Text, [regex]::Escape($Needle)).Count
    if ($count -ne $Expected) { $script:failures.Add("$Message (expected=$Expected actual=$count)") }
}
function Require-File([string]$Path, [string]$Message, [long]$MinBytes = 1) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $script:failures.Add("$Message (missing=$Path)")
        return
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -lt $MinBytes) { $script:failures.Add("$Message (too-small=$Path bytes=$($item.Length))") }
}

$graph = Get-Content -Raw 'tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md'
$workflow = Get-Content -Raw '.github/workflows/verify.yml'
$evidencePath = 'docs/evidence/FMUX-020_PRODUCT_UI_UX_MAIN_VERIFICATION_EVIDENCE.md'
$coreMainVerified = 'docs/evidence/COMPLETE_UPGRADE_MAIN_VERIFIED.md'

# Dependency truth must already be durable before FMUX-020 can be active.
Require-File $coreMainVerified 'FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED evidence missing' 100
$fmux019Start = $graph.IndexOf('## FMUX-019', [StringComparison]::Ordinal)
$fmux020Start = $graph.IndexOf('## FMUX-020', [StringComparison]::Ordinal)
if ($fmux019Start -lt 0 -or $fmux020Start -le $fmux019Start) {
    $failures.Add('FMUX-019/FMUX-020 task graph sections missing')
} else {
    $fmux019 = $graph.Substring($fmux019Start, $fmux020Start - $fmux019Start)
    Require-Contains $fmux019 'State: DONE / MAIN VERIFIED' 'FMUX-019 is not recorded DONE / MAIN VERIFIED'
    Require-Contains $fmux019 'Governance state-sync: DONE / MAIN VERIFIED.' 'FMUX-019 governance closure is not recorded MAIN VERIFIED'

    $fmux020 = $graph.Substring($fmux020Start)
    Require-Contains $fmux020 'Branch: `chatgpt/FMUX-020-product-ui-ux-main-verification`.' 'FMUX-020 branch claim missing'
    if (-not $fmux020.Contains('State: ACTIVE / CLAIMED') -and -not $fmux020.Contains('State: ACTIVE / LOCAL VERIFIED') -and -not $fmux020.Contains('State: DONE / MAIN VERIFIED')) {
        $failures.Add('FMUX-020 lifecycle is not active/verified/done')
    }
}

# Keep the entire FMUX product contract live without replaying implementation tasks.
$productContracts = @(
    'test_fmux_cross_platform_adversarial_gate.ps1',
    'test_fmux_repository_intelligence_contract.ps1',
    'test_fmux_terminal_pty_contract.ps1',
    'test_fmux_recovery_contract.ps1',
    'test_fmux_backend_isolation_contract.ps1',
    'test_fmux_onboarding_contract.ps1',
    'test_fmux_accessibility_theme_contract.ps1',
    'test_fmux_performance_visual_consistency_contract.ps1'
)
foreach ($contract in $productContracts) {
    $full = Join-Path $PSScriptRoot $contract
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $failures.Add("Missing FMUX product contract: $contract")
        continue
    }
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $full | Out-Host
    if ($LASTEXITCODE -ne 0) { $failures.Add("FMUX product contract failed: $contract exit=$LASTEXITCODE") }
}

# Final candidate evidence must exist, but it must not falsely claim merged-main verification on branch.
Require-File $evidencePath 'FMUX-020 candidate evidence missing' 300
if (Test-Path -LiteralPath $evidencePath) {
    $evidence = Get-Content -Raw $evidencePath
    foreach ($needle in @(
        'LIVE CORE-TO-UI PROOF',
        'CURRENT-BUILD SCREENSHOT PROOF',
        'PID `14804`',
        '14/14',
        'LOCAL VERIFIED is not MAIN VERIFIED'
    )) { Require-Contains $evidence $needle "FMUX-020 evidence missing: $needle" }
}

# Screenshot artifacts are durable proof inputs. Current-build render is isolated and must cover all product pages.
foreach ($path in @(
    'docs/evidence/artifacts/FMUX-020/live-runtime-home.png',
    'docs/evidence/artifacts/FMUX-020/live-runtime-workspaces.png'
)) { Require-File $path 'FMUX-020 live runtime screenshot missing' 10000 }

$currentPages = @('setup','home','workspaces','connections','settings','activity','changes','evidence','repository','terminal','recovery','artifacts','backend','diagnostics')
foreach ($page in $currentPages) {
    Require-File ("docs/evidence/artifacts/FMUX-020/current-ui/$page.png") "FMUX-020 current-build screenshot missing: $page" 10000
}
Require-File 'docs/evidence/artifacts/FMUX-020/current-ui/render-report.txt' 'FMUX-020 current-build render report missing' 200
Require-File 'docs/evidence/artifacts/FMUX-020/current-ui/visual-qa-report.txt' 'FMUX-020 screenshot QA report missing' 500
if (Test-Path -LiteralPath 'docs/evidence/artifacts/FMUX-020/current-ui/visual-qa-report.txt') {
    $visualReport = Get-Content -Raw 'docs/evidence/artifacts/FMUX-020/current-ui/visual-qa-report.txt'
    Require-Contains $visualReport 'unique_page_hashes=14/14' 'FMUX-020 screenshot QA does not prove 14 unique page renders'
    Require-Contains $visualReport 'result=PASS' 'FMUX-020 screenshot QA report is not PASS'
}

# Verify must retain clean native build/package/smoke plus the final product gate on both Windows native jobs.
Require-Count $workflow './tests/test_fmux_product_ui_ux_main_verification.ps1' 2 'FMUX-020 final gate must run exactly once in Windows x64 and native Windows ARM64 Verify jobs'
foreach ($needle in @(
    './build_macos_app.sh',
    'dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror',
    'Build Windows x64 release',
    'Build Windows arm64 release',
    'Windows app smoke test',
    'Upload Windows x64 package',
    'Build Windows ARM64 release',
    'Windows ARM64 app smoke test',
    'Upload Windows ARM64 package',
    './tests/test_windows_runtime.ps1',
    './tests/test_swift_runtime.sh'
)) { Require-Contains $workflow $needle "FMUX-020 native build/package/core regression proof missing from Verify: $needle" }

if ($failures.Count -gt 0) {
    Write-Error ("fmux-product-ui-ux-main-verification: FAIL`n - " + ($failures -join "`n - "))
    exit 1
}

Write-Output 'fmux-product-ui-ux-main-verification: PASS'
Write-Output 'contracts: FMUX adversarial + repository/terminal/recovery/backend/onboarding/accessibility/performance retained'
Write-Output 'screenshots: live runtime 2/2 + current-build pages 14/14'
Write-Output 'native verification: macOS build + Windows x64/arm64 build/package/smoke + core regression retained'
Write-Output 'lifecycle: candidate/local evidence only; MAIN VERIFIED requires exact merged-main Verify'
