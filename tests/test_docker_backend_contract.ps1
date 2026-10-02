$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -Raw (Join-Path $Root "contracts/tool_catalog.v1.json") | ConvertFrom-Json
$winDocker = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/DockerExecutionBackend.cs")
$winEnv = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/ExecProcessEnvironmentAuthority.cs")
$winTools = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/LocalTools.cs")
$winPolicy = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/ServerPolicy.cs")
$winEvidence = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/EvidenceCoordinator.cs")
$winTests = Get-Content -Raw (Join-Path $Root "windows/tests/FileMCP.Core.Tests/Program.cs")
$macDocker = Get-Content -Raw (Join-Path $Root "macos/DockerExecutionBackend.swift")
$macEnv = Get-Content -Raw (Join-Path $Root "macos/ExecProcessEnvironmentAuthority.swift")
$macTools = Get-Content -Raw (Join-Path $Root "macos/LocalMCPServer.swift")
$macPolicy = Get-Content -Raw (Join-Path $Root "macos/ServerPolicy.swift")
$macEvidence = Get-Content -Raw (Join-Path $Root "macos/EvidenceSupport.swift")
$swiftRuntime = Get-Content -Raw (Join-Path $Root "tests/test_swift_runtime.sh")
$macBuild = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")
$verify = Get-Content -Raw (Join-Path $Root ".github/workflows/verify.yml")

if($catalog.catalogVersion -ne "1.13.0"){ throw "FMG-024 must not change public catalog version" }
if($catalog.tools.Count -ne 46){ throw "FMG-024 must preserve 46 canonical tools" }
foreach($name in @("exec_process","pty_start")){
  $tool = $catalog.tools | Where-Object name -eq $name
  if($null -eq $tool){ throw "Canonical catalog missing $name" }
  $props = @($tool.definition.inputSchema.properties.PSObject.Properties.Name)
  foreach($forbidden in @("backend_id","docker_image","docker_host","mount","network_mode")){
    if($props -contains $forbidden){ throw "FMG-024 must not expose caller-controlled $forbidden on $name" }
  }
}

foreach($marker in @(
  'class DockerExecutionBackend',
  'DockerExecutionBackendConfiguration',
  'DigestPinnedImagePattern',
  '"--pull", "never"',
  '"--no-healthcheck"',
  '"--read-only"',
  '"--cap-drop", "ALL"',
  '"--security-opt", "no-new-privileges"',
  '"--pids-limit"',
  '"--cpus"',
  '"--memory"',
  '"--network"',
  '"none"',
  '"--user"',
  '"--mount"',
  'ResolvePinnedImageAsync',
  'VerifyContainerSecurityAsync',
  'CleanupOwnedOrphansLockedAsync',
  'EvidenceIdentity',
  '"image_digest"',
  '"network_policy"',
  '"resource_policy"',
  '"DOCKER_HOST"',
  '"DOCKER_CONTEXT"',
  '"DOCKER_CONFIG"',
  'blockedOverrideNames: DockerControlEnvironmentNames'
)){
  if(-not $winDocker.Contains($marker)){ throw "Windows FMG-024 missing marker: $marker" }
}
if($winDocker.Contains("docker.sock") -and -not $winTests.Contains("docker.sock")){
  throw "Windows Docker backend source must not embed a Docker socket mount"
}
if(-not $winEnv.Contains("blockedOverrideNames")){ throw "Windows Docker client override authority missing" }
if(-not $winPolicy.Contains("AllowsOpenWorldExecutionBackend")){ throw "Windows explicit Docker network policy capability missing" }
if(-not $winTools.Contains("DockerExecutionBackend")){ throw "Windows Docker backend is not server-selected by LocalTools" }
if(-not $winEvidence.Contains('"backend_metadata"')){ throw "Windows durable evidence does not surface backend metadata" }

foreach($marker in @(
  'final class DockerExecutionBackend',
  'struct DockerExecutionBackendConfiguration',
  '"--pull", "never"',
  '"--no-healthcheck"',
  '"--read-only"',
  '"--cap-drop", "ALL"',
  '"--security-opt", "no-new-privileges"',
  '"--pids-limit"',
  '"--cpus"',
  '"--memory"',
  '"--network"',
  '"none"',
  '"--user"',
  '"--mount"',
  'resolvePinnedImage',
  'verifyContainerSecurity',
  'cleanupOwnedOrphans',
  'evidenceIdentity',
  '"image_digest"',
  '"network_policy"',
  '"resource_policy"',
  '"DOCKER_HOST"',
  '"DOCKER_CONTEXT"',
  '"DOCKER_CONFIG"',
  'blockedOverrideNames: Self.dockerControlEnvironmentNames'
)){
  if(-not $macDocker.Contains($marker)){ throw "macOS FMG-024 missing marker: $marker" }
}
if(-not $macEnv.Contains("blockedOverrideNames")){ throw "macOS Docker client override authority missing" }
if(-not $macPolicy.Contains("allowsOpenWorldExecutionBackend")){ throw "macOS explicit Docker network policy capability missing" }
if(-not $macTools.Contains("DockerExecutionBackend")){ throw "macOS Docker backend is not server-selected by LocalTools" }
if(-not $macEvidence.Contains('"backend_metadata"')){ throw "macOS durable evidence does not surface backend metadata" }

foreach($text in @($swiftRuntime,$macBuild,$verify)){
  if(-not $text.Contains("DockerExecutionBackend.swift")){
    throw "macOS DockerExecutionBackend source missing from native compile/typecheck list"
  }
}

foreach($marker in @(
  "swift-docker-backend: ok",
  "FMG-024 Swift unpinned image",
  "FMG-024 Swift Docker create must carry mandatory isolation/resource controls",
  "FMG-024 Swift Docker create must expose one workspace bind and no Docker socket",
  "FMG-024 Swift daemon-control override",
  "FMG-024 Swift network policy",
  "FMG-024 Swift daemon unavailable"
)){
  if(-not $swiftRuntime.Contains($marker)){ throw "macOS FMG-024 acceptance missing marker: $marker" }
}

foreach($marker in @(
  "windows-docker-backend: ok",
  "FMG-024 rejects unpinned Docker image configuration",
  "FMG-024 rejects selected image outside local digest-pinned allowlist",
  "FMG-024 rejects root container identity",
  "FMG-024 create command carries mandatory isolation/resource controls",
  "FMG-024 create command exposes only one workspace bind and never mounts Docker socket",
  "FMG-024 network-enabled backend requires separate explicit local policy capability",
  "FMG-024 daemon-unreachable backend fails operation without breaking FileMCP construction",
  "FMG-024 changed/unmatched local image digest fails closed before create",
  "FMG-024 orphan cleanup never deletes foreign container with mismatched ownership labels",
  "FMG-024 rejects Docker daemon-control environment overrides before container side effects"
)){
  if(-not $winTests.Contains($marker)){ throw "Windows FMG-024 acceptance missing marker: $marker" }
}

Write-Output "docker-backend-contract: PASS"
Write-Output "catalog: 1.13.0 / 46 tools (unchanged)"
Write-Output "selection: local/server-owned only"
Write-Output "network-default: none"
Write-Output "image-policy: digest-pinned local allowlist"
Write-Output "docker-daemon-authority: local environment only; request overrides blocked"
