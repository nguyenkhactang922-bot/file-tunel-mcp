# FMUX-006 Connections Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-006-connections

## Implemented

Windows:
- Connections PageHeader with runtime status;
- credential status badge sourced from Windows Credential Manager state;
- connectivity diagnostics sourced from enabled/running workspaces and configured tunnel IDs;
- existing save/connect/disconnect flows preserved.

macOS:
- Connections header;
- credential status sourced from Keychain state;
- tunnel/configuration diagnostics;
- runtime connection state;
- existing save/connect/disconnect behavior preserved.

## Local verification

- project-state contract: PASS;
- FMUX Connections contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 776 assertions;
- macOS build-script syntax: PASS.

## FMUX-005 prerequisite

FMUX-005 DONE / MAIN VERIFIED:
- PR #25;
- merge main d13ec1a1b135ae2706158accf007000f1aa71510;
- merged-main Verify 36418561277 SUCCESS.

## Scope guard

No new credential authority or runtime permissions were introduced.
UI remains a presentation layer over existing credential/tunnel/runtime truth.
FMUX-007 remains blocked until FMUX-006 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge exact green head.
Verify merged main.
Mark FMUX-006 DONE / MAIN VERIFIED and claim FMUX-007.
