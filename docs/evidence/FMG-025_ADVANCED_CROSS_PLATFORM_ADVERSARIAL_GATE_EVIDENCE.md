# FMG-025 Advanced Cross-Platform Adversarial Gate Evidence

Status: LOCAL GATE PASS / EXACT-HEAD NATIVE VERIFY PENDING
Date: 2026-10-03
Branch: `chatgpt/FMG-025-adversarial-gate`
Base: verified main `2bd859a966f9f49075ffc7d0a544154cb5d76498`
Authority: ADR-0005, ADR-0006, `tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md`

## Frozen scope

FMG-025 is a verification gate over FMG-014 through FMG-024. It does not redesign or reimplement those capabilities. The gate must prove:
- Windows/macOS contract parity for advanced common tools;
- artifact/quarantine/checkpoint privacy and security coverage;
- native PTY coverage;
- repository-intelligence scale/corruption coverage;
- execution-backend/Docker lifecycle and security coverage;
- no raw advanced content enters telemetry/evidence;
- no weakening of ADR-0005 foundation invariants.

## Source-of-truth baseline

FMG-024 was merged to main as `2bd859a966f9f49075ffc7d0a544154cb5d76498`. Merged-main Verify run `37095113136` succeeded on macOS, Windows x64 and native Windows ARM64, including the existing FMG-014..024 contract/runtime suites. The optional live Docker engine proof remains explicitly ENVIRONMENT-BLOCKED because the local daemon is unavailable; no live Docker PASS is claimed.

## Gap found

The advanced negative suites already existed and were individually wired into native verification, but FMG-025 had no aggregate gate proving that the complete advanced matrix remained wired across the native jobs and retained the required privacy/foundation invariants.

No production/runtime implementation gap was found during this inventory.

## Change

Added `tests/test_advanced_adversarial_gate.ps1` and wired it exactly once into each Windows-native Verify job (Windows x64 and Windows ARM64). The gate:
- requires all FMG-014..024 advanced PowerShell contract suites to exist and remain wired in both Windows-native jobs;
- requires macOS native Verify to compile all advanced Swift sources and run `tests/test_swift_runtime.sh`;
- verifies frozen catalog `1.13.0` / 46 tools;
- preserves foundation tool-surface, file-version, Mutation Guard, mutation-hardening, apply-edits and metadata-evidence gates;
- checks artifact/evidence separation, PTY evidence/telemetry exclusion, checkpoint no-transcript guards, repository-intelligence raw-source/corruption/scale guards, and Windows/macOS adversarial runtime markers;
- requires FMG-024 evidence to keep live Docker proof explicitly environment-blocked and to reject fake live PASS claims.

The aggregate gate intentionally does not rerun the expensive task-specific suites itself; CI continues to execute those suites once in their existing steps. This avoids duplicate test execution while making FMG-025 wiring/coverage drift fail closed.

## Local evidence

Command:
`powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/test_advanced_adversarial_gate.ps1`

Result: PASS

Observed output:
- `advanced-adversarial-gate: ok (FMG-014..024 parity/privacy/security/runtime wiring)`
- `catalog: 1.13.0 / 46 tools`
- `native-jobs: macOS + Windows x64 + Windows ARM64`
- `docker-live-proof: environment-blocked unless a real engine is available`

`git diff --check`: PASS.

## Remaining closure path

NEXT_EXACT_ACTION: commit the FMG-025 gate/evidence/state candidate, push the exact head, require native Verify on macOS / Windows x64 / native Windows ARM64, repair only a real failed stage, then perform exact-head review, PR/merge and merged-main Verify before marking FMG-025 DONE / MAIN VERIFIED and claiming FMG-026.
