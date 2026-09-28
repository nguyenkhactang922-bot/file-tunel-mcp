# FMUX-007 Settings / Policy Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-007-settings-policy-v2

## Implemented

Windows:
- Settings PageHeader and grouped General / Policy & permissions / Appearance / Storage & retention sections;
- advanced progressive-disclosure Execution and Git sections;
- dynamic policy explanation for Restricted, Workspace auto, Custom, and migration-only Legacy profile;
- factual Appearance state: follows OS appearance/accessibility; no fake theme setting;
- factual Storage state: runtime retention policies remain authoritative; UI cannot bypass.

macOS:
- Settings header and equivalent section taxonomy;
- dynamic policy explanation wired to policy popup selection;
- advanced Execution/Git grouping preserved;
- factual Appearance and Storage/retention presentation only.

## Local verification

- project-state contract: PASS;
- FMUX Settings/Policy contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 776 assertions;
- macOS build-script syntax: PASS.

## FMUX-006 prerequisite

FMUX-006 DONE / MAIN VERIFIED:
- PR #27;
- merge main c595af516ca31be3bb20ab34316fa5ad92fe02be;
- merged-main Verify 36420010186 SUCCESS.

## Scope guard

No new permission, policy authority, storage override, or theme authority was introduced.
All effective permissions remain runtime-enforced.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge exact green head.
Verify merged main.
Mark FMUX-007 DONE / MAIN VERIFIED and claim FMUX-008.
