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