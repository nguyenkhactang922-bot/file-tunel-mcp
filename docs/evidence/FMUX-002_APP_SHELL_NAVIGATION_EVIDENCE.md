# FMUX-002 App Shell + Navigation Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-002-app-shell

## Scope implemented

Windows:
- labeled left sidebar shell;
- top TabItem headers hidden from primary navigation;
- legacy pages remain hosted in the existing TabControl as content;
- Home, Connections, Settings and Diagnostics navigation;
- compact navigation mode;
- persistent runtime/workspace context in shell.

macOS:
- primary NSTabView switched to noTabsNoBorder;
- native sidebar shell added;
- Connections, Settings and Diagnostics selectors;
- persistent runtime status context;
- legacy Connection/Settings/Logs pages preserved as hosted content.

## Scope guard

Not exposed before their FMG/FMUX dependencies:
- Repository;
- Terminal;
- Recovery;
- Evidence;
- future advanced capability pages.

No FMG runtime/security scope was changed.

## Local verification

- project-state contract: PASS;
- FMUX app-shell contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime regression: PASS, 750 assertions;
- canonical tool catalog hash unchanged: 8c5365afc0ae89e417c144ba77bbdc6a068e3fdbeefd92d674a62e1647c69d91;
- macOS build script syntax: PASS via Git Bash;
- git diff check: required before commit.

## FMUX-001 prerequisite

FMUX-001 DONE / MAIN VERIFIED:
- PR #20;
- merge main ee85ba494f36be6d15757fe338588cc92651518a;
- merged-main Verify run 36400920401 SUCCESS on Windows x64 / Windows ARM64 / macOS.

## Next exact action

Run diff/scope review.
Commit/push exact FMUX-002 candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Perform scoped review.
Merge only exact green head.
Verify merged main.
Then mark FMUX-002 DONE / MAIN VERIFIED and claim FMUX-003.
