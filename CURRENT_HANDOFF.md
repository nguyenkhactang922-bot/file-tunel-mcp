# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `chatgpt/FMG-001-canonical-catalog`
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

NEXT_EXACT_ACTION: stage and commit the locally verified FMG-001 candidate, push the exact branch, create/reuse the fork-main PR, require native GitHub Verify on macOS + Windows x64 + Windows ARM64, review/merge only on green exact-head evidence, then verify fork main and claim FMG-002. Do not begin FMG-002 before FMG-001 MAIN VERIFIED.
