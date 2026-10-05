# FMUX-020 Product UI/UX Main Verification Evidence

Date: 2026-10-05
Task: FMUX-020 Product UI/UX Main Verification
Branch: `chatgpt/FMUX-020-product-ui-ux-main-verification`
Claim base: exact verified main `11d40cf277a490a360cb3f9ee61b690a292dfb7b`
Dependency: FMUX-019 governance DONE / MAIN VERIFIED; FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED.

## Lifecycle truth

This file is candidate/local verification evidence. **LOCAL VERIFIED is not MAIN VERIFIED.**
`PRODUCT_UI_UX_MAIN_VERIFIED` may be recorded only after the exact reviewed FMUX-020 candidate is merged to `main` and the required merged-main native Verify succeeds on macOS, Windows x64, and native Windows ARM64.

## LIVE CORE-TO-UI PROOF

The durable FileMCP runtime was not restarted.

- PID `14804`
- process: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`
- start time: 2026-10-05 09:32:15 local
- window title: `FileMCP`
- responding: true
- live UI Automation root: `FileMCP`, class `Window`, enabled
- live shell state observed: `Healthy`
- live workspace state observed through the UI: C Disabled, D Running, E Running, F Disabled
- read-only navigation proof: Home -> Workspaces; no runtime mutation/restart was performed

Durable live screenshots:

- `docs/evidence/artifacts/FMUX-020/live-runtime-home.png` (1936x1056)
- `docs/evidence/artifacts/FMUX-020/live-runtime-workspaces.png` (1936x1056)

The live process remained PID `14804` after capture.

## CURRENT-BUILD SCREENSHOT PROOF

The current FMUX candidate UI was rendered in an isolated WPF proof harness under ignored `build/fmux020-ui-proof/`.
The harness references the current `FileMCP.App` project, loads the real design resources and `MainWindow`, uses a separate proof observability database, does not invoke `App.OnStartup`, does not acquire the desktop single-instance coordinator, and does not start a second production runtime/server.

Render result: `FMUX020_UI_RENDER_PASS`; **14/14** product pages rendered at 1280x900:

1. Setup
2. Home
3. Workspaces
4. Connections
5. Settings
6. Activity
7. Changes
8. Evidence
9. Repository
10. Terminal
11. Recovery
12. Artifacts
13. Backend
14. Diagnostics

Artifacts live under `docs/evidence/artifacts/FMUX-020/current-ui/` as `setup.png`, `home.png`, `workspaces.png`, `connections.png`, `settings.png`, `activity.png`, `changes.png`, `evidence.png`, `repository.png`, `terminal.png`, `recovery.png`, `artifacts.png`, `backend.png`, `diagnostics.png`, plus `render-report.txt`.

The durable runtime PID `14804` remained alive and responding after the isolated render proof.

## Product contract continuity

The new FMUX-020 aggregate gate reuses the already-frozen product contracts instead of replaying implementation tasks. The RED baseline proved all existing FMUX contracts green, including:

- FMUX cross-platform adversarial gate and its 11 foundation contracts;
- Repository Intelligence presentation;
- Terminal / PTY presentation;
- Recovery presentation;
- Backend / Isolation presentation;
- Onboarding;
- Accessibility / Keyboard / Theme;
- Performance / Visual Consistency.

The test-first FMUX-020 RED gate failed only the two expected final-gate gaps:

1. this FMUX-020 candidate evidence file did not yet exist;
2. the FMUX-020 final gate was not yet wired into the two Windows native Verify jobs.

No product/core/runtime regression was observed in the RED run.

## Native build/package/core regression contract

The Verify workflow remains authoritative for cross-platform completion and contains:

- macOS native app build and Swift runtime regression;
- Windows solution Release build with warnings as errors;
- Windows x64 release build, packaged app smoke, and package upload;
- Windows arm64 release build from the x64 lane;
- native Windows ARM64 solution/release build, packaged app smoke, and package upload;
- Windows runtime/core regression;
- the FMUX-020 final product gate on both Windows native jobs.

Local final build/regression results and exact-head/PR/main native run IDs are appended only after those stages actually pass.

## Current checkpoint

ACTIVE / CANDIDATE EVIDENCE. Final gate wiring and local final verification are the next stage. No claim of `PRODUCT_UI_UX_MAIN_VERIFIED` is made here.


## Local final verification

- FMUX-020 final aggregate gate: PASS after the two test-first RED gaps were repaired.
- Workflow wiring: final FMUX-020 gate is present exactly once in Windows x64 Verify and once in native Windows ARM64 Verify.
- Windows Release solution build: PASS with 0 warnings / 0 errors.
- Current-build screenshot QA: PASS; 14/14 pages at 1280x900, 14/14 unique SHA-256 page renders, non-flat sampled color/luminance checks. Report: `docs/evidence/artifacts/FMUX-020/current-ui/visual-qa-report.txt`.
- Windows core/runtime regression: PASS, `windows-core-tests: ok (995 assertions)`.
- Durable runtime PID `14804` remained alive/responding throughout; it was not restarted.

The first local runtime regression attempt reached the dynamic-health fixture and exposed a test-only race: the fake tunnel process could create the health-url file while still holding its write handle, while the test asserted only `File.Exists` and immediately called `File.ReadAllText`. Production runtime behavior did not fail. The targeted repair changes only `windows/tests/FileMCP.Core.Tests/Program.cs` to wait until the expected health URL is both present and readable, treating transient `IOException` as not-ready. This matches retry patterns already used by adjacent process/file fixtures. The failed runtime stage alone was resumed and then PASSed all 995 assertions.

Checkpoint: ACTIVE / LOCAL VERIFIED. Exact-head macOS / Windows x64 / native Windows ARM64 Verify, review, one PR, guarded merge, exact merged-main Verify, and final FMUX program state sync are still required. No claim of `PRODUCT_UI_UX_MAIN_VERIFIED` is made before those stages pass.

## Exact-head Verify attempt 1

Remote head `c31a5393ed55c6906bf5d36c0456ae0c9b515db8` ran Verify `37335689404` to completion.

- macOS: SUCCESS.
- Windows x64: FAIL only at `Verify dynamic health discovery contract`.
- native Windows ARM64: FAIL only at `Verify dynamic health discovery contract`.

The contract failure was caused by assertion-message drift from the test-only health-url race hardening: the static contract intentionally requires literal `stale health URL file is replaced by current tunnel launch`. Targeted repair restores that phrase while keeping the readable-file wait and transient `IOException` retry unchanged. The failed contract alone was rerun locally and PASSed. No production/runtime/core source changed; runtime PID `14804` was not restarted. Run `37335689404` is preserved as failed-attempt evidence and must not be rerun.

## Exact-head native verification / review PASS

Targeted repair head `79d423b480f90fde6e195941c219f9e15e32163e` passed Verify `37337080123` on all required lanes:

- macOS: SUCCESS, including static verification, integration tests, native app build and bundled legal resources;
- Windows x64: SUCCESS, including FMUX-020 product gate, dynamic-health contract, Windows integration tests, x64/ARM64 release builds, app smoke and x64 package upload;
- native Windows ARM64: SUCCESS, including FMUX-020 product gate, dynamic-health contract, native runner assurance, solution/release build, app smoke, release resources and package upload.

Scoped review from verified base `11d40cf277a490a360cb3f9ee61b690a292dfb7b` to `79d423b480f90fde6e195941c219f9e15e32163e` is PASS. The candidate changes CI/test contracts, durable state/evidence and visual proof artifacts only. There is no production source diff under `windows/src` or `macos`, and no FileMCP.Core/runtime/server/policy authority expansion. Runtime PID `14804` remains unchanged.

Checkpoint: ACTIVE / EXACT-HEAD NATIVE VERIFIED / REVIEW PASS. Next is an evidence/state-only closure commit, guarded push and fresh exact closure-SHA three-lane Verify before the single reviewed PR. No claim of `PRODUCT_UI_UX_MAIN_VERIFIED` is made before PR merge and exact merged-main Verify pass.


## Implementation MAIN VERIFIED / final governance state-sync

Closure head `788b82bd8e248d67c18ad2279d00eec2ede5fcd8` passed push Verify `37339216002` on macOS / Windows x64 / native Windows ARM64. PR #64 retained that exact closure head; PR Verify `37340337547` completed SUCCESS on all three required lanes.

PR #64 merged as main `821015002ca92f339df3434aa73e4887fd905670`. Exact merged-main Verify `37341640268` completed SUCCESS on macOS / Windows x64 / native Windows ARM64, including the FMUX-020 aggregate product gate, dynamic-health contract, Windows integration/build/package/smoke, native ARM64 build/smoke/package, and macOS integration/build/resources.

Therefore FMUX-020 implementation is DONE / MAIN VERIFIED and the frozen criterion for recording `PRODUCT_UI_UX_MAIN_VERIFIED` has been met. Canonical product marker: `docs/evidence/PRODUCT_UI_UX_MAIN_VERIFIED.md`, verified against main `821015002ca92f339df3434aa73e4887fd905670`.

Final governance state-sync is ACTIVE on `state/FMUX-020-main-verified`, based exactly on that verified main. Runtime PID `14804` remains unchanged and was not restarted. This governance diff is state/evidence only and does not authorize any production/core/runtime/tool-policy expansion. Failed run `37335689404` remains preserved historical evidence and must not be rerun.
