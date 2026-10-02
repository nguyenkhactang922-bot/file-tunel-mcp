$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -Raw (Join-Path $Root "contracts/tool_catalog.v1.json") | ConvertFrom-Json
$winBackend = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/ExecutionBackend.cs")
$winTools = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/LocalTools.cs")
$winEvidence = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/EvidenceCoordinator.cs")
$winTests = Get-Content -Raw (Join-Path $Root "windows/tests/FileMCP.Core.Tests/Program.cs")
$macBackend = Get-Content -Raw (Join-Path $Root "macos/ExecutionBackend.swift")
$macTools = Get-Content -Raw (Join-Path $Root "macos/LocalMCPServer.swift")
$macEvidence = Get-Content -Raw (Join-Path $Root "macos/EvidenceSupport.swift")
$swiftRuntime = Get-Content -Raw (Join-Path $Root "tests/test_swift_runtime.sh")
$macBuild = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")
$verify = Get-Content -Raw (Join-Path $Root ".github/workflows/verify.yml")

if($catalog.catalogVersion -ne "1.13.0"){ throw "FMG-023 must not change public catalog version" }
if($catalog.tools.Count -ne 46){ throw "FMG-023 must preserve 46 canonical tools, got $($catalog.tools.Count)" }

$exec = $catalog.tools | Where-Object name -eq "exec_process"
if($null -eq $exec){ throw "Canonical catalog missing exec_process" }
$execProperties = @($exec.definition.inputSchema.properties.PSObject.Properties.Name)
if($execProperties -contains "backend_id"){ throw "FMG-023 must not expose caller-controlled backend_id input" }

foreach($marker in @(
  "interface IExecutionBackend",
  "HostExecutionBackend",
  "ExecutionBackendDescriptor",
  "ExecutionBackendHealth",
  "ExecutionBackendCapabilities.Process",
  "ExecutionBackendCapabilities.Pty",
  'WorkspaceMode: "host-contained"',
  'EnvironmentMode: "mediated"',
  "ExecutionBackendContracts.ValidateProcessResult",
  "PersistentPtyService"
)){
  if(-not $winBackend.Contains($marker)){ throw "Windows execution backend missing marker: $marker" }
}

foreach($marker in @(
  "protocol ExecutionBackend",
  "final class HostExecutionBackend",
  "struct ExecutionBackendDescriptor",
  "struct ExecutionBackendHealth",
  "ExecutionBackendCapabilities.process",
  "ExecutionBackendCapabilities.pty",
  'workspaceMode: "host-contained"',
  'environmentMode: "mediated"',
  "ExecutionBackendContracts.validate(result)",
  "PersistentPtyService"
)){
  if(-not $macBackend.Contains($marker)){ throw "macOS execution backend missing marker: $marker" }
}

foreach($marker in @(
  "_executionBackend.RunProcessAsync",
  "RequireExecutionBackend(ExecutionBackendCapabilities.Process)",
  "ExecutionBackendContracts.AttachMetadata",
  "EvidenceBackendId",
  "_executionBackend.StopAllAsync"
)){
  if(-not $winTools.Contains($marker)){ throw "Windows LocalTools routing missing marker: $marker" }
}
if($winTools.Contains("_pty.StartAsync")){
  throw "Windows LocalTools still bypasses FMG-023 execution backend for process/PTY routing"
}

foreach($marker in @(
  "executionBackend.runProcess",
  "requireExecutionBackend(ExecutionBackendCapabilities.process)",
  "ExecutionBackendContracts.attachMetadata",
  "evidenceBackendID",
  "executionBackend.stopAll"
)){
  if(-not $macTools.Contains($marker)){ throw "macOS LocalTools routing missing marker: $marker" }
}
if($macTools.Contains("pty.start(")){
  throw "macOS LocalTools still bypasses FMG-023 execution backend for process/PTY routing"
}

foreach($marker in @(
  "var backendId = _tools.EvidenceBackendId(toolName)",
  "backendId,",
  '["backend_id"] = run.BackendId'
)){
  if(-not $winEvidence.Contains($marker)){ throw "Windows evidence backend binding missing marker: $marker" }
}
foreach($marker in @(
  "let backendID = tools.evidenceBackendID(toolName: toolName)",
  "backendID: backendID",
  '"backend_id": run.backendID'
)){
  if(-not $macEvidence.Contains($marker)){ throw "macOS evidence backend binding missing marker: $marker" }
}

if($winBackend.Contains("GitTools") -or $winBackend.Contains("GitCli")){ throw "Execution backend must not absorb Git tools" }
if($macBackend.Contains("gitStatus") -or $macBackend.Contains("gitCommit") -or $macBackend.Contains("gitPush")){ throw "Execution backend must not absorb Git tools" }

foreach($text in @($swiftRuntime,$macBuild,$verify)){
  if(-not $text.Contains("macos/ExecutionBackend.swift") -and -not $text.Contains('$ROOT/macos/ExecutionBackend.swift')){
    throw "macOS ExecutionBackend source missing from native compile/typecheck list"
  }
}

foreach($marker in @(
  "windows-execution-backend: ok",
  "FMG-023 backend descriptor remains extensible for FMG-024 isolated workspace/network/resource modes",
  "FMG-023 routes exec_process through selected execution backend",
  "FMG-023 rejects unavailable backend before process dispatch",
  "FMG-023 rejects backend capability mismatch before process dispatch",
  "FMG-023 lifecycle degradation fails closed",
  "FMG-023 rejects backend result normalization mismatch",
  "FMG-023 rejects model-supplied backend identity spoof input"
)){
  if(-not $winTests.Contains($marker)){ throw "Windows FMG-023 acceptance missing marker: $marker" }
}

foreach($marker in @(
  "swift-execution-backend: ok",
  "FMG-023 unavailable backend",
  "FMG-023 capability mismatch",
  "FMG-023 lifecycle failure",
  "FMG-023 result normalization",
  "FMG-023 model backend identity spoof input"
)){
  if(-not $swiftRuntime.Contains($marker)){ throw "Swift FMG-023 acceptance missing marker: $marker" }
}

Write-Output "execution-backend-contract: PASS"
Write-Output "catalog: 1.13.0 / 46 tools (unchanged)"
Write-Output "default-backend: host-native"
Write-Output "scope: process + PTY only"
Write-Output "file-git-routing: host-native outside backend interface"
Write-Output "backend-identity-source: server-owned"
