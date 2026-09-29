$ErrorActionPreference = "Stop"

function Require-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) { throw $Message }
}

$Catalog = Get-Content "contracts/tool_catalog.v1.json" -Raw | ConvertFrom-Json
if ($Catalog.catalogVersion -ne "1.10.0") { throw "FMG-016 requires catalog version 1.10.0" }
if ($Catalog.tools.Count -ne 34) { throw "FMG-016 requires exactly 34 canonical tools; got $($Catalog.tools.Count)" }

$Expected = @{
    quarantine_delete  = @("high", "delete")
    quarantine_list    = @("low", "metadata")
    quarantine_get     = @("low", "metadata")
    quarantine_restore = @("high", "write")
}
foreach ($Name in $Expected.Keys) {
    $Tool = @($Catalog.tools | Where-Object name -eq $Name)
    if ($Tool.Count -ne 1) { throw "Missing/duplicate canonical tool: $Name" }
    if ($Tool[0].handler -ne "local_tools") { throw "$Name must use local_tools handler" }
    if ($Tool[0].risk -ne $Expected[$Name][0] -or $Tool[0].effect -ne $Expected[$Name][1]) {
        throw "$Name policy classification changed unexpectedly"
    }
    if ($Tool[0].definition.inputSchema.additionalProperties -ne $false) {
        throw "$Name input schema must fail closed on unknown arguments"
    }
}

$Delete = $Catalog.tools | Where-Object name -eq "quarantine_delete"
$Get = $Catalog.tools | Where-Object name -eq "quarantine_get"
$Restore = $Catalog.tools | Where-Object name -eq "quarantine_restore"
if (@($Delete.definition.inputSchema.required) -notcontains "relative_path") { throw "quarantine_delete must require relative_path" }
if (@($Get.definition.inputSchema.required) -notcontains "quarantine_ref") { throw "quarantine_get must require quarantine_ref" }
if (@($Restore.definition.inputSchema.required) -notcontains "quarantine_ref") { throw "quarantine_restore must require quarantine_ref" }

$Win = Get-Content "windows/src/FileMCP.Core/QuarantineService.cs" -Raw
$WinTools = Get-Content "windows/src/FileMCP.Core/LocalTools.cs" -Raw
$WinTests = Get-Content "windows/tests/FileMCP.Core.Tests/Program.cs" -Raw
$Mac = Get-Content "macos/QuarantineService.swift" -Raw
$MacServer = Get-Content "macos/LocalMCPServer.swift" -Raw
$SwiftTests = Get-Content "tests/test_swift_runtime.sh" -Raw

foreach ($Needle in @(
    "ArtifactContentClasses.Quarantine",
    "ArtifactContentClasses.Checkpoint",
    "after_package_verified",
    "_mutationGuard.Verify",
    "VerifyPackageAsync",
    "createdRootGuard",
    "before_tree_rollback",
    "partial_recovery_required",
    "expected_version is required",
    "QuarantineRef expired",
    "deleteCommitStarted"
)) { Require-Contains $Win $Needle "Windows FMG-016 invariant missing: $Needle" }

foreach ($Needle in @(
    "ArtifactContentClass.quarantine",
    "ArtifactContentClass.checkpoint",
    "after_package_verified",
    "mutationGuard.verify",
    "verifyPackage",
    "createdRootGuard",
    "before_tree_rollback",
    "partial_recovery_required",
    "expected_version is required",
    "QuarantineRef expired",
    "deleteCommitStarted"
)) { Require-Contains $Mac $Needle "macOS FMG-016 invariant missing: $Needle" }

foreach ($Name in @("quarantine_delete", "quarantine_list", "quarantine_get", "quarantine_restore")) {
    Require-Contains $WinTools ('"' + $Name + '"') "Windows LocalTools missing $Name"
    Require-Contains $MacServer ('"' + $Name + '"') "macOS LocalMCPServer missing $Name"
}

foreach ($Needle in @(
    "windows-quarantine-restore: ok",
    "quarantine_delete rejects stale source version",
    "quarantine_delete rejects path swap after package verification",
    "expired quarantine ref cannot restore",
    "restore rejects destination appearing after plan",
    "tree partial restore failure rolls back destination completely",
    "rollback failure retains recovery artifact and returns partial_recovery_required",
    "artifact quota exhaustion aborts quarantine delete",
    "metadata persistence disk-full aborts quarantine delete"
)) { Require-Contains $WinTests $Needle "Windows FMG-016 test missing: $Needle" }

foreach ($Needle in @(
    "swift-quarantine-restore: ok",
    "stale source",
    "path swap",
    "expired restore",
    "destination race",
    "tree restore failure did not rollback",
    "rollback failure did not retain recovery artifact",
    "artifact quota",
    "metadata disk full",
    "empty tree quarantine restore failed",
    "macos/QuarantineService.swift"
)) { Require-Contains $SwiftTests $Needle "macOS FMG-016 test/wiring missing: $Needle" }

foreach ($Path in @("build_macos_app.sh", ".github/workflows/verify.yml")) {
    $Text = Get-Content $Path -Raw
    Require-Contains $Text "macos/QuarantineService.swift" "$Path does not compile QuarantineService.swift"
}

Write-Host "quarantine-restore-contract: ok (catalog=1.10.0 tools=34)"
