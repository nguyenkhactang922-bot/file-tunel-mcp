# FMUX-008 Structured Activity Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-008-structured-activity

## Implemented

Windows:
- first-class Activity destination;
- structured bounded event timeline derived from real runtime/log stream;
- All/Error/Runtime/Settings filters;
- master/detail interaction;
- row and column virtualization;
- retained event cap of 500;
- raw logs remain under Diagnostics.

macOS:
- first-class Activity destination;
- native bounded event model capped at 500;
- filter popup;
- NSTableView structured timeline;
- selected-event detail;
- raw logs remain under Diagnostics.

## Local verification

- project-state contract: PASS;
- FMUX Structured Activity contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 776 assertions on targeted rerun;
- macOS build-script syntax: PASS.

One initial Windows runtime invocation hit the known FMG-014 ContentRef tamper-test flake ("Malformed ContentRef"); immediate targeted rerun of the same stage PASSed all 776 assertions. No FMUX code touched artifact semantics.

## FMUX-007 prerequisite

FMUX-007 DONE / MAIN VERIFIED:
- PR #28;
- merge main 1e5b1c94bd747a0576b7b2871ac78d10b649930a;
- merged-main Verify 36421881472 SUCCESS after targeted macOS rerun.

## Scope guard

No observability/runtime authority changed.
Structured events are a bounded presentation derived from existing runtime/log truth.
FMUX-009 remains blocked until FMUX-008 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Review.
Merge exact green head.
Verify merged main.
Mark FMUX-008 DONE / MAIN VERIFIED and claim FMUX-009.
