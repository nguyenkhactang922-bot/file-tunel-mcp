# FMUX-004 Home Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-004-home

## Implemented

Windows Home:
- PageHeader with canonical status;
- active workspaces derived from enabled settings;
- running work derived from runtime state;
- latest important event derived from actual error path;
- existing usage/activity telemetry retained;
- quick actions to Connections and Settings;
- existing Overview telemetry reused instead of duplicated.

macOS Home:
- Home content destination and sidebar navigation;
- runtime status;
- active workspace from configured directory;
- latest important event;
- quick actions to Connections and Settings.

## Local verification

- project-state contract: PASS;
- FMUX Home contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime: PASS, 750 assertions;
- macOS build-script syntax: PASS.

## Scope guard

No synthetic health or usage metrics were introduced.
No FMG authority or policy behavior changed.
FMUX-005 remains blocked until FMUX-004 MAIN VERIFIED.

## Next exact action

Commit/push exact candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge exact green head.
Verify merged main.
Mark FMUX-004 DONE / MAIN VERIFIED and claim FMUX-005.
