# FMUX-019 Cross-Platform UX Adversarial Gate Evidence

Status: LOCAL VERIFIED
Date: 2026-10-05
Branch: `chatgpt/FMUX-019-cross-platform-adversarial`
Claim base: verified main `253901ff2fc5eb4996c2842d3a4a2d05d87fcebf`
Runtime guard: existing FMG026-ready PID `14804` remained running and was not restarted.

## Frozen scope

FMUX-019 is an adversarial verification gate over the already MAIN VERIFIED FMUX product surfaces. It verifies Windows/macOS parity, error/empty/stale/offline states, keyboard-only completion, feature/capability gating, security-language truthfulness, and preservation of legacy/core regression proof. It must not reinterpret core authority or reopen previously verified feature implementation without a proven gap.

## Resume / dependency proof

FMUX-018 governance closure is fully MAIN VERIFIED: state head `d5112ab47f5c1d3d3b35ecd3a76da583479593be`; push Verify `37300900430` SUCCESS; PR #61 Verify `37301719404` SUCCESS; PR #61 merged as main `253901ff2fc5eb4996c2842d3a4a2d05d87fcebf`; merged-main Verify `37302476304` SUCCESS on macOS / Windows x64 / native Windows ARM64. FMUX-019 was claimed directly from that exact verified main.

## Baseline adversarial inventory

Before changing production source, all 18 existing `tests/test_fmux*.ps1` contracts were executed once on the claim base and all 18 passed. This proved the existing presentation/status/navigation, shell, feedback, Home, Workspaces, Connections, Settings, Activity, Changes, Evidence, Artifact/Batch, Repository, Terminal, Recovery, Backend/Isolation, Onboarding, Accessibility/Theme, and Performance/Visual contracts had not drifted.

The inventory found two real gate-level gaps only:

1. Eleven foundation FMUX contracts existed and passed locally but were not retained by `.github/workflows/verify.yml`: presentation, app shell, feedback components, Home, Workspaces, Connections, Settings/Policy, Structured Activity, Changes, Evidence, and Artifact/Batch.
2. Several caught-exception paths displayed a raw exception string as the complete modal UX on both Windows and macOS, violating the frozen error contract requiring what failed, affected scope, state-change truth, and a safe next action.

Offline/disconnected state, keyboard focus/action semantics, feature gating, no-authority language, stale/error/unavailable semantics, and core/native regression wiring were already present and required no production rewrite.

## Test-first red checkpoint

Added `tests/test_fmux_cross_platform_adversarial_gate.ps1` before repairs. Its first run failed exactly on the two proven gaps:

- FMUX-019 workflow wiring expected 2, actual 0;
- Windows raw-exception-only settings-load/catch paths and missing structured helper;
- macOS raw-exception-only catch paths and missing structured helper.

All eleven foundation contracts executed by the new aggregate gate passed during this RED run, so no earlier FMUX feature was reimplemented.

## Minimal repairs

### CI continuity

The FMUX-019 aggregate gate now runs exactly once in each Windows-native Verify job (Windows x64 and native Windows ARM64). The gate executes the eleven previously unwired, cheap/static foundation FMUX contracts. Existing FMUX-011..018 Verify steps remain unchanged, avoiding duplicate task-specific execution in the same job. Existing FMG advanced adversarial, Windows runtime/integration/package smoke, macOS native Swift runtime/build/package proof remain required.

### Structured operational errors

Windows and macOS now route caught operational failures through a presentation-layer structured error helper. User-facing failures include:

- what failed;
- affected scope;
- whether state changed or is uncertain;
- safe next action;
- optional secondary technical detail.

Validation messages still use their existing concise validation path. The repair changes presentation only: no MCP/tool authority, filesystem scope, credential authority, network policy, backend selection, runtime API, or core service semantics changed.

## Local verification

PASS:

- `tests/test_fmux_cross_platform_adversarial_gate.ps1`
  - eleven foundation contracts PASS inside the aggregate gate;
  - parity/security/offline/keyboard/feature-gating/core-regression assertions PASS;
- affected contracts:
  - `test_fmux_feedback_components_contract.ps1`
  - `test_fmux_connections_contract.ps1`
  - `test_fmux_settings_policy_contract.ps1`
  - `test_fmux_onboarding_contract.ps1`
  - `test_fmux_accessibility_theme_contract.ps1`
  - `test_fmux_performance_visual_consistency_contract.ps1`
  - `test_project_state_contract.ps1`
