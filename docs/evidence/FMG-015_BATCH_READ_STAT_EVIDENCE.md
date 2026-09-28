# FMG-015 Batch Read / Stat Evidence

Status: SYNCHRONIZED LOCAL VERIFIED / NATIVE CI PENDING

Branch: `chatgpt/FMG-015-batch-read-stat`

## Scope implemented

- canonical `batch_stat` and `batch_read` tools;
- catalog version `1.7.0`, canonical tool count 25;
- per-entry SafePathResolver authorization;
- strong version token per eligible file;
- one aggregate ToolBudget across the batch;
- deterministic per-entry success/error/too_large states;
- explicit partial/truncated/cancelled summary;
- optional FMG-014 authenticated ContentRef spill for oversized reads;
- ContentRef spill uses the exact strong-version snapshot bytes, not a reopened path;
- Windows/macOS handler parity and build/runtime wiring.

## Local verification

PASS:
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror`: 0 warnings / 0 errors.
- isolated FMG-015 integration: `windows-batch-read-stat: ok`.
- isolated FMG-015 test count: 20 assertions.
- `tests/test_batch_read_stat_contract.ps1`: PASS.
- canonical catalog contract: PASS, tools=25.
- tool-surface parity: PASS, canonical=25.
- catalog SHA-256: `70faaa4cb370589191084ef76dfbcb502d810f5c8c658f0e1da80e9ec194a8c7`.

Covered negative/adversarial behavior:
- mixed valid + path-escape entries;
- deterministic duplicate-path handling;
- huge list rejection;
- aggregate bytes budget exhaustion across many entries;
- cancellation after first completed entry returns explicit partial state;
- strong read detects mutation during read;
- artifact quota exhaustion remains a per-entry failure;
- unknown per-entry field fails closed;
- post-version source mutation before ContentRef spill cannot change spill bytes: the artifact is built from `versioned.Data` / `versioned.data`.

## Full local regression note

Two full-suite local attempts reached unrelated pre-existing runtime flakes outside FMG-015:
1. transient lock on `runtime-dynamic-health.health-url`;
2. `DesktopSingleInstanceCoordinatorAsync` timeout.

FMG-015 itself passed before the first unrelated failure, and the isolated FMG-015 suite passes deterministically. These legacy runtime stages are not modified to mask the local environment; exact-head native GitHub Verify remains the authoritative full-regression gate.

## Remaining gate

1. commit local verified candidate;
2. merge latest `fork/main` without dropping concurrent FMUX work;
3. rerun affected local contracts/build;
4. push exact synchronized head;
5. require native Verify on macOS + Windows x64 + Windows ARM64;
6. scoped review;
7. PR/merge;
8. merged-main Verify;
9. mark FMG-015 DONE / MAIN VERIFIED and claim FMG-016.

## Main synchronization checkpoint

PASS:
- merged concurrent FMUX-005 through FMUX-009 main changes without dropping FMG-015;
- affected FMUX contract gates PASS;
- FMG-015 contract PASS after synchronization;
- Windows Release build PASS with 0 warnings / 0 errors;
- FMG-015 isolated integration PASS with 20 assertions;
- branch is behind fork/main by 0 commits at synchronized head.

NEXT_EXACT_ACTION: push the exact synchronized head, require native Verify on macOS + Windows x64 + Windows ARM64, fix only concrete failing stages, then scoped review -> PR/merge -> merged-main Verify -> FMG-015 MAIN VERIFIED -> FMG-016.


## Exact-head native Verify attempt 1

Candidate: `b9814e06e32a213977e290bfc579b5986753642d`.
Verify run: `36440733440`.

Result:
- Windows ARM64: SUCCESS.
- Windows x64: FAILED in full integration at the FMG-015 mutation assertion after all FMG-015 contracts passed.
- macOS: FMG-015 native `mcp-batch-stat`, `mcp-batch-read`, and `mcp-batch-budget` all PASS; the lane later exited because the legacy modern-tool assertions addressed tools by array index and catalog 1.7.0 inserted two tools.

Root causes and fixes:
1. Strong read previously depended on identity/size/timestamp snapshots to detect a same-size rapid mutation. On the hosted Windows runner that metadata could remain unchanged. FileVersionService now exposes an `after_first_chunk` test stage and performs an independent final content re-read/hash verification on Windows and macOS. The adversarial fixture mutates after the first captured chunk, proving a real mid-read mutation cannot pass as a coherent strong snapshot.
2. macOS modern-tool harness assertions now address canonical tools by name instead of hard-coded array indices, so catalog expansion cannot create a false integration failure.

Post-fix local proof:
- Windows Release build: 0 warnings / 0 errors.
- Full Windows integration: PASS, 796 assertions.
- FMG-015 isolated suite: PASS, 20 assertions.
- batch-read-stat contract: PASS.
- file-version/source-state contract: PASS.
- canonical catalog + tool-surface parity: PASS, 25 tools, SHA-256 `70faaa4cb370589191084ef76dfbcb502d810f5c8c658f0e1da80e9ec194a8c7`.

Remaining gate: commit fix -> synchronize latest main if needed -> push new exact head -> native Verify all three lanes -> scoped review -> PR/merge -> merged-main Verify.

## Exact-head Verify run 36440733440 - defect findings

Head: `b9814e06e32a213977e290bfc579b5986753642d`.

- Windows ARM64: SUCCESS.
- Windows x64: FAIL in FMG-015 mutation-during-strong-read assertion. Root cause: same-size write after the initial metadata snapshot can evade metadata-only before/after comparison on filesystems/runners with insufficient timestamp distinction.
- macOS: FMG-015 live MCP checks `mcp-batch-stat`, `mcp-batch-read`, and `mcp-batch-budget` all PASS. The job later failed because a legacy modern-catalog assertion addressed tools by numeric list position; adding two FMG-015 tools shifted those indices.

Corrective changes:
- Windows + macOS FileVersionService now expose an `after_first_chunk` test hook and perform a final independent content-hash verification pass bound to the expected native identity/metadata snapshot. Same-size mid-read mutation therefore fails even when size/mtime alone do not distinguish it.
- Windows mutation fixture now mutates after the first chunk, proving an actual mid-read race rather than a pre-read mutation.
- macOS runtime adds the same mid-read mutation proof.
- macOS catalog assertions use tool names instead of brittle numeric positions.

Targeted local verification after correction:
- Windows Release build: PASS, 0 warnings / 0 errors.
- FMG-015 isolated integration: PASS, 20 assertions.
- FMG-015 contract: PASS.

## Exact-head Verify run 36443414494 - attempt 2

Head: `c4b2eb5ce36109f686e53e83d53df5b90f84c735`.

- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS static/typecheck: PASS, including the cross-platform FileVersionService hardening.
- macOS integration: FAIL before executing the new mutation assertion because the same `fmg015Race...` test block existed twice in the generated Swift main, causing redeclaration diagnostics.

Remediation: remove the duplicate test block only; keep exactly one native macOS same-size mid-read mutation proof. Product code is unchanged from the Windows/ARM64-successful head.

## Exact-head Verify run 36444058795 - attempt 3

Head: `c341d6dfad6f90c20604543f3a7f2720213ea48a`.

PASS:
- macOS native Verify: SUCCESS;
- Windows x64 native Verify: SUCCESS;
- Windows ARM64 native Verify: SUCCESS.

After this run completed, fork/main advanced to FMUX-010 (`61359a9f98ddda9b78cb85ae87042620ab50f94f`). FMG-015 merged that main state. Post-sync local proof is PASS: FMG-015 contract, FMUX-010 Evidence contract, Windows Release build 0 warnings/errors, and full Windows regression 796 assertions.

NEXT_EXACT_ACTION: exact-head native Verify on the synchronized post-FMUX-010 head; then scoped review -> PR/merge -> merged-main Verify -> FMG-015 MAIN VERIFIED -> FMG-016.
