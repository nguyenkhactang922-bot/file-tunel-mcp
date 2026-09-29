# FMG-017 Model-Friendly Edit Adapters Evidence

Status: LOCAL VERIFIED / MAIN SYNC + NATIVE CI PENDING

Branch: `chatgpt/FMG-017-model-friendly-edit-adapters`

## Canonical surface

- catalog version: `1.9.0`
- canonical tools: 31
- catalog SHA-256: `7b053baec3ddd1ce8789e651bdd0e9f6d1354387c03f2ddf8a1a05763d32d4d8`
- new tools:
  - `apply_search_replace`
  - `apply_unified_diff`

Both tools are high-risk filesystem.write adapters. They never write directly. They compile to canonical byte edits and execute only through existing `apply_edits`.

## Safety / semantic invariants

PASS:
- exact search/replace requires exactly one match; zero and multiple matches fail closed;
- unified diff accepts exactly one file and rejects path-header escape/mismatch;
- malformed hunk/header/count/context fails closed;
- overlapping hunks fail closed;
- expected_version is read and preserved through canonical apply_edits;
- adapter compilation and canonical application honor ToolExecutionContext cancellation/budget;
- BOM and line-ending behavior is inherited from canonical apply_edits;
- dry-run preview exactly matches the equivalent canonical apply_edits preview;
- adapter services contain no direct file mutation primitives.

## Windows local verification

PASS:
- `tests/test_edit_adapters_contract.ps1`;
- canonical catalog contract: PASS;
- cross-platform tool-surface parity: PASS;
- dependent apply_edits/version/Mutation Guard/batch/quarantine/project/evidence/exec contracts: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- FMG-017 isolation: `windows-edit-adapters-only-tests: ok (16 assertions)`;
- full Windows regression: `windows-core-tests: ok (834 assertions)`;
- `git diff --check`: PASS.

## macOS implementation / verification state

Implemented and wired:
- `macos/EditAdapterService.swift`;
- `macos/LocalMCPServer.swift` adapter handlers delegate to canonical `applyEdits`;
- app build, static Verify and both native Swift runtime compile lists include `EditAdapterService.swift`;
- native Swift runtime assertions cover search/replace preview+commit, unified diff preview+commit, zero/multiple match, stale version, cancellation, malformed diff, path escape, overlap, BOM and CRLF inheritance.

The local Windows host does not have a usable macOS Swift toolchain / bash environment. Native Swift typecheck/runtime proof is therefore pending GitHub macOS Verify, not locally claimed.

## Remaining gate

1. commit the local-verified candidate;
2. synchronize latest verified `fork/main`;
3. rerun only affected local contracts/build/full Windows regression after sync;
4. push exact synchronized head;
5. require native Verify on macOS + Windows x64 + native Windows ARM64;
6. scoped review;
7. PR/merge;
8. merged-main Verify;
9. mark FMG-017 DONE / MAIN VERIFIED and claim FMG-018.


## Exact-head native verification and scoped review

Candidate head: `5abe84a2c4b455b645307e70bacec86bdc1b5e9f`.

Native Verify history:
- run `36517765343` on `326796114fbe9fe5f7924f2e71fe32b22405feca`: Windows ARM64 passed and Windows x64 progressed through FMG-017, while macOS Integration tests failed only because the new Swift runtime assertion called `hasTool` without its required `named:` label;
- remediation commit `5abe84a2c4b455b645307e70bacec86bdc1b5e9f`: test-only one-line label fix; product code and catalog semantics unchanged;
- run `36518117949` on exact head `5abe84a2c4b455b645307e70bacec86bdc1b5e9f`: SUCCESS on macOS, Windows x64 and native Windows ARM64.

Scoped review: PASS.
- both adapters remain compile-only services with no direct filesystem mutation primitives;
- source is read through strong `expected_version` authority before compilation;
- compiled edits are executed only through canonical `apply_edits`, preserving commit-time policy reauthorization, Mutation Guard, expected-version recheck, atomic staging/publish, BOM and newline behavior;
- `apply_search_replace` requires exactly one exact UTF-8 match; zero/multiple matches fail closed;
- `apply_unified_diff` accepts one file only, validates both path headers against `relative_path`, rejects absolute/parent escapes, malformed headers/body/counts/context and overlapping hunks;
- cancellation and ToolBudget checks occur during adapter compilation and again on canonical application;
- dry-run preview parity is covered against equivalent canonical `apply_edits` on Windows and native Swift runtime;
- catalog remains 1.9.0 / 31 canonical tools / SHA-256 `7b053baec3ddd1ce8789e651bdd0e9f6d1354387c03f2ddf8a1a05763d32d4d8`.

NEXT_EXACT_ACTION: commit/push this evidence-only closure head, require exact-head native Verify on macOS + Windows x64 + native Windows ARM64, then create/reuse one PR, merge only the verified head, require merged-main Verify, mark FMG-017 DONE / MAIN VERIFIED, and claim FMG-018.