- raw-error scan: Windows direct/raw catches = 0; macOS `showError(error.localizedDescription)` = 0;
- FMUX-019 workflow wiring count = 2;
- core-source diff guard = empty;
- `git diff --check` PASS;
- Windows Release win-x64 build PASS: 0 warnings / 0 errors.

macOS native typecheck/integration/build/package is not claimed locally on Windows; exact-head GitHub Verify remains authoritative for that native lane.

## Remaining lifecycle

1. sync LOCAL VERIFIED state/evidence;
2. scoped diff/security review;
3. commit exact FMUX-019 candidate;
4. side-effect guard remote branch/PR/main;
5. push exact head;
6. require exact-head Verify SUCCESS on macOS / Windows x64 / native Windows ARM64;
7. exact-head review;
8. create exactly one PR;
9. require PR Verify SUCCESS;
10. guarded merge;
11. require exact merged-main Verify SUCCESS;
12. governance state-sync to MAIN VERIFIED;
13. only then unlock FMUX-020.
## Exact-head Verify attempt 1 / targeted repair

Candidate `ce935f760c51bbb76cf4b8f003a339c483e3b227` triggered Verify `37312247737`.

- macOS native lane: SUCCESS; preserve this PASS and do not rerun it manually.
- Windows x64: FAIL only at `Verify FMUX Cross-Platform UX Adversarial Gate`.
- native Windows ARM64: FAIL only at the same FMUX-019 gate.
- Failed logs on both Windows lanes showed the same cause: historical foundation tests FMUX-002 and FMUX-004..010 required the obsolete literal lifecycle `State: ACTIVE / CLAIMED`, although those historical tasks are now `DONE / MAIN VERIFIED`.
- No production/runtime/core failure was observed.

Targeted repair only: eight legacy foundation contract files now resolve their own FMUX task-graph section and accept the valid lifecycle progression `ACTIVE / CLAIMED`, `ACTIVE / LOCAL VERIFIED`, or `DONE / MAIN VERIFIED`. No production source changed in this repair.

Only the failed FMUX-019 aggregate stage was rerun locally after the repair; it PASSed with all eleven foundation contracts green. The next remote action is a fix commit + guarded push of the new exact head; the old failed run is complete and must not be rerun.
## Exact-head native verification / review PASS

Targeted repair head `1fc91be563d70306bdfe84216906198723604a22` passed exact-head Verify `37313099533` on all required native lanes:

- macOS: SUCCESS (static verification, integration, native app build/resources);
- Windows x64: SUCCESS, including the FMUX-019 aggregate gate, runtime integration, x64/arm64 package build and app smoke;
- native Windows ARM64: SUCCESS, including the FMUX-019 aggregate gate, native solution/release build, smoke and package upload.

Scoped review from verified base `253901ff2fc5eb4996c2842d3a4a2d05d87fcebf` to `1fc91be563d70306bdfe84216906198723604a22` is PASS. Changes are limited to presentation source, CI/test gates and durable evidence/state. No `FileMCP.Core`, LocalMCPServer/Runtime, policy/backend/service authority surface changed. Runtime PID `14804` remains unchanged.

Checkpoint: EXACT-HEAD NATIVE VERIFIED / REVIEW PASS. Do not rerun the failed attempt `37312247737`.

## Implementation MAIN VERIFIED / governance state-sync

FMUX-019 closure head `04daf8443b4e74ab6ed80124319977d5eb656fc1` passed push Verify `37314184374` on macOS / Windows x64 / native Windows ARM64. PR #62 retained that exact head; PR Verify `37315279071` SUCCESS on all three required lanes; scoped review PASS with no core/runtime/tool-authority expansion.

PR #62 merged as main `70e4379c11339a32ae794157eeb5d3f1fb471998`. Post-merge Verify `37316174195` SUCCESS on macOS / Windows x64 / native Windows ARM64. Therefore the FMUX-019 implementation result is DONE / MAIN VERIFIED at that main commit.

Governance state-sync is ACTIVE on `state/FMUX-019-main-verified`, based exactly on verified main `70e4379c11339a32ae794157eeb5d3f1fb471998`. Runtime PID `14804` remains unchanged. FMUX-020 is intentionally not claimed until this governance state-sync is pushed, exact-head verified, reviewed/merged by PR, and its resulting main commit passes exact merged-main Verify.
