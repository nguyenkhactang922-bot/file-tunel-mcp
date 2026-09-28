# FMUX-014 Artifact / Batch UX Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-28
Branch: chatgpt/FMUX-014-artifact-batch

## Implemented

Windows:
- first-class Artifacts destination and sidebar navigation;
- bounded batch-result history from real batch_read / batch_stat structured results;
- grouped batch summary with requested/completed/partial/cancelled/truncated state;
- per-entry large-output inspection with path, state, delivery, size, expiry and blob metadata;
- explicit ContentRef-presence metadata without logging the raw ContentRef token;
- observed artifact quota errors without inventing remaining quota.

macOS:
- matching Artifacts destination and navigation;
- bounded batch-result and entry tables;
- grouped/partial/cancelled/truncated result summary;
- ContentRef-presence, expiry, size, blob and observed quota-error metadata;
- explicit unavailable/unknown quota truth when remaining quota is not emitted.

Core presentation marker:
- Windows and macOS emit a read-only [ArtifactBatchResult] projection after successful batch_read / batch_stat;
- inline file content is excluded;
- raw ContentRef token is excluded;
- the marker does not change batch/file/artifact authority or tool result semantics.

## Local verification

- project-state contract: PASS;
- FMUX Artifact / Batch contract: PASS;
- Windows Release build: PASS, 0 warnings / 0 errors;
- Windows runtime regression: PASS, 797 assertions after deterministic tamper-fixture hardening;
- macOS build-script syntax: PASS;
- git diff --check: PASS before evidence checkpoint.

The Windows and macOS runtime gates exposed the same pre-existing nondeterministic FMG-014 tamper-fixture ambiguity: mutating the final base64url signature character could produce a non-canonical token and fail as Malformed ContentRef before reaching the intended HMAC-authentication assertion. Both test fixtures were hardened to mutate the first signature-segment character instead, preserving a canonical token while still proving tamper rejection. Runtime authority and ContentRef semantics were not changed. Windows runtime passed with 797 assertions; macOS exact-head re-verification is required for the Swift fixture.

## Scope guard

No ContentRef authentication, expiry, quota, artifact storage, batch authorization, SafePathResolver, ToolBudget, version-token, cancellation or partial-result authority changed.
The UI only presents sanitized metadata already produced by FMG-014 / FMG-015 behavior.
No synthetic remaining-quota value and no raw ContentRef token are exposed in the presentation marker.

## Next exact action

Check latest fork/main and remote FMUX-014 branch state.
If main advanced, sync it without dropping concurrent FMG/FM UX work and rerun only affected local gates.
Commit/push the exact synchronized candidate.
Require native Verify on Windows x64 / Windows ARM64 / macOS.
Scoped review.
Merge only exact green head.
Verify merged main.
Mark FMUX-014 DONE / MAIN VERIFIED and claim the next dependency-ready FMUX task.
