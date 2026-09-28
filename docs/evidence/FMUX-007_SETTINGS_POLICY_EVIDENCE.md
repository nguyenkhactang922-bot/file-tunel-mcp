# FMUX-007 Settings / Policy Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-007-settings-policy

## Implemented

Windows:
- structured Settings page with Workspace & access, Policy, Advanced execution/Git/telemetry, Appearance;
- dynamic policy explanation from the selected server-owned policy profile;
- advanced options remain progressively disclosed;
- no fake manual theme override; appearance truthfully follows system resources.

macOS:
- structured Settings sections with matching semantic grouping;
- dynamic policy explanation;
- advanced options preserved;
- truthful system-appearance statement.

## Local verification

- project-state contract: PASS;
- FMUX Settings / Policy contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 776 assertions;
- macOS build-script syntax: PASS.

## FMUX-006 prerequisite

FMUX-006 DONE / MAIN VERIFIED:
- PR #27;
- merge main c595af516ca31be3bb20ab34316fa5ad92fe02be;
- merged-main Verify 36420010186 SUCCESS.

## Scope guard

No policy authority, Git behavior, telemetry behavior, execution authority, or appearance mode was changed.
UI explains existing server-owned policy truth.
FMUX-008 remains blocked until FMUX-007 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge exact green head.
Verify merged main.
Mark FMUX-007 DONE / MAIN VERIFIED and claim FMUX-008.
