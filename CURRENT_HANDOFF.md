# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `chatgpt/FMG-005-exec-process`
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

## FPA-004 scope decision

FPA-004 state: OUT-OF-SCOPE BY PRODUCT AUTHORITY for the current release target.

The current product scope does not require Windows Authenticode identity or Apple Developer ID/notarization identity. Unsigned developer/internal/direct-use distribution is accepted. Existing signing/notarization plumbing remains implemented and verified as an optional future capability; no signed/notarized artifact claim is made.

Authority/evidence:
- `docs/adr/0003-unsigned-distribution-scope.md`;
- `docs/evidence/FPA-004_SCOPE_DECISION_EVIDENCE.md`.

If public-market signed distribution is required later, reopen FPA-004-F/G and provide real credentials plus real signed/notarized artifact evidence.

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


## Secure production secret provisioning helper

The helper remains available and verified for a future signed-distribution scope, but production signing credentials are not required by the current unsigned release target.


## V11-009 final technical verification

Technical main verification is PASS on fork main.

Evidence:
- docs/evidence/V11-009_FINAL_TECHNICAL_MAIN_EVIDENCE.md
- native Verify run 35874974993: macOS / Windows x64 / Windows ARM64 SUCCESS
- local Windows Release build: 0 warnings / 0 errors
- Windows runtime suite: 444 assertions PASS
- x64/ARM64 package resources PASS
- x64 packaged app smoke PASS

PR #2 is open, clean and mergeable at the exact verified tree. The connected bot has upstream READ only and cannot execute the final merge.

No repository-internal technical task remains.
## Future architecture track - ChatCMD integration

Status: DESIGN-FROZEN, NOT ACTIVE IMPLEMENTATION.

A multi-round independent audit of int04/ChatCmd was completed against pinned commit c20e134ad6b60ef12eee7231bcbca56f5252be45. The accepted design is selective native reimplementation, not repository merging or a runtime rewrite.

Authorities:
- docs/audit/CHATCMD_INDEPENDENT_MULTI_ROUND_INTEGRATION_AUDIT_2026-09-23.md
- docs/design/CHATCMD_SOURCE_TO_FILEMCP_MAPPING_V1.md
- docs/design/CHATCMD_INTEGRATION_DECISION_MATRIX_V1.md
- docs/adr/0004-chatcmd-inspired-execution-foundation.md
- tasks/CHATCMD_INTEGRATION_CANDIDATE_QUEUE.md

This future track does not replace the current authoritative V11-009 upstream-merge action. When project authority activates the integration program, claim CCI-001 only.
## Final cross-repo architecture program

Status: DESIGN GATE COMPLETE / READY TO IMPLEMENT, BUT FEATURE CODING NOT STARTED.

Final authority:
- docs/adr/0005-final-coding-agent-gateway-architecture.md
- docs/design/MASTER_FILEMCP_CODING_AGENT_GATEWAY_ARCHITECTURE_V1.md
- docs/design/FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md
- tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md

The cross-repo program completed Codex/OpenHands/Aider/Cline/Goose/ChatCMD comparison, contradiction synthesis, function-level upgrade decisions, independent red-team, P1 repair and repair re-audit.

Future implementation NEXT_EXACT_ACTION when this program is explicitly started: claim FMG-001 Canonical Catalog Authority only.

Do not begin FMG-001 in this design-only handoff. The existing V11-009 upstream merge authority gate remains the repository's unrelated current external closure action.

## Complete-scope pre-code freeze

Status: COMPLETE DESIGN/TASK SPLIT FROZEN / FEATURE CODING NOT STARTED.

Product authority requires the complete current upgrade to be designed before coding. ADR-0006 extends ADR-0005 and resolves all former advanced `DEFER` items into BUILD or REJECT.

Complete authorities:
- docs/adr/0006-complete-upgrade-scope-freeze.md
- docs/design/MASTER_FILEMCP_COMPLETE_UPGRADE_ARCHITECTURE_V2.md
- docs/design/FINAL_COMPLETE_SCOPE_FUNCTION_MATRIX.md
- tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md

Implementation starts at FMG-001 only and proceeds through FMG-026 without a new architecture pause after FMG-013.

FMG-026, not FMG-013, is the complete upgrade completion gate.
## FMG-001 active implementation

State: CLAIMED / ACTIVE.

Branch: `chatgpt/FMG-001-canonical-catalog`.

NEXT_EXACT_ACTION: implement FMG-003 Server-Owned Policy + Migration only: restricted/workspace-auto/custom profiles, legacy EnableCommands migration, policy generation/hash, risk/effect authorization, effective catalog filtering and runtime reauthorization. Do not begin FMG-004 or later tasks.

