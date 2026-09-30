$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $Root "contracts/tool_catalog.v1.json"
$catalog = Get-Content -Raw $catalogPath | ConvertFrom-Json
$winTools = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/LocalTools.cs")
$winPty = Get-Content -Raw (Join-Path $Root "windows/src/FileMCP.Core/PersistentPtyService.cs")
$macTools = Get-Content -Raw (Join-Path $Root "macos/LocalMCPServer.swift")
$macPty = Get-Content -Raw (Join-Path $Root "macos/PersistentPty.swift")
$swiftRuntime = Get-Content -Raw (Join-Path $Root "tests/test_swift_runtime.sh")
$macBuild = Get-Content -Raw (Join-Path $Root "build_macos_app.sh")
$verify = Get-Content -Raw (Join-Path $Root ".github/workflows/verify.yml")

if($catalog.catalogVersion -ne "1.11.0"){ throw "FMG-020 requires catalog 1.11.0" }
if($catalog.tools.Count -ne 41){ throw "FMG-020 requires 41 canonical tools, got $($catalog.tools.Count)" }

$ptyTools = @("pty_start","pty_read","pty_write","pty_resize","pty_signal","pty_stop","pty_list")
foreach($name in $ptyTools){
  if(-not ($catalog.tools.name -contains $name)){ throw "Catalog missing $name" }
  if(-not $winTools.Contains('"' + $name + '"')){ throw "Windows LocalTools missing $name" }
  if(-not $macTools.Contains('"' + $name + '"')){ throw "macOS LocalTools missing $name" }
}

foreach($marker in @(
  "CreatePseudoConsole",
  "ProcThreadAttributePseudoConsole",
  "StartfUseStdHandles",
  "JobObjectLimitKillOnJobClose",
  "ArtifactContentClasses.PtyOutput",
  "restart_resume_supported",
  "cursor_evicted",
  "idle_expired",
  "lifetime_expired"
)){
  if(-not $winPty.Contains($marker)){ throw "Windows PTY implementation missing marker: $marker" }
}

foreach($marker in @(
  "openpty",
  "posix_spawn",
  "TIOCSWINSZ",
  "killpg",
  "macos-posix-openpty-spawn",
  "ArtifactContentClasses.ptyOutput",
  "restart_resume_supported",
  "cursor_evicted",
  "idle_expired",
  "lifetime_expired",
  "process-group ownership is no longer proven",
  "ring.startIndex"
)){
  if(-not $macPty.Contains($marker)){ throw "macOS PTY implementation missing marker: $marker" }
}

if($winPty -match 'Evidence(Store|Coordinator)|Telemetry|recordActivity'){ throw "Windows PTY code must not emit PTY bytes into evidence/telemetry" }
if($macPty -match 'Evidence(Store|Coordinator)|Telemetry|recordActivity|\blog\('){ throw "macOS PTY code must not emit PTY bytes into evidence/telemetry" }

foreach($text in @($swiftRuntime,$macBuild,$verify)){
  if(-not $text.Contains("macos/PersistentPty.swift") -and -not $text.Contains('$ROOT/macos/PersistentPty.swift')){
    throw "macOS PTY source missing from native compile list"
  }
}

foreach($marker in @(
  "swift-persistent-pty: ok",
  "FMG020_TTY:",
  "PTY descendant process-tree cleanup",
  "cursor_evicted",
  "idle_expired",
  "lifetime_expired"
)){
  if(-not $swiftRuntime.Contains($marker)){ throw "Swift native PTY acceptance missing marker: $marker" }
}

Write-Output "persistent-pty-contract: PASS"
Write-Output "catalog: 1.11.0 / 41 tools"
Write-Output "windows-backend: ConPTY"
Write-Output "macos-backend: POSIX openpty + posix_spawn"
Write-Output "restart-resume: false"
Write-Output "raw-pty-evidence-telemetry: absent"
