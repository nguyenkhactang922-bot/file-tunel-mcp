# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `main`
Git SHA source of truth: run git rev-parse HEAD.
Expected worktree at handoff: CLEAN.

## Completed technical program

PASS:
- FMR-001.
- OBS-001 through OBS-013.
- V11-001 through V11-008.
- FPA-001, FPA-002, FPA-003, FPA-005, FPA-006, FPA-007, FPA-008 and FPA-009.

Latest normal verification:
- Windows Release build: 0 warnings / 0 errors.
- Windows runtime suite: 444 assertions PASS.
- macOS native Verify: PASS.
- Windows x64 native Verify: PASS.
- Windows ARM64 native Verify: PASS.
- Production signing/notarization plumbing contract: PASS.
- Production Release workflow: active on fork default branch main.

## FPA-004 current boundary

FPA-004 state: EXTERNAL-BLOCKED ONLY ON REAL PRODUCTION RELEASE IDENTITY.

Repository-internal release plumbing is complete and verified:
- Windows Authenticode signing + timestamp + post-package verification.
- macOS Developer ID signing + hardened runtime + notarization + staple + Gatekeeper verification.
- GitHub Environment production-release exists and is restricted to main.
- Production Release workflow is registered on default branch main.
- non-secret readiness checker exists at release/check_production_release_readiness.ps1.

Real Production Release boundary proof:
- run 35762454809;
- version 0.4.0;
- Windows x64 failed only because WINDOWS_CODESIGN_PFX_BASE64 is absent;
- Windows ARM64 failed only because WINDOWS_CODESIGN_PFX_BASE64 is absent;
- macOS failed only because MACOS_DEVELOPER_ID_P12_BASE64 is absent.

Current readiness result:
- workflow active: YES;
- default branch: main;
- required production Environment secret names present: 0/7;
- usable local Windows code-signing certificate with private key: none found;
- fail-fast Production Release run 35764732944: preflight FAILED on 7 missing secret names, all three platform release jobs SKIPPED;
- preflight implementation Verify run 35764406983: macOS / Windows x64 / Windows ARM64 SUCCESS.

Required real Environment secrets:
1. WINDOWS_CODESIGN_PFX_BASE64
2. WINDOWS_CODESIGN_PFX_PASSWORD
3. MACOS_DEVELOPER_ID_P12_BASE64
4. MACOS_DEVELOPER_ID_P12_PASSWORD
5. APPLE_NOTARY_KEY_P8_BASE64
6. APPLE_NOTARY_KEY_ID
7. APPLE_NOTARY_ISSUER_ID

Do not mark FPA-004 PASS until a real credentialed Production Release succeeds and final artifacts pass post-package signature/notarization checks.

## GitHub/upstream status

Canonical verified working branch for release plumbing: fork main.
Fork: nguyenkhactang922-bot/file-tunel-mcp.
Production Release: active on fork main.

Upstream: dongttfd/file-tunel-mcp.
PR #2 remains the upstream integration path.
Connected bot does not have upstream write/merge permission.

## Resume law

On a new chat:
1. confirm git root / branch / HEAD / status;
2. read AGENTS.md and docs/CHATCODE_GLOBAL_MULTI_PROJECT_EXECUTION_LAW.md;
3. read this file and PROJECT_STATE.md;
4. read tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md;
5. resume the single authoritative next action;
6. do not repeat completed OBS/V11/FPA technical work.
