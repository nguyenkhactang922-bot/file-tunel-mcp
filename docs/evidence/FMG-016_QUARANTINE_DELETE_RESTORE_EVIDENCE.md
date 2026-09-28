# FMG-016 Quarantine Delete / Restore Evidence

Status: LOCAL VERIFIED / MAIN SYNC + NATIVE CI PENDING
Date: 2026-09-29
Branch: chatgpt/FMG-016-quarantine-restore

## Implemented

Canonical tools added:
- quarantine_delete
- quarantine_list
- quarantine_get
- quarantine_restore

Catalog:
- version 1.8.0
- 29 canonical tools
- SHA-256 717917385167e7c9877f83d60165e295ea703c25f37a2422cdd6ab2abc4cb50e

Delete semantics:
- dry-run supports expected-version acquisition without mutation;
- expected-version + Mutation Guard are revalidated before destructive commit;
- quarantine payload/manifest is stored and verified before source deletion;
- durable record is persisted as prepared before destructive commit;
- state becomes quarantined only after source deletion and durable record update;
- failed pre-commit packaging/persistence cleans recovery material and preserves source;
- artifact quota/disk-full fail closed.

Restore semantics:
- destination appearance/change after plan is rejected;
- single-file restore uses guarded temp materialization and atomic publish;
- tree restore creates rollback checkpoint material before target creation;
- partial restore failure attempts rollback;
- terminal states: restored / rolled_back / partial_recovery_required;
- rollback failure retains recovery ContentRef for operator recovery.

Cross-platform:
- Windows QuarantineService.cs
- macOS QuarantineService.swift
- Windows/macOS catalog and handler parity
- native CI hooks wired into Verify/build scripts.

Integration hardening discovered during regression:
- ArtifactContentStore dependency is now lazy for LocalTools/QuarantineService, preserving volume-root workspaces without weakening the rule that actual artifact storage must be outside the workspace;
- canonical runtime-test expectations updated for catalog v1.8.0 / 29 tools;
- deterministic ContentRef tamper fixtures from verified main semantics are included in dirty checkpoint before main sync.

## Local verification

- project-state contract: PASS;
- quarantine-restore contract: PASS;
- tool catalog contract: PASS;
- tool surface parity: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows full runtime regression: PASS, 818 assertions;
- macOS build/test script syntax: PASS;
- git diff --check: PASS.

## Required negative coverage

Covered in Windows/macOS runtime/contract tests:
- stale source version;
- path swap / source changed before commit;
- expired quarantine reference;
- destination appeared after restore plan;
- tree partial failure;
- rollback failure retaining recovery artifact;
- artifact quota exhaustion;
- metadata persistence disk-full failure.

## Scope guard

No FMG-017+ functionality is claimed.
No ArtifactContentStore isolation rule is weakened.
No silent overwrite is introduced.
Quarantine destructive operations remain policy-authorized, version-guarded and Mutation-Guard protected.

## Next exact action

Commit this local-verified FMG-016 checkpoint.
Merge latest fork/main without dropping FMUX-014 MAIN VERIFIED work.
Resolve governance/catalog/test conflicts by preserving both main and FMG-016 authority.
Rerun only affected contracts/build/runtime gates.
Push exact synchronized head.
Require native Verify on macOS / Windows x64 / Windows ARM64.
Scoped review, PR/merge, merged-main Verify.
Then mark FMG-016 DONE / MAIN VERIFIED and claim the next dependency-ready task.

## Post-main-sync verification

Synchronized with verified main `7ced7b604d67acbb526e280e7e3653ba15d37d11` (FMUX-014 MAIN VERIFIED).
Affected gates after merge: project-state PASS; FMG-016 quarantine contract PASS; FMUX-014 artifact/batch contract PASS after lifecycle assertion accepted DONE state; catalog/parity PASS at 1.8.0 / 29 tools / `717917385167e7c9877f83d60165e295ea703c25f37a2422cdd6ab2abc4cb50e`; Windows Release 0 warnings/errors; Windows full runtime 818 assertions PASS; macOS script syntax PASS; diff check PASS.
NEXT_EXACT_ACTION: finish merge commit, push exact synchronized head, require native Verify on macOS / Windows x64 / Windows ARM64, scoped review, PR/merge, merged-main Verify.

## FMG-016 native Verify attempt 1 remediation

Run `36461034791` on `16fb4c22d401b04d89580d6f8d866e2174a39f12`: Windows x64 + ARM64 failed only because `tests/test_exec_process_contract.ps1` still expected 25 tools instead of catalog v1.8.0 / 29; macOS failed warnings-as-errors because `QuarantineService.list(maxItems:)` used an unnecessary `try` around a non-throwing lock closure.
Remediation is test/static-only: contract expectation/output updated to 29; redundant Swift `try` removed. Local affected-stage proof: exec-process contract PASS, quarantine contract PASS, macOS shell syntax PASS, diff check PASS. Product quarantine semantics are unchanged.
NEXT_EXACT_ACTION: commit/push remediation and require a new exact-head native Verify on all three lanes.
