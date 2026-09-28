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
