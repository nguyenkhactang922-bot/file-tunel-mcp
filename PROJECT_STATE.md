# PROJECT STATE

Project: FileMCP
Active branch: `main`
Git SHA source of truth: resolve dynamically with `git rev-parse HEAD`.
Architecture law: `docs/process/IDEA_CAPTURE_AND_DESIGN_LAW.md`
Execution law: `docs/CHATCODE_GLOBAL_MULTI_PROJECT_EXECUTION_LAW.md`

## Completed initiatives

- FMR-001 PASS.
- Observability V1: OBS-001 through OBS-013 PASS.
- Observability V1.1 strengthening: V11-001 through V11-008 PASS.
- Real ChatGPT connector logical-chat correlation acceptance PASS.
- FPA-001 Windows CI staging parity PASS.

## Current final-product program

Whole-app independent audit found additional blockers outside the already-verified Windows observability core.

Audit report:
`docs/audit/FINAL_PRODUCT_INDEPENDENT_REPOSITORY_AUDIT_2026-09-22.md`

Task graph:
`tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`

Current decision:

```text
Windows core / Observability V1+V1.1   VERIFIED
Whole-repository release readiness     EXTERNAL-BLOCKED ON FPA-004 REAL RELEASE TRUST
V11-009 technical fork-main verify      PASS; FINAL PASS EXTERNAL-BLOCKED
```

## Verified quality baseline

- Windows Release build: PASS, 0 warnings / 0 errors.
- Full Windows runtime suite: PASS, 444 assertions.
- x64 packaged app smoke: PASS.
- x64 + ARM64 release-resource packaging: PASS under FPA-001 isolated staging verification.
- NuGet vulnerable-package audit: no vulnerable packages reported.
- Direct-package outdated audit: no updates reported.
- OBS-013 live ChatGPT cross-turn correlation and raw-handle privacy: PASS.

## Current open product findings

- FPA-002 PASS: macOS logical-chat/tool-surface parity, native CI verified.
- FPA-003 PASS: macOS bounded tunnel supervisor parity, native CI verified.
- FPA-004 EXTERNAL-BLOCKED: signing/notarization plumbing is native-CI verified; real production credentials + default-branch workflow registration + credentialed release run remain.
- FPA-005 PASS: native Windows ARM64 runtime assurance verified by GitHub hosted ARM64 runner.
- FPA-007 PASS: per-user Windows desktop single-instance activation verified on x64 and ARM64.
- FPA-008 PASS: cross-platform HTTP connection cap plus idle/header deadlines, native CI verified.
- FPA-009 PASS: dynamic health endpoint discovery via official tunnel-client URL file, native CI verified.

FPA-006 PASS. FPA-002 PASS with native macOS/Windows CI. Current remediation advances to FPA-003.


FPA-003 native CI PASS: run 35723605790 succeeded on both verify-macos and verify-windows. Current remediation advances to FPA-005.


FPA-005 candidate: native Windows ARM64 job + parameterized packaged smoke are implemented; local contracts and Windows regression PASS. Native ARM64 GitHub execution is the remaining acceptance gate.


FPA-005 native CI PASS: run 35726514963 succeeded on verify-macos, verify-windows and verify-windows-arm64. Current remediation advances to FPA-007.


FPA-007 candidate: per-user named-pipe single-instance activation is implemented; core 423 assertions and packaged x64 duplicate-launch activation smoke PASS. Native CI remains the final acceptance gate.


FPA-007 native CI PASS: run 35728230159 succeeded on macOS, Windows x64 and Windows ARM64 with second-launch activation smoke. Current remediation advances to FPA-008.


FPA-008 native CI PASS: run 35745850301 succeeded on verify-macos, verify-windows and verify-windows-arm64. Current technical remediation advances to FPA-009 before the remaining public-market signing gate.


FPA-009 native CI PASS: run 35748443822 succeeded on verify-macos, verify-windows and verify-windows-arm64. Remaining whole-app market gate is FPA-004 signing/notarization.


FPA-004 plumbing candidate: release-only Windows Authenticode and macOS Developer ID/notarization/stapling automation is implemented locally. Local contracts/build/runtime/package smoke PASS. Native Verify is the next gate; real production credentials are not configured on the connected fork and remain required for FPA-004 PASS.


FPA-004 plumbing VERIFIED: GitHub Actions run 35752248896 succeeded on verify-macos, verify-windows and verify-windows-arm64. The fork production-release Environment now exists, but all seven real release secrets are absent. Upstream PR #2 remains open and the connected bot has read-only upstream permission. FPA-004 cannot be marked PASS until a real signed/notarized/stapled release run succeeds.


Final post-remediation audit: docs/audit/FINAL_PRODUCT_POST_REMEDIATION_AUDIT_2026-09-22.md. No additional repo-internal bug was opened; remaining blocker is FPA-004 real release trust credentials/default-branch execution.


Default-branch release registration: VERIFIED. Fork main commit 884e9a89 passed native Verify run 35755705022 on macOS, Windows x64 and Windows ARM64. Production Release is active on the default branch and production-release permits main. FPA-004 is now blocked only by absent real release credentials and the required real signed/notarized release run.


V11-009 technical main verification: PASS on fork main commit 1d3e14d with native Verify run 35756276412 succeeding on macOS, Windows x64 and Windows ARM64. Final V11-009 remains EXTERNAL-BLOCKED on upstream merge authority and FPA-004 real production-signing evidence.
