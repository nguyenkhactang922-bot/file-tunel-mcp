# FMUX-011 Repository Intelligence UX Evidence

Date: 2026-10-03
Task: FMUX-011 — Repository Intelligence
Branch: `chatgpt/FMUX-011-repository-intelligence`
Verified base: `fork/main = 5a5abed27e523dac4f62c27e8808c3bb03a6d874`
State: ACTIVE / EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-STATE CLOSURE PENDING.

## Frozen scope

- Repository summary.
- Observed `repo_map`, `symbol_search`, and `related_files` results.
- Provider ID/version and completeness shown prominently.
- Metadata-only bounded UI; no raw source bytes, authenticated cursors, or opaque ContentRef tokens copied into presentation telemetry.
- Repository intelligence remains read-only and never grants authority or claims exhaustive symbol/source truth.

## Implementation

Windows and macOS now emit a sanitized `[RepositoryIntelligenceResult]` presentation projection only after successful canonical repository-intelligence tool execution. The projection copies provider/completeness/source-state and bounded item metadata only; the native app shells observe that marker and render a Repository page with result history and item metadata.

Windows surface:
- `NavRepositoryButton` / `RepositoryTab`.
- `RepositoryResultGrid` and `RepositoryItemGrid`.
- provider/completeness, observed result summary, and source-state labels.
- max 100 captured results; server projection max 200 entries per observed result.

macOS surface:
- Repository sidebar destination / hidden-tab page.
- result table and item table.
- provider/completeness, observed result summary, and source-state labels.
- max 100 captured results; server projection max 200 entries per observed result.

## Security / truth review

`tests/test_fmux_repository_intelligence_contract.ps1` verifies both native surfaces and projection boundaries. It explicitly rejects projection code that copies `content_ref`, raw `content`, or `next_cursor`. UI copy states that provider completeness is descriptive/heuristic, observed state is read-only, and repository intelligence grants no authority.

Existing app-shell guard was updated only to stop classifying already-implemented Repository and Evidence destinations as future/unimplemented. Terminal and Recovery remain guarded from premature exposure.

## Local evidence

PASS:
- `tests/test_fmux_repository_intelligence_contract.ps1`.
- `tests/test_repository_intelligence_query_contract.ps1` — catalog 1.13.0 / 46 tools / read-only query facade.
- `tests/test_fmux_app_shell_contract.ps1`.
- `tests/test_project_state_contract.ps1` — current branch matches and one authoritative next action.
- `dotnet build windows/FileMCP.Windows.sln -c Release --no-restore -warnaserror` — 0 warnings / 0 errors.
- `git diff --check`.
- Windows vendored tunnel-client local-auth stage reached PASS during local integration attempt.

Environment-limited, not a source failure:
- `tests/test_windows_runtime.ps1` cannot complete clean restore under FileMCP's intentionally minimal mediated local process environment. After restoring `OS=Windows_NT` inside the child shell, tunnel local-auth passed, then NuGet restore failed with the already-known `Value cannot be null. (Parameter 'path1')` minimal-environment issue. The no-restore Release build is clean; GitHub native Windows Verify is the clean-restore/integration authority.
- macOS compiler/runtime is not available on this Windows host. GitHub `macos-26` Verify is the native `swiftc -warnings-as-errors`, integration, app-build, and bundled-resource authority.

## Exact-head native verification / scoped review

- Exact candidate: `8c84912c5280fb599ad91632f5458d8b7a42f2a0`.
- Push Verify: `37138794626` — SUCCESS on macOS / Windows x64 / native Windows ARM64.
- macOS: static/typecheck, catalog, native integration, app build and bundled-resource verification PASS.
- Windows x64: Release build, FMUX-011 contract, full integration, x64/ARM64 package build, app smoke, resources and upload PASS.
- Windows ARM64: FMUX-011 contract, native build, app smoke, resources and package upload PASS.
- Scoped diff review against `fork/main=5a5abed27e523dac4f62c27e8808c3bb03a6d874`: PASS; no P0/P1 remains. Repository Intelligence presentation remains bounded, metadata-only, read-only and non-authoritative; raw source, raw ContentRef tokens and cursors are not projected.

## Remaining remote gates before DONE

1. Commit/push this evidence-state-only closure head.
2. Require exact-head Verify on the closure SHA because the commit identity changes.
3. Create/review exactly one PR targeting `main` after that closure head is green.
4. Merge the exact reviewed head with head guard.
5. Verify the exact resulting `main` commit on all required native lanes.
6. Only then mark FMUX-011 DONE / MAIN VERIFIED and re-evaluate the FMUX dependency graph.