## FMG-001 closure / FMG-002 claim

FMG-001: DONE / MAIN VERIFIED on merge commit `71d658131342581f14407276bcfe18164a0afa37`; native Verify run `35988856441` SUCCESS.

FMG-002: CLAIMED / ACTIVE on `chatgpt/FMG-002-structured-result-envelope`.

## FMG-002 closure / FMG-003 claim

FMG-002: DONE / MAIN VERIFIED on final merge `dcbc55f7685e91c804ab14500df752a0c6f3be62`; native Verify run `35994263967` SUCCESS.

FMG-003: CLAIMED / ACTIVE on `chatgpt/FMG-003-server-policy`.

## FMG-003 active implementation

FMG-002: DONE / MAIN VERIFIED on merge `dcbc55f7685e91c804ab14500df752a0c6f3be62`; native Verify run `35994263967` SUCCESS.

FMG-003: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-003-server-policy`.

NEXT_EXACT_ACTION: commit/push the exact FMG-003 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, perform scoped review, merge only on green exact-head evidence, verify merged main, then claim the next READY task from the frozen graph.

## FMG-003 closure / FMG-004 claim

FMG-003: DONE / MAIN VERIFIED on merge `8259fd6e0d4d35b6a54498c9d91156b05d2424cc`; merged-main native Verify run `36097504088` SUCCESS on macOS + Windows x64 + Windows ARM64.

FMG-004: CLAIMED / ACTIVE on `chatgpt/FMG-004-toolbudget-cursor`.

NEXT_EXACT_ACTION: implement FMG-004 ToolBudget / Cancellation / Cursor Core only: common caller-lowerable budgets, cooperative cancellation, usage/truncation metadata, and authenticated read cursor core with root/options/generation/expiry binding. Do not begin FMG-005 before FMG-004 MAIN VERIFIED.

## FMG-004 local verification

FMG-004: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-004-toolbudget-cursor`.

Local Windows evidence: 576 assertions PASS; catalog/parity PASS; Release 0 warnings/errors; state contract/diff check PASS. Swift build/runtime wiring is complete, but native macOS execution is environment-blocked on this Windows host.

NEXT_EXACT_ACTION: commit/push the exact FMG-004 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, perform scoped review, merge only on green exact-head evidence, verify merged main, then mark FMG-004 MAIN VERIFIED and claim the next READY task from the frozen dependency graph. Do not start FMG-005 before FMG-004 MAIN VERIFIED.


## FMG-004 active implementation

FMG-004: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING.
NEXT_EXACT_ACTION: commit/push exact candidate and require native GitHub Verify.

## FMG-004 closure / FMG-005 claim

FMG-004: DONE / MAIN VERIFIED on merge `9e65230a672cac533f74d6b007f2f08ce83d8687`; merged-main native Verify run `36114335810` SUCCESS on macOS + Windows x64 + Windows ARM64.

FMG-005: CLAIMED / ACTIVE on `chatgpt/FMG-005-exec-process`.

NEXT_EXACT_ACTION: implement FMG-005 Structured `exec_process` + Environment Authority only: executable + argv, contained cwd, minimal platform environment baseline, locally configured pass-through, policy-checked request overrides, timeout/output budget, structured result, and reuse existing native ProcessRunner. Preserve `run_command` as compatibility/high-risk path. Do not begin FMG-006 before FMG-005 MAIN VERIFIED.


## FMG-005 local verification

FMG-005: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-005-exec-process`.

Local evidence: canonical tool count 20; exec_process contract PASS; Release build 0 warnings/errors; Windows runtime 609 assertions PASS; macOS compile/test wiring complete.
Evidence: `docs/evidence/FMG-005_EXEC_PROCESS_ENVIRONMENT_EVIDENCE.md`.

NEXT_EXACT_ACTION: commit/push exact FMG-005 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, perform scoped review, merge only on green exact-head evidence, verify merged main, then mark FMG-005 MAIN VERIFIED. Do not start FMG-006 first.

## FMG-005 local verification

FMG-005: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-005-exec-process`.

Local evidence: Windows runtime 609 assertions PASS; canonical catalog/parity PASS at 20 tools / `d03c6cd0c4d6582a89e408078e5f4053039f7178d172614256d510f86c137895`; exec-process contract PASS; Release 0 warnings/errors; project-state/diff checks PASS. Native Swift execution is environment-blocked on this Windows host and must be proven by GitHub macOS Verify.

NEXT_EXACT_ACTION: commit/push the exact FMG-005 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, perform scoped review, merge only on green exact-head evidence, verify merged main, then mark FMG-005 DONE / MAIN VERIFIED and claim the next READY task. Do not start FMG-006 before FMG-005 MAIN VERIFIED.
