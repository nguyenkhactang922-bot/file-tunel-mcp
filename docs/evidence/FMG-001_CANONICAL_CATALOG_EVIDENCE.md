# FMG-001 Canonical Catalog Authority - Candidate Evidence

Date: 2026-09-24
Task: FMG-001
Branch: chatgpt/FMG-001-canonical-catalog
Status: LOCAL VERIFIED / NATIVE CI PENDING
Authority: ADR-0005, ADR-0006, tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md

## Implemented scope

- Canonical language-neutral catalog at contracts/tool_catalog.v1.json.
- Schema/catalog/instruction/protocol version authority.
- Normalized cross-platform catalog SHA-256.
- Exact instruction hash over the instruction text actually exposed by runtime.
- Risk/effect/capability metadata validation.
- Windows and macOS catalog-backed tool definitions.
- Handler coverage and protocol-contract fail-closed validation.
- Live tools/list catalog metadata exposure.
- Windows embedded catalog resource.
- Windows/macOS release package catalog copy and package hash checks.

## Canonical candidate identity

Normalized catalog SHA-256:
d597f611374045825808d930f2bb0ef7e995515bb816a52ceccb47fd42a8e6aa

Tool count: 19.

## Negative/fail-closed coverage

- missing handler rejected;
- extra runtime tool rejected;
- schema mismatch rejected;
- risk/effect metadata mismatch rejected;
- malformed catalog rejected;
- stale catalog version rejected;
- stale instruction version rejected;
- protocol drift rejected;
- duplicate tool definitions rejected;
- invalid availability metadata rejected;
- CRLF/LF catalog text normalizes to one canonical hash.

FMG-001 does not change active authorization semantics; catalog metadata remains descriptive only.

## Local verification

- python tests/test_tool_catalog_contract.py: PASS, tools=19, hash=d597f611374045825808d930f2bb0ef7e995515bb816a52ceccb47fd42a8e6aa.
- tests/test_tool_surface_parity.ps1: PASS, canonical=19, same hash.
- tests/test_windows_runtime.ps1: PASS, 470 assertions; live legacy/modern tools/list exposes catalog metadata.
- dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror: PASS, 0 warnings, 0 errors.
- Windows release contract: PASS.
- macOS supervisor contract: PASS.
- HTTP connection-bounds contract: PASS.
- dynamic health-discovery contract: PASS.
- Windows ARM64 assurance contract: PASS.
- Windows single-instance contract: PASS.
- production release signing contract: PASS.
- release secret-provisioning contract: PASS.

## Package proof

Normal FileMCP-release staging was locked by an active FileMCP process. The process was not killed because it may be serving the active bridge. Verification used isolated staging FileMCP-fmg001-verify.

- x64 publish/package: PASS.
- ARM64 publish/package: PASS.
- x64 packaged catalog hash: PASS, d597f611374045825808d930f2bb0ef7e995515bb816a52ceccb47fd42a8e6aa.
- x64 app startup: PASS.
- close-to-tray: PASS.
- packaged tunnel-client: PASS.
- single-instance activation: PASS.
- packaged SQLite write/read: PASS.
- packaged OTLP provider: PASS.
- packaged OpenTelemetry notices: PASS.

## Native macOS proof

The local Windows host cannot execute the native Swift/macOS runtime suite. The repository includes ToolCatalog.swift in native macOS build/test wiring and packages the canonical catalog into the app bundle. Authoritative macOS proof must come from GitHub Verify on the exact pushed candidate before FMG-001 is marked DONE.

## Remaining exact gate

Commit exact candidate -> push -> fork-main PR -> native Verify macOS + Windows x64 + Windows ARM64 -> scoped review -> merge -> verify fork main -> mark FMG-001 DONE -> claim FMG-002.
