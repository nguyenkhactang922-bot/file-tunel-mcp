# FMUX-009 Changes Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-009-changes

## Implemented

Windows:
- first-class Changes destination and sidebar navigation;
- bounded captured mutation-event list from real runtime log/activity flow;
- Applied / Stale / Conflict / Failed status mapping;
- detail pane with file/version context shown only when emitted;
- explicit no-synthetic-diff behavior.

macOS:
- matching Changes destination and sidebar navigation;
- bounded mutation-event list from the same real log/activity flow;
- status classification and detail surface;
- explicit unavailable file/version context when runtime event does not emit it.

## Local verification

- project-state contract: PASS;
- FMUX Changes contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 776 assertions;
- macOS build-script syntax: PASS.

## FMUX-008 prerequisite

FMUX-008 DONE / MAIN VERIFIED:
- PR #30;
- merge main 4c83cc17fc70433674fb92643ffa22ff17f4da4f;
- merged-main Verify 36423928925 SUCCESS.

## Scope guard

No mutation authority, file-version semantics, apply_edits semantics, or Git behavior changed.
The UI consumes observed mutation events only and does not synthesize file/version/diff data.
FMUX-010 remains blocked until FMUX-009 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge exact green head.
Verify merged main.
Mark FMUX-009 DONE / MAIN VERIFIED and claim FMUX-010.
