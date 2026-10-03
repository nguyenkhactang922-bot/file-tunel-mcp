# FileMCP Complete Upgrade — MAIN VERIFIED

Date: 2026-10-03

Status: **COMPLETE_UPGRADE_MAIN_VERIFIED**

Verified main commit: `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`

## Completion chain

The complete-upgrade core FMG-001..FMG-026 has reached its frozen final gate with real repository, runtime, GitHub, and exact-main-commit evidence.

- FMG-025 prerequisite: DONE / MAIN VERIFIED.
- FMG-026 frozen full regression/package checkpoint: exact head `21d0c6ed05a749be363b108a7a965a7f0deaef9e`, Verify `37109212534`, SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Correct FMG026-ready runtime: PID `17860`, executable `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`.
- Canonical catalog: `1.13.0`, 46 tools, SHA-256 `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`.
- Effective policy-filtered live surface: 45 tools because `CustomPolicyAllowShell=false`; only compatibility shell tool `run_command` is intentionally hidden. Shell authority was not enabled merely to increase the visible count.
- Live Secure MCP Tunnel readiness: PASS for both configured profiles.
- Prior live basic file/Git/direct-exec/project-context/evidence dispatch proof: PASS.
- Live advanced proof: PASS for batch + authenticated ContentRef, quarantine delete/list/get/restore, search/replace and unified-diff edit adapters, repository-intelligence facade on a bounded Git fixture, workspace checkpoint capture/list/get/restore/delete, and native Windows ConPTY start/list/resize/write/read/signal/stop.
- Temporary live-proof fixture cleanup: PASS; no product/runtime source implementation change was introduced by the proof.
- Optional Docker live engine proof: **ENVIRONMENT BLOCKED** because the local daemon is unavailable; this is explicitly permitted by the frozen FMG-024/FMG-026 availability rule and is not represented as a live Docker PASS.

## GitHub closure

Primary FMG-026 closure candidate:
- commit `e39877808b3fb0394b5b5a2608d6489ad6d8404f`;
- push exact-head Verify `37120899485`: SUCCESS on macOS / Windows x64 / native Windows ARM64;
- PR #47 `Close FMG-026 complete upgrade regression gate`;
- PR exact-head Verify `37121297945`: SUCCESS on macOS / Windows x64 / native Windows ARM64;
- scoped review: PASS;
- PR #47 merged with expected-head guard;
- resulting `main` commit: `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`.

## Post-merge exact-main verification

GitHub produced the PR #47 `merged` event and advanced `main` to `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`, but unlike prior merges it emitted no repository `PushEvent` for that main update and created no check suite on the merge commit. This anomaly is recorded rather than hidden.

To verify the actual post-merge tree without inventing a new source commit, a verification-only remote ref was created pointing **exactly** to the existing main commit:

`verify/FMG-026-main-03cf7c0 -> 03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`

No commit, code, docs, state, or tree delta was introduced by that ref.

Verify run `37121899760` executed with `headSha=03cf7c082e29fb9eb576a875e4d73b018d5cc9f0` and completed **SUCCESS** on:
- Windows x64;
- native Windows ARM64;
- macOS.

This is verification of the exact actual post-merge `main` commit, not reuse of a pre-merge branch run. There was no `main`-branch workflow run for this merge, and this evidence does not claim otherwise.

## Final result

`FMG-026 = DONE / MAIN VERIFIED`

`FILEMCP COMPLETE-UPGRADE CORE = DONE / COMPLETE_UPGRADE_MAIN_VERIFIED`

Verified main: `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`

Canonical supporting evidence: `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.

The next task may be claimed only after this closure state-sync itself completes the mandatory GitHub push -> PR -> review -> merge -> exact resulting-main verification lifecycle. After that, re-evaluate `tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md` and claim the lowest dependency-ready FMUX task; current graph inspection indicates FMUX-011 is the first such candidate.
