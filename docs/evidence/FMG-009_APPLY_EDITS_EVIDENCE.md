# FMG-009 Atomic Versioned apply_edits Evidence

Status: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING

Branch: `chatgpt/FMG-009-apply-edits`
Baseline main: `8a58a223814505518e581ebe79856846555cb4b4`
Depends: FMG-004 and FMG-008 DONE / MAIN VERIFIED.

## Implemented scope

- Added canonical MCP tool `apply_edits`; canonical catalog is now version `1.3.0` with 21 tools.
- `apply_edits` requires `expected_version` for an existing UTF-8 text target.
- Coordinate systems: `byte` (0-based, end-exclusive, UTF-8 boundary checked) and `lineColumn` (1-based line/column, Unicode scalar columns, `column_encoding=utf8CodePoint`, end-exclusive).
- Adjacent edits are allowed; overlapping non-empty ranges are rejected; same-offset insertions preserve request order.
- UTF-8 BOM and detected line ending are preserved by default; replacement newlines normalize to source newline when requested.
- Dry-run performs full validation and returns bounded preview without creating a committed target change.
- Mutation flow: versioned read -> compile/validate -> sibling temp staging -> flush/sync -> final policy reauthorization -> Mutation Guard -> expected-version recheck -> cancellation recheck -> atomic publish.
- Windows uses `File.Move(temp, target, true)`; macOS uses `replaceItemAt(target, withItemAt: temp)` after synchronized sibling staging.
- Cancellation before commit leaves original unchanged. Cancellation observed after atomic publish is reported as `committed=true` rather than a false rollback/failure state.
- ToolBudget integration bounds source bytes/replacement work; 5 MB canonical write limit remains enforced.
- Model-specific search/replace or unified-diff formats are not added here; they remain adapters above this canonical primitive per frozen architecture.

## Adversarial / failure coverage

Windows native suite covers:
- byte edits;
- lineColumn Unicode scalar edits;
- BOM + CRLF preservation;
- stable same-offset insertion ordering;
- dry-run content/mtime preservation;
- overlap rejection;
- UTF-8 interior-byte rejection;
- stale expected version;
- caller-lowered budget exhaustion;
- injected staging failure;
- external writer between staging and commit;
- target replacement/path swap;
- cancellation immediately before commit;
- cancellation immediately after commit reports committed result;
- publish failure leaves original intact.

macOS native Swift harness contains equivalent acceptance/adversarial assertions and is wired into GitHub Verify. This Windows host has no native `swiftc`, so macOS is NATIVE CI PENDING rather than locally PASS.

## Local evidence

- `python tests/test_tool_catalog_contract.py`: PASS, tools=21, catalog SHA-256 `a6d3914363267b165af5896b0b6456a71155faaafd4911a957818e1a1fd26b91`;
- `tests/test_tool_surface_parity.ps1`: PASS, canonical=21 with the same hash;
- `tests/test_apply_edits_contract.ps1`: PASS;
- FMG-005/FMG-006/FMG-007/FMG-008 regression contracts: PASS under catalog 1.3.0 / 21 tools;
- `tests/test_windows_runtime.ps1`: PASS, 682 assertions including `windows-apply-edits: ok`;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors;
- `tests/test_project_state_contract.ps1`: PASS before state transition;
- Git-for-Windows Bash syntax for `tests/test_swift_runtime.sh`: PASS;
- `git diff --check`: PASS.

## Remaining gate

Commit/push exact candidate -> native GitHub Verify on macOS + Windows x64 + Windows ARM64 -> fix only exact failing stage if any -> scoped security/atomicity review -> PR exact green head -> merge -> merged-main local + native verification -> mark FMG-009 DONE / MAIN VERIFIED -> only then claim FMG-010.
