# FMG-002 Structured Result Envelope - Candidate Evidence

Date: 2026-09-24
Task: FMG-002
Branch: `chatgpt/FMG-002-structured-result-envelope`
Status: MAIN VERIFIED
Depends: FMG-001 DONE / MAIN VERIFIED
Authority: ADR-0005, ADR-0006, tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md

## Implemented scope

- Added a versioned namespaced result envelope at `_meta["io.filemcp/result"]` to successful and tool-level error `tools/call` results on Windows and macOS.
- Preserved existing `content`, `structuredContent`, and `isError` fields for backward compatibility.
- Envelope fields are identical by contract across native runtimes:
  - `schemaVersion`: `1.0.0`;
  - `status`: `success`, `partial`, or `tool_error`;
  - `operationId`: `op_` plus 32 lowercase hexadecimal characters;
  - `truncation.truncated`: boolean plus `truncation.reason`;
  - `usage.contentItems`: non-negative integer;
  - `warnings`: string array.
- `partial` is selected when existing structured output reports `truncated=true`; truncation reason is normalized to `server_limit` for that current case.
- Protocol/transport JSON-RPC errors remain JSON-RPC errors and are not disguised as tool-level result envelopes.
- Modern MCP completion metadata remains additive to the same tool result.

## Fail-closed / negative coverage

Windows unit coverage rejects:
- unknown result-envelope schema version;
- unknown status;
- missing/malformed operation ID;
- invalid negative usage count.

Runtime regression coverage verifies:
- existing legacy content remains unchanged semantically;
- structured content remains unchanged semantically;
- correlation/telemetry wrappers do not change tool payload semantics;
- operation IDs may differ between calls without breaking compatibility assertions.

macOS native test wiring asserts on live tools/call:
- schema version;
- success status;
- error status;
- truncation boolean;
- usage content count;
- operation ID shape.

## Local verification

- `tests/test_windows_runtime.ps1`: PASS, 509 assertions.
- `tests/test_tool_surface_parity.ps1`: PASS, canonical tools=19, catalog hash unchanged.
- `python tests/test_tool_catalog_contract.py`: PASS.
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors.
- `git diff --check`: PASS.

## Cross-platform gate

The local host is Windows and cannot execute the native Swift/macOS runtime suite. Exact pushed candidate must pass GitHub Verify on macOS, Windows x64 and Windows ARM64 before FMG-002 may be marked DONE / MAIN VERIFIED.

## Remaining gate

Commit exact candidate -> push -> PR to fork main -> exact-head native Verify -> review -> merge -> merged-main Verify -> mark FMG-002 DONE / MAIN VERIFIED -> dependency-unblock FMG-003 and FMG-004 according to the frozen graph.
## Final MAIN VERIFIED closure

- Primary implementation PR #4 merged as `0314137c2e0bf7e47e257c9e1d9909adb4d9d8d7`.
- Swift hardening PR #5 merged as final FMG-002 main commit `dcbc55f7685e91c804ab14500df752a0c6f3be62`.
- Exact final main Verify run `35994263967`: SUCCESS.
- Native macOS, Windows x64, Windows ARM64: PASS.
- Post-merge Windows runtime: 509 assertions PASS.
- Post-merge Release build: 0 warnings / 0 errors.

FMG-002 is DONE / MAIN VERIFIED.
