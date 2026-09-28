# FMUX-005 Workspaces Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-005-workspaces

## Implemented

Windows:
- first-class Workspaces destination and sidebar navigation;
- multi-drive workspace list for C/D/E/F;
- per-workspace root, enabled/runtime state, profile/policy context, connection and activity detail;
- master/detail inspection;
- live row refresh from existing runtime/settings truth.

macOS:
- first-class Workspaces destination and sidebar navigation;
- configured workspace root, runtime status, policy profile and connection state;
- native single-workspace parity matching the current macOS runtime architecture.

## Local verification

- project-state contract: PASS;
- FMUX Workspaces contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 750 assertions;
- macOS build-script syntax: PASS.

## FMUX-004 prerequisite

FMUX-004 DONE / MAIN VERIFIED:
- PR #24;
- merge main e4e243ab1526d8cb67e7b2304b649227726e02f5;
- merged-main Verify 36414061842 SUCCESS.

## Scope guard

No new workspace authority or runtime path semantics were introduced.
The UI only presents existing settings/runtime facts.
FMUX-006 remains blocked until FMUX-005 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge only exact green head.
Verify merged main.
Mark FMUX-005 DONE / MAIN VERIFIED and claim FMUX-006.
