$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$CatalogObject = (Get-Content "contracts/tool_catalog.v1.json" -Raw) | ConvertFrom-Json
$WindowsTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$WindowsRunner = Get-Content "windows/src/FileMCP.Core/ProcessRunner.cs" -Raw
$WindowsAuthority = Get-Content "windows/src/FileMCP.Core/ExecProcessEnvironmentAuthority.cs" -Raw
$WindowsSettings = Get-Content "windows/src/FileMCP.App/MainWindow.xaml.cs" -Raw
$MacServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$MacRunner = Get-Content "macos/ProcessRunner.swift" -Raw
$MacAuthority = Get-Content "macos/ExecProcessEnvironmentAuthority.swift" -Raw
$MacApp = Get-Content "macos/FileMCPApp.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw
$WindowsTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$Workflow = Get-Content ".github/workflows/verify.yml" -Raw
$MacBuild = Get-Content "build_macos_app.sh" -Raw
$MacDev = Get-Content "run_macos_dev.sh" -Raw
$Readme = Get-Content "README.md" -Raw

if ($CatalogObject.tools.Count -ne 20) { throw "Expected 20 canonical tools, got $($CatalogObject.tools.Count)." }
$Exec = @($CatalogObject.tools | Where-Object { $_.name -eq "exec_process" })
if ($Exec.Count -ne 1) { throw "Expected exactly one exec_process canonical tool." }
if ($Exec[0].risk -ne "high" -or $Exec[0].effect -ne "execute") { throw "exec_process risk/effect contract drift." }
if ($Exec[0].definition.inputSchema.properties.arguments.type -ne "array") { throw "exec_process arguments must remain argv array." }
if ($Exec[0].definition.inputSchema.properties.environment.type -ne "object") { throw "exec_process environment must remain structured object." }

foreach ($Marker in @(
    '"exec_process" => ObjectOutput(await ExecProcessAsync',
    'UseShellExecute = false',
    'startInfo.ArgumentList.Add(argument)',
    'startInfo.Environment.Clear()',
    'effectiveCancellation).ConfigureAwait(false)',
    'class ExecProcessEnvironmentAuthority',
    'MaxForwardedVariables',
    'total argument size exceeds 32768 characters'
)) {
    if (($WindowsTools + $WindowsRunner + $WindowsAuthority).IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows exec_process marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'case "exec_process":',
    'ProcessRunner.run(',
    'final class ExecProcessEnvironmentAuthority',
    'shouldCancel: { executionContext.map { !$0.tryContinue() } ?? false }',
    'posix_spawn',
    'maxForwardedVariables',
    'total argument size exceeds 32768 characters'
)) {
    if (($MacServer + $MacRunner + $MacAuthority).IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS exec_process marker missing: $Marker"
    }
}

$WindowsBudgetMatch = [regex]::Match($WindowsTools, '(?s)BudgetedToolNames\s*=\s*new\([^)]*\)\s*\{(?<body>.*?)\};')
if (-not $WindowsBudgetMatch.Success -or $WindowsBudgetMatch.Groups['body'].Value.IndexOf('"exec_process"', [StringComparison]::Ordinal) -lt 0) {
    throw "Windows exec_process must remain budgeted."
}
$MacBudgetMatch = [regex]::Match($MacServer, '(?s)budgetedToolNames:\s*Set<String>\s*=\s*\[(?<body>.*?)\]')
if (-not $MacBudgetMatch.Success -or $MacBudgetMatch.Groups['body'].Value.IndexOf('"exec_process"', [StringComparison]::Ordinal) -lt 0) {
    throw "macOS exec_process must remain budgeted."
}

foreach ($Text in @($Workflow, $MacBuild, $MacDev, $SwiftTests)) {
    if ($Text.IndexOf("ExecProcessEnvironmentAuthority.swift", [StringComparison]::Ordinal) -lt 0) {
        throw "macOS compile path is missing ExecProcessEnvironmentAuthority.swift."
    }
}

foreach ($Marker in @('ExecEnvironmentAllowListBox','ParseEnvironmentAllowList','ExecEnvironmentAllowList')) {
    if ($WindowsSettings.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows exec environment settings marker missing: $Marker"
    }
}

foreach ($Marker in @('execEnvironmentAllowListField','ConfigKey.execEnvironmentAllowList','execEnvironmentAllowList: execEnvironmentAllowList()')) {
    if ($MacApp.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS exec environment settings marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'windows-exec-process: ok',
    'exec_process preserves argv literally without FileMCP shell interpolation',
    'exec_process forbidden environment override rejected',
    'exec_process cancellation cleans descendant process tree',
    'exec_process budget cancellation terminal state'
)) {
    if ($WindowsTests.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "Windows FMG-005 test marker missing: $Marker"
    }
}

foreach ($Marker in @('structured high-risk execution tool','does **not** insert an implicit shell','high-risk shell compatibility tool')) {
    if ($Readme.IndexOf($Marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "README FMG-005 execution semantics marker missing: $Marker"
    }
}

foreach ($Marker in @(
    'process-tree-cancellation: ok',
    'exec-process-environment-authority: ok',
    'macos-exec-process: ok',
    'EXEC_CANCELLED',
    'exec_process must not be exposed while restricted policy is active'
)) {
    if ($SwiftTests.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        throw "macOS FMG-005 test marker missing: $Marker"
    }
}

Write-Host "exec-process-contract: ok (canonical=20 direct-argv + env-authority + cross-platform settings/wiring)"
