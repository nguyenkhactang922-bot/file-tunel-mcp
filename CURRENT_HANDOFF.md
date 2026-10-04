# CURRENT HANDOFF

## Current status

Project: FileMCP
PROJECT_ROOT: `D:\Tools\FileMCP`
Branch: `chatgpt/FMUX-013-recovery`
Git SHA source of truth: run git rev-parse HEAD.
Expected worktree at handoff: FMUX-013 Recovery ACTIVE / CLAIMED on `chatgpt/FMUX-013-recovery`, based exactly on verified main `dad103c569cbfc6d68b343445287152013c6f29e`; FMUX-012 state-sync is MAIN VERIFIED via PR #51 and merged-main Verify `37186288521`; runtime PID `17860` remains correct and must not be restarted.

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

Branch: `chatgpt/FMUX-014-artifact-batch`.

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

## FMG-005 closure / FMG-006 claim

FMG-005: DONE / MAIN VERIFIED. Final candidate `e7c3e1764a3bd229ac1060f628a19c5049d256cf` merged by PR #8 as main `ec4f762c811be658cf9d5a82e0300ee7e79ef2ba`; merged-main Verify `36121843677` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows runtime 611 assertions and Release build PASS.

FMG-006: CLAIMED / ACTIVE on `chatgpt/FMG-006-file-version-source-state`.

NEXT_EXACT_ACTION: implement FMG-006 Strong File Version + SourceStateRef only: authenticated/opaque strong file version identity; read/stat exposure; versioned SourceStateRef provider; Git-backed repository fingerprint components; narrow relevant-file dependency support; negative tests for same size/mtime content changes, replacement object, dirty tracked/relevant untracked changes and excluded unrelated changes. Do not begin FMG-007 before FMG-006 MAIN VERIFIED.

## FMG-006 local verification

FMG-006: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-006-file-version-source-state`.

Local evidence: catalog/parity PASS at 20 tools / `d39a11012ad61a6d35ae472c5776d0a8488ded080212f72168505e41e11619c3`; FMG-006 file-version/source-state contract PASS; Windows runtime 627 assertions PASS; Release build 0 warnings/errors; diff/state checks PASS. macOS native code/tests are wired but local execution is environment-blocked because this Windows host has no `swiftc`.

NEXT_EXACT_ACTION: commit/push the exact FMG-006 candidate, require native GitHub Verify on macOS + Windows x64 + Windows ARM64, fix only the exact failing stage if any, perform scoped security/privacy review, merge only exact green head, verify merged main, mark FMG-006 DONE / MAIN VERIFIED, then claim FMG-007.

## FMG-006 closure / FMG-007 claim

FMG-006: DONE / MAIN VERIFIED. Primary PR #9 merged strong file version + SourceStateRef; test-only PR #10 hardened Base64URL tamper verification. Final main `4ce571a8fd22448701cc6ad135a828c2328d12fe`; final merged-main Verify `36164398847` SUCCESS on macOS + Windows x64 + Windows ARM64; local Windows runtime 627 assertions PASS.

FMG-007: CLAIMED / ACTIVE on `chatgpt/FMG-007-mutation-guard`.

NEXT_EXACT_ACTION: implement AuthorizedPathSnapshot / Mutation Guard only: stable native root/parent/target identity, new-target parent + expected leaf absence, final no-follow/reparse-safe recheck, equivalent Windows/macOS semantics, and adversarial path-swap tests. Do not begin FMG-008 before FMG-007 MAIN VERIFIED.

## FMG-007 local verification

FMG-007: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-007-mutation-guard`.

Local evidence: Windows runtime 637 assertions PASS including `windows-mutation-guard: ok`; Mutation Guard contract PASS; canonical catalog/parity and FMG-006 prerequisite contract PASS; Release build 0 warnings/errors; state/diff/shell syntax gates PASS. Native Swift implementation/test wiring is complete but requires GitHub macOS Verify because this Windows host has no `swiftc`.

NEXT_EXACT_ACTION: commit/push the exact FMG-007 candidate, require native GitHub Verify on macOS + Windows x64 + Windows ARM64, fix only the exact failing stage if any, perform scoped security review, merge only exact green head, verify merged main, mark FMG-007 DONE / MAIN VERIFIED, then claim FMG-008.

## FMG-007 closure / FMG-008 claim

FMG-007: DONE / MAIN VERIFIED. Candidate `2319488761c845df7be5010dca0283485a41a8e9` merged by PR #11 as main `ad78b0f75564728c7a4aa5dae218d4e79d697569`; merged-main Verify `36167404567` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows runtime 637 assertions and Release build PASS.

FMG-008: CLAIMED / ACTIVE on `chatgpt/FMG-008-existing-mutation-hardening`.

NEXT_EXACT_ACTION: harden existing write/delete mutations only: expected-version support, Mutation Guard immediately before commit/delete, commit-time policy reauthorization, cancellation-before-commit safety, and required dry-run semantics. Preserve root/link/backward-compatibility contracts. Do not begin FMG-009 before FMG-008 MAIN VERIFIED.

## FMG-008 closure / FMG-009 claim

FMG-008: DONE / MAIN VERIFIED. Final candidate `35ef237a0f4d32f0940491b9163a0dcbea7e6c61` merged by PR #12 as main `8a58a223814505518e581ebe79856846555cb4b4`; merged-main Verify `36212103370` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows core 655 assertions and Release build PASS. Evidence: `docs/evidence/FMG-008_EXISTING_MUTATION_HARDENING_EVIDENCE.md`.

FMG-009: CLAIMED / ACTIVE on `chatgpt/FMG-009-apply-edits`.
Branch: `chatgpt/FMUX-014-artifact-batch`

NEXT_EXACT_ACTION: implement FMG-009 Atomic Versioned `apply_edits` only: canonical range-edit primitive, expected strong version, explicit coordinate system, non-overlap validation, BOM/newline preservation, dry-run, staging, final version/Mutation Guard/policy/cancellation rechecks, atomic publish, and adversarial/fault-injection coverage. Do not begin FMG-010 before FMG-009 MAIN VERIFIED.

## FMG-009 local verification

FMG-009: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-009-apply-edits`.

Local evidence: canonical catalog/parity PASS at 21 tools / `a6d3914363267b165af5896b0b6456a71155faaafd4911a957818e1a1fd26b91`; apply-edits and prerequisite contracts PASS; Windows runtime 682 assertions PASS including `windows-apply-edits: ok`; Release build 0 warnings/errors; diff/state/shell-syntax gates PASS. macOS native implementation/test harness is wired but requires GitHub macOS Verify.

NEXT_EXACT_ACTION: commit/push exact FMG-009 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, fix only exact failing stage, perform scoped atomicity/security review, merge only exact green head, verify merged main, mark FMG-009 DONE / MAIN VERIFIED, then claim FMG-010.

## FMG-009 closure / FMG-010 claim

FMG-009: DONE / MAIN VERIFIED. Final candidate `d7d5e5d45f79fc27f35bd0758ba6e1675bda6b92` merged by PR #13 as main `e054aee3d18196881fbb8033037441959b255b73`; merged-main Verify `36225126052` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows runtime 682 assertions and Release build PASS.

FMG-010: CLAIMED / ACTIVE on `chatgpt/FMG-011-metadata-evidence`.

NEXT_EXACT_ACTION: implement Project Context Provenance / Digest only: bounded instruction discovery; deterministic ordered provenance/scope; schema+digest; range continuation; no-authority marker; existing skill integration without duplicate recipe engine; adversarial tests for oversized instructions, nested conflicts, malicious authority requests, stale range/version, path escape and cancellation. Do not begin FMG-011 before FMG-010 MAIN VERIFIED.


## FMG-010 local verification

FMG-010: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on chatgpt/FMG-011-metadata-evidence.

Local evidence: catalog/parity + project-context/prerequisite contracts PASS at catalog 1.5.0, 22 tools, hash f717cf599faf112964a981e516de0898d4ce140c3f6daca15d732f13216a53aa; Windows Release build 0 warnings/errors; runtime 715 assertions PASS including windows-project-context: ok; isolated x64 package/app smoke PASS; ZIP SHA-256 9ABA9428D8CD22F0FE29F30D3D3D05FAA3327D512DA95DDAC183EE28DE31ECFB; macOS implementation/test harness/compile wiring present and shell syntax PASS.

NEXT_EXACT_ACTION: commit/push exact FMG-010 candidate, require native GitHub Verify macOS + Windows x64 + Windows ARM64, fix only exact failing stage, perform scoped provenance/authority review, merge only exact green head, verify merged main, mark FMG-010 DONE / MAIN VERIFIED, then claim FMG-011.

## FMG-010 closure / FMG-011 claim

FMG-010: DONE / MAIN VERIFIED. Final main `9340377f42abfe97bc708d0683f77dea26e86b50`; merged-main Verify `36235453791` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows runtime 715 assertions and Release build PASS.

FMG-011: CLAIMED / ACTIVE on `chatgpt/FMG-011-metadata-evidence`.

NEXT_EXACT_ACTION: implement FMG-011 Metadata-Only Evidence / Freshness only: evidence identity/state, SourceStateRef linkage, policy/catalog generation, passed/failed/not-run/unknown/stale/blocked/N/A state machine, retention/quota/cleanup, restart handling, telemetry separation, and adversarial tests for stale source/policy/catalog/storage failure/crash/secrets/retention. Do not begin FMG-012 before FMG-011 MAIN VERIFIED.


FMG-011 design freeze complete:
- docs/design/FMG-011_METADATA_EVIDENCE_FRESHNESS_FROZEN.md
- docs/design/FMG-011_INDEPENDENT_REVIEW.md
- docs/design/FMG-011_DECISION_MATRIX.md
- tasks/FMG-011_TASK_GRAPH.md
- NEXT_EXACT_ACTION: implement FMG-011-A shared evidence contracts/IDs/states only; do not begin store integration before contracts pass.


## FMG-011 local verification

FMG-011: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-011-metadata-evidence`.

Local evidence:
- canonical catalog/parity PASS at 23 tools / `8c5365afc0ae89e417c144ba77bbdc6a068e3fdbeefd92d674a62e1647c69d91`;
- exec_process/source-state/project-context/evidence contracts PASS;
- Windows Release build PASS, 0 warnings/errors;
- Windows runtime PASS, 750 assertions including `windows-evidence-freshness: ok`;
- macOS EvidenceStore/server/adversarial harness and build/CI wiring present; Git Bash syntax PASS;
- scoped privacy/security review PASS.

Evidence: `docs/evidence/FMG-011_METADATA_EVIDENCE_CANDIDATE_EVIDENCE.md`.

Historical FMG-011 next action (completed): candidate verification/merge/main verification completed before FMG-012 claim.

## FMG-011 closure / FMG-012 claim

FMG-011: DONE / MAIN VERIFIED. Candidate `54270a86e03ebcdb86d01954d791065d5abdf1bc` merged by PR #17 as main `ddc8b27839469dcc5a6ff36bb531cf0b3dda87aa`; merged-main Verify `36296831946` SUCCESS on macOS + Windows x64 + Windows ARM64.

FMG-012: CLAIMED / ACTIVE on `chatgpt/FMG-012-cross-platform-gate`.

NEXT_EXACT_ACTION: execute the foundation cross-platform adversarial contract gate only: catalog/schema parity, all Phase A negative suites, Windows Release/runtime/package proof, then native macOS/x64/ARM64 Verify. Fix only exact defects discovered; do not start FMG-013 before FMG-012 MAIN VERIFIED.

## FMG-012 local verification

FMG-012: ACTIVE / LOCAL VERIFIED / FINAL-HEAD NATIVE CI PENDING on `chatgpt/FMG-012-cross-platform-gate`.

Local evidence: all Phase A contract/adversarial scripts PASS; Windows runtime 750 assertions PASS; Release build 0 warnings/errors; x64 + ARM64 package builds/static integrity PASS. Local GUI smoke is environment-blocked because the live FileMCP singleton is the MCP bridge; claim-head native Verify `36297166252` SUCCESS on macOS + Windows x64 + Windows ARM64.

NEXT_EXACT_ACTION: commit/push exact FMG-012 evidence candidate, require native Verify on the final exact head, perform scoped gate review, merge only green exact head, verify merged main, mark FMG-012 DONE / MAIN VERIFIED, then claim FMG-013.

## FMG-012 closure / FMG-013 claim

FMG-012: DONE / MAIN VERIFIED. Final candidate `364b7945f2885e5ec39ee1ad1da9e8a08618735c` merged by PR #18 as main `d3a3670f6fb60ab75d8471b3d982c811337fa951`; merged-main Verify `36297870457` SUCCESS on macOS + Windows x64 + Windows ARM64; local merged-main Windows runtime 750 assertions and Release build PASS.

FMG-013: CLAIMED / ACTIVE on `chatgpt/FMG-013-full-regression-live-proof`.

NEXT_EXACT_ACTION: execute Foundation Full Regression + Live MCP Proof only: full regression contracts/runtime/package/native verification plus live MCP catalog/tool/correlation proof against the current connector. Fix only concrete failing stages. FMG-013 is foundation MAIN VERIFIED, not complete-upgrade completion.

## FMG-013 live proof blocker

FMG-013: BLOCKED / CHATGPT CONNECTOR DISCOVERY STALE on `chatgpt/FMG-013-full-regression-live-proof`.

Completed evidence: source/full regression/native Verify PASS; claim-head Verify `36298103299` SUCCESS on macOS + Windows x64 + Windows ARM64. Current source catalog is 23 tools / version 1.6.0.

Live blocker: current FileMCP PID 11960 runs old binary `D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe` (SHA-256 `7689540f1ff4cc080064eb1ccaf33a5b4a8b1a736b2f10b52988505e6e7c2807`) and this ChatGPT connector exposes only 19 tools.

Ready replacement: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe` (SHA-256 `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`).

NEXT_EXACT_ACTION: after normal FileMCP desktop restart into the ready build and connector reconnection, resume FMG-013 at LIVE MCP PROOF ONLY; verify 23-tool catalog/current hash + live tool/correlation behavior. Do not rerun completed regression and do not claim FMG-014 before FMG-013 FOUNDATION MAIN VERIFIED.



## FMG-013 post-restart checkpoint - 2026-09-28

Desktop/runtime replacement is now verified: PID `10688` is running `dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe` with SHA-256 `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`.

The remaining blocker is ChatGPT connector discovery/cache: this chat still exposes only 19 FileMCP tools.

NEXT_EXACT_ACTION: do not rerun regression. Reconnect/rediscover the FileMCP connector so the chat advertises 23 tools; then run LIVE MCP PROOF ONLY (catalog version/hash + live tool/correlation behavior), exact-head native Verify, review, merge, merged-main verification, then claim FMG-014.


### FMG-013 live correlation sub-proof - 2026-09-28

Live correlation on the active ready build is PASS: existing `chat_instance_id` resumed with `resumed=true`, and a bound read using the same `_filemcp_chat` handle succeeded. Remaining gate is only ChatGPT connector rediscovery from 19 to 23 tools plus catalog version/hash/new-tool live parity.


## FMG-013 reconnect verification - 2026-09-28

Fresh reconnect verification PASSed for runtime/tunnel/correlation: ready binary PID `10688`, tunnel health `live`, readiness `ready`, main-channel probe `ok`, control-plane forwarding to local MCP returns service status `200`, and logical chat correlation resume + bound read PASS.

The current ChatGPT registry is still 19 tools. NEXT_EXACT_ACTION remains: refresh/rediscover the connector until 23 canonical tools are advertised, then run only the remaining live catalog/hash/new-tool parity proof. Do not rerun completed regression. FMG-014 remains BLOCKED.


### FMG-013 rediscovery diagnosis - 2026-09-28

19/23 is not policy filtering: active profile is `legacy-command-compatible` and that profile allows all tools. Tunnel is healthy and live `tools/call` traffic reaches the new runtime, but no `tools/list` discovery request is visible after the new runtime startup. Remaining gate is external connector/control-plane rediscovery; do not run exact-head Verify or merge until the live registry actually advertises 23 tools and catalog/hash parity is proven.


### FMG-013 targeted connector refresh checkpoint - 2026-09-28T15:49:09+07:00

Restarted only the D-workspace tunnel-client while preserving FileMCP desktop/server. D tunnel recovered healthy/ready with new PID 2552, but this ChatGPT session still exposes 19 FileMCP tools. NEXT_EXACT_ACTION remains external ChatGPT connector rediscovery/reload to 23 tools, then run LIVE MCP PROOF ONLY for exec_process/apply_edits/project_context/evidence_get + catalog/hash/correlation. FMG-014 remains BLOCKED.


## FMG-013 live 23-tool proof PASS - 2026-09-28T15:59:05+07:00

The refreshed FileMCP connector now exposes the canonical 23 tools. Live `exec_process`, `project_context`, versioned atomic `apply_edits`, `evidence_get` negative-path dispatch, exact catalog version/hash parity, and correlation resume/bound read are verified. FMG-013 is LIVE VERIFIED / EXACT-HEAD NATIVE CI PENDING.

NEXT_EXACT_ACTION: commit/push the exact FMG-013 live-evidence candidate, require native Verify on macOS + Windows x64 + Windows ARM64 for that exact head, perform scoped review, open/merge PR only on green exact-head evidence, verify merged main, then mark FMG-013 DONE / FOUNDATION MAIN VERIFIED and claim FMG-014. Do not rerun completed foundation regression.
## FMUX product-experience track

Design gate: PASS / FROZEN on 2026-09-28.
Authorities:
- docs/adr/0007-product-ui-ux-architecture-and-fmux-track.md
- docs/audit/FMUX_INDEPENDENT_MULTI_ROUND_UI_UX_AUDIT_2026-09-28.md
- docs/audit/FMUX_FINAL_REPAIR_REAUDIT_2026-09-28.md
- docs/design/FMUX_PRODUCT_EXPERIENCE_ARCHITECTURE_V1.md
- docs/design/FMUX_DESIGN_SYSTEM_AND_COMPONENT_SPEC_V1.md
- docs/design/FMUX_INTERACTION_STATE_AND_FMG_MAPPING_V1.md
- docs/design/FMUX_DEPENDENCY_GRAPH_V1.md
- docs/design/FMUX_DECISION_MATRIX_V1.md
- tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md

FMUX-001: ACTIVE / LOCAL + NATIVE VERIFIED / FINAL-HEAD CI PENDING on branch `chatgpt/FMUX-001-presentation-foundation`.
Evidence: `docs/evidence/FMUX-001_PRESENTATION_FOUNDATION_EVIDENCE.md`.
NEXT_EXACT_ACTION: finish exact-head native verification, review/merge FMUX-001, then claim FMUX-002. FMG-026 scope remains unchanged.

## FMUX-001 closure / FMUX-002 claim

FMUX-001: DONE / MAIN VERIFIED.
PR: #20.
Merge main: `ee85ba494f36be6d15757fe338588cc92651518a`.
Merged-main Verify: run `36400920401` SUCCESS on Windows x64 / Windows ARM64 / macOS.
Local proof: project-state contract PASS; FMUX presentation contract PASS; Windows Release build 0 warnings / 0 errors; Windows runtime 750 assertions PASS.

FMUX-002: ACTIVE / LOCAL + NATIVE VERIFIED on `chatgpt/FMUX-002-app-shell`.
Candidate head before main-sync merge: `94e93fb82a58102caff2e0f5bc615e46e7cd4706`.
Exact-head native Verify: run `36404297279` SUCCESS on Windows x64 / Windows ARM64 / macOS.
Scope: App Shell + Navigation only: labeled sidebar, content host, workspace/global health context, compact mode, persistent Settings placement, Windows/macOS semantic parity. Legacy pages remain hosted during incremental migration. FMUX-003 remains BLOCKED until FMUX-002 MAIN VERIFIED.
Evidence: `docs/evidence/FMUX-002_APP_SHELL_NAVIGATION_EVIDENCE.md`.

NEXT_EXACT_ACTION: finish main-sync conflict resolution, rerun only state/shell/build gates affected by the merge, push final exact head, require native Verify on that head, review, merge, merged-main verification, then claim FMUX-003.

## FMUX-002 main-sync verification

FMUX-002 final merged candidate is LOCAL VERIFIED after syncing latest main/FM G-013.
Local post-sync proof: project-state PASS; FMUX shell contract PASS; Windows Release 0 warnings/errors; Windows runtime 750 assertions PASS.
NEXT_EXACT_ACTION: push exact final head, require native Verify on Windows x64 / Windows ARM64 / macOS, review, merge, merged-main verification, then mark FMUX-002 MAIN VERIFIED and claim FMUX-003.

## FMUX-002 closure / FMUX-003 claim

FMUX-002: DONE / MAIN VERIFIED.
PR: #22.
Final candidate head: `727ad27048146c129ac6f9dd81e1ebd452af15f1`.
Final exact-head Verify: run `36407890996` SUCCESS on Windows x64 / Windows ARM64 / macOS.
Merge main: `5bf90ad2e675917368657c5ec8c40f48ad9ead23`.
Merged-main Verify: run `36408283195` SUCCESS on Windows x64 / Windows ARM64 / macOS.
Local proof: project-state contract PASS; FMUX app-shell contract PASS; Windows Release build 0 warnings/errors; Windows runtime 750 assertions PASS.

FMUX-003: CLAIMED / ACTIVE on `chatgpt/FMUX-003-status-feedback`.
Scope: Canonical Status / Feedback Components only: StatusBadge, InlineNotice, EmptyState, PageHeader, loading/refresh/error/stale patterns, notification policy. Do not begin FMUX-004 before FMUX-003 MAIN VERIFIED.

NEXT_EXACT_ACTION: implement FMUX-003 only, then local contracts/build/runtime, exact-head native Verify, review, merge, merged-main verification.

## FMUX-003 local verification

FMUX-003: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-003-status-feedback`.
Local proof: feedback-component contract PASS; Windows Release 0 warnings/errors; Windows runtime 750 assertions PASS; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-003_STATUS_FEEDBACK_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, scoped review, merge, merged-main verification, then claim FMUX-004.

## FMG-013 closure / FMG-014 claim - 2026-09-28

FMG-013: DONE / FOUNDATION MAIN VERIFIED.
- Final candidate head: `db34185e4989953b54a504c9e03a1b5b7253ba3d`.
- PR #21 merged to fork `main`.
- Merge main: `0158bc5a7b94df7531d9d19c183c9b1c2f8af6c2`.
- PR Verify run `36402363852`: SUCCESS after rerunning only the transient Windows ARM64 hosted-runner `setup-dotnet` failure; macOS / Windows x64 / Windows ARM64 all SUCCESS on the exact candidate.
- Merged-main Verify run `36403091233`: SUCCESS on macOS / Windows x64 / Windows ARM64.
- Live MCP proof: canonical 23 tools, catalog version `1.6.0`, catalog SHA-256 `98ba484931717cc7ee8efbce83941afc33aa5fbaddb6b667882100a423bfacee`; live exec_process / project_context / apply_edits / evidence_get dispatch + logical-chat correlation PASS.

FMG-014: CLAIMED / ACTIVE on `chatgpt/FMG-014-artifact-contentref-store`.

NEXT_EXACT_ACTION: implement FMG-014 Ephemeral Artifact / ContentRef Store only: local content-addressed blob store outside the repository, metadata index, authenticated ContentRef bound to installation/workspace/content-class/expiry, quotas + TTL GC, current-user-only storage permissions, stream read/write, and explicit TOOL_OUTPUT / PTY_OUTPUT / CHECKPOINT / QUARANTINE classes. Add tamper, cross-workspace replay, metadata/blob mismatch, corruption, disk-full, concurrent put/delete, expired lease and permission-regression tests. Do not begin FMG-015 before FMG-014 MAIN VERIFIED.


## FMG-014 local verification checkpoint - 2026-09-28

State: ACTIVE / LOCAL VERIFIED / CROSS-PLATFORM CI PENDING.
Branch: `chatgpt/FMUX-014-artifact-batch`.
Evidence: `docs/evidence/FMG-014_ARTIFACT_CONTENTREF_STORE_EVIDENCE.md`.

Implemented:
- content-addressed artifact blob store + independent metadata index;
- authenticated HMAC-SHA256 `cr1` ContentRef;
- installation/workspace/blob/class/ref-id/expiry/lease binding;
- TOOL_OUTPUT / PTY_OUTPUT / CHECKPOINT / QUARANTINE classes;
- quota + TTL GC;
- Windows current-user ACL and macOS owner-only POSIX permissions;
- streaming read/write;
- negative coverage for tamper, cross-workspace, metadata mismatch, corruption, disk-full rollback, quota partial-write refusal, lease expiry and concurrent dedupe/delete.

Local Windows evidence:
- artifact contract PASS;
- Release build PASS, 0 warnings / 0 errors;
- full Windows integration PASS, 776 assertions.

NEXT_EXACT_ACTION: commit this local candidate, sync latest fork/main (currently FMUX track may have advanced), push exact synchronized head, require native Verify on macOS + Windows x64 + Windows ARM64, review/PR/merge, merged-main Verify, then FMG-014 MAIN VERIFIED -> claim FMG-015. Do not begin FMG-015 early.


## FMG-014 post-main-sync verification

Merged latest `fork/main=7e8590a` into the FMG-014 working tree while preserving FMUX-003 and FMG-014 authority.
Local post-sync proof: project-state PASS; FMUX shell PASS; FMUX feedback PASS; FMG-014 artifact contract PASS; Windows Release build 0 warnings/errors; Windows integration 776 assertions PASS.
NEXT_EXACT_ACTION: finalize the merge commit, push the exact FMG-014 head, require native Verify on macOS + Windows x64 + Windows ARM64, then scoped review -> PR/merge -> merged-main Verify -> FMG-014 MAIN VERIFIED -> claim FMG-015.


## FMG-014 exact-head native verification

Candidate `c7f921e4036a7ac4be9b350b215f055e706ddd60` is NATIVE VERIFIED.
Verify run `36413985720`: SUCCESS on macOS, Windows x64 and native Windows ARM64.
Final macOS integration proof includes `swift-artifact-contentref-store: ok`; Windows integration includes `windows-artifact-contentref-store: ok` within 776 assertions.
State: ACTIVE / EXACT-HEAD NATIVE VERIFIED / REVIEW PENDING.
NEXT_EXACT_ACTION: scoped review -> PR/merge -> merged-main Verify -> FMG-014 DONE / MAIN VERIFIED -> claim FMG-015. FMG-015 remains BLOCKED until merged-main verification completes.
## FMUX-004 local verification

FMUX-004: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-004-home`.
Local proof: Home contract PASS; Windows Release 0 warnings/errors; Windows runtime 750 assertions PASS; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-004_HOME_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim FMUX-005.


## FMG-014 final synchronized code verification

Code candidate: `15babd9f9eee540fef2f008b6ea6ce6340b33109`.
Native Verify run: `36416421696` SUCCESS on macOS / Windows x64 / native Windows ARM64.
Post-main-sync local proof: project-state + FMUX presentation/home + FMG-014 contract PASS; Windows Release 0 warnings/errors; Windows integration 776 assertions PASS.
Security hardening: ContentRef base64url decoder now rejects non-canonical encodings on Windows and macOS before HMAC acceptance.
NEXT_EXACT_ACTION: commit/push this evidence-only closure head -> exact-head native Verify -> scoped review -> PR/merge -> merged-main Verify -> FMG-014 DONE / MAIN VERIFIED -> claim FMG-015.


## FMG-014 closure / FMG-015 claim - 2026-09-28

FMG-014: DONE / MAIN VERIFIED.
- Final evidence head: `d4d2c75ce91efd1b1b3f5f87d58e86f52f6ced53`.
- Exact-head push Verify run `36416843308`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #26 Verify run `36417272966`: SUCCESS on all three native lanes.
- PR #26 merged to fork `main` as `d7669ed0d60c51eb1cfb12813abc8f34d3d3ff0e`.
- Merged-main Verify run `36417632075`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Content-addressed blob store, authenticated canonical ContentRef, installation/workspace/class/expiry/lease binding, quota/TTL GC, current-user permissions, streaming I/O and negative/adversarial coverage are MAIN VERIFIED.

FMG-015: CLAIMED / ACTIVE on `chatgpt/FMG-015-batch-read-stat`.

NEXT_EXACT_ACTION: implement FMG-015 Batch Read / Stat only: `batch_stat` + `batch_read`, per-entry SafePathResolver/version authorization, aggregate ToolBudget, deterministic per-entry states, cancellation with explicit partial result, version token per eligible file, and optional FMG-014 ContentRef for oversized items. Cover mixed valid/escape paths, duplicates, huge lists, mid-batch cancellation, file mutation during read and artifact quota exhaustion. Do not begin FMG-016 before FMG-015 MAIN VERIFIED.


## FMG-014 closure / FMG-015 claim

FMG-014: DONE / MAIN VERIFIED.
PR #26 head `d4d2c75ce91efd1b1b3f5f87d58e86f52f6ced53`; merge main `d7669ed0d60c51eb1cfb12813abc8f34d3d3ff0e`; PR Verify `36417272966` SUCCESS; merged-main Verify `36417632075` SUCCESS on macOS / Windows x64 / native Windows ARM64.

FMG-015: CLAIMED / ACTIVE on `chatgpt/FMG-015-batch-read-stat`.
NEXT_EXACT_ACTION: implement batch_stat + batch_read with per-entry resolver/version authority, one aggregate ToolBudget, deterministic per-entry results, explicit cancellation/partial state, and optional Artifact ContentRef spill for oversized content; then negative tests -> local verify -> exact-head native Verify -> review -> PR/merge -> merged-main Verify. FMG-016 remains BLOCKED until FMG-015 MAIN VERIFIED.

## FMG-015 local verification checkpoint - 2026-09-28

State: LOCAL VERIFIED / MAIN SYNC + NATIVE CI PENDING.
Catalog: 1.7.0 / 25 canonical tools / SHA-256 `70faaa4cb370589191084ef76dfbcb502d810f5c8c658f0e1da80e9ec194a8c7`.
Local FMG-015 isolation: PASS (20 assertions); Release build: PASS 0 warnings/errors; batch contract + catalog/parity: PASS.
Scoped review hardening: ContentRef spill is bound to strong-version snapshot bytes and nested batch request arguments fail closed.
Evidence: `docs/evidence/FMG-015_BATCH_READ_STAT_EVIDENCE.md`.

NEXT_EXACT_ACTION: commit this local-verified FMG-015 candidate, merge latest fork/main without dropping concurrent FMUX work, rerun affected gates, push exact synchronized head, require native Verify macOS + Windows x64 + Windows ARM64, review/PR/merge, merged-main Verify, then mark FMG-015 DONE / MAIN VERIFIED and claim FMG-016.
## FMUX-004 closure / FMUX-005 post-main-sync

FMUX-004: DONE / MAIN VERIFIED. PR #24; merge `e4e243ab1526d8cb67e7b2304b649227726e02f5`; merged-main Verify `36414061842` SUCCESS.

FMUX-005: ACTIVE / POST-MAIN-SYNC LOCAL VERIFY REQUIRED on `chatgpt/FMUX-005-workspaces`.
Pre-sync exact-head Verify `36417451616` SUCCESS on Windows x64 / Windows ARM64 / macOS for `8ddce5383d6b0133dafc163272153c64348c231c`.
Latest `fork/main` was merged due PR mergeability; only state/handoff conflicted and latest main authority was preserved.
NEXT_EXACT_ACTION: rerun only post-sync state/Workspaces/build/runtime gates, push final exact head, native Verify, review, merge, merged-main verification, then claim FMUX-006.

## FMUX-005 closure / FMUX-006 local verification

FMUX-005: DONE / MAIN VERIFIED. PR #25; merge `d13ec1a1b135ae2706158accf007000f1aa71510`; merged-main Verify `36418561277` SUCCESS.

FMUX-006: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-006-connections`.
Local proof: Connections contract PASS; Windows Release 0 warnings/errors; Windows runtime 776 assertions PASS; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-006_CONNECTIONS_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim FMUX-007.

## FMUX-006 closure / FMUX-007 local verification

FMUX-006: DONE / MAIN VERIFIED. PR #27; merge `c595af516ca31be3bb20ab34316fa5ad92fe02be`; merged-main Verify `36420010186` SUCCESS.

FMUX-007: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-007-settings-policy`.
Local proof: Settings/Policy contract PASS; Windows Release 0 warnings/errors; Windows runtime 776 assertions PASS; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-007_SETTINGS_POLICY_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim FMUX-008.

## FMUX-007 closure / FMUX-008 local verification

FMUX-007: DONE / MAIN VERIFIED. PR #28; merge `1e5b1c94bd747a0576b7b2871ac78d10b649930a`; merged-main Verify `36421881472` SUCCESS after targeted macOS rerun.

FMUX-008: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-008-structured-activity`.
Local proof: Structured Activity contract PASS; Windows Release 0 warnings/errors; Windows runtime 776 assertions PASS on targeted rerun; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-008_STRUCTURED_ACTIVITY_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim FMUX-009.

## FMUX-008 closure / FMUX-009 local verification

FMUX-008: DONE / MAIN VERIFIED. PR #30; merge `4c83cc17fc70433674fb92643ffa22ff17f4da4f`; merged-main Verify `36423928925` SUCCESS.

FMUX-009: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-009-changes`.
Local proof: Changes contract PASS; Windows Release 0 warnings/errors; Windows runtime 776 assertions PASS; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-009_CHANGES_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim FMUX-010.

## FMG-015 synchronized native-CI checkpoint

State: SYNCHRONIZED LOCAL VERIFIED / NATIVE CI PENDING.
Main sync: behind fork/main = 0 at checkpoint.
Affected gates after merge: FMG-015 batch contract PASS; FMUX-005..009 contracts PASS; Windows Release build PASS 0 warnings/errors; FMG-015 isolated integration PASS 20 assertions.
NEXT_EXACT_ACTION: push exact synchronized FMG-015 head, require native Verify macOS + Windows x64 + Windows ARM64, scoped review, PR/merge, merged-main verification, then mark FMG-015 DONE / MAIN VERIFIED and claim FMG-016.


## FMG-015 native Verify attempt 1 remediation

State: FIX VERIFIED LOCAL / RESYNC + NATIVE CI PENDING.
Run `36440733440`: ARM64 SUCCESS; Windows x64 exposed deterministic strong-read mutation-detection weakness; macOS batch semantics passed but the harness exposed index-based catalog assertions. Both root causes are fixed without weakening acceptance: cross-platform final content-hash re-verification + after-first-chunk adversarial mutation, and name-based macOS tool assertions.
Local post-fix: full Windows 796 assertions PASS; FMG-015 isolation 20 assertions PASS; batch/file-version/catalog/parity contracts PASS.
NEXT_EXACT_ACTION: commit remediation, synchronize latest fork/main, push exact head, require native Verify all three lanes, then review/PR/merge/merged-main Verify. FMG-016 remains BLOCKED.

## FMG-015 native Verify attempt 2

State: WINDOWS X64 + ARM64 VERIFIED / MACOS TEST-HARNESS FIX PENDING EXACT-HEAD VERIFY.
Run `36443414494`: Windows x64 SUCCESS; Windows ARM64 SUCCESS; macOS product typecheck PASS, integration failed only because the new native mutation test block was duplicated. Duplicate removed locally; exactly one `swift-file-version-mid-read-mutation: ok` marker remains and FMG-015 contract PASS.
NEXT_EXACT_ACTION: commit/push the macOS test-only deduplication, require exact-head native Verify, then scoped review -> PR/merge -> merged-main Verify. FMG-016 remains BLOCKED until FMG-015 MAIN VERIFIED.
## FMUX-009 closure / FMUX-010 local verification

FMUX-009: DONE / MAIN VERIFIED. PR #31; merge `271c3d402d2aa6799efd6edc08d746c2823fe517`; merged-main Verify `36440105236` SUCCESS.

FMUX-010: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-010-evidence`.
Local proof: Evidence contract PASS; Windows Release 0 warnings/errors; Windows runtime 776 assertions PASS on rerun; macOS build-script syntax PASS. Initial runtime attempt hit the previously observed non-deterministic FMG-014 ContentRef tamper assertion and passed unchanged on rerun.
Evidence: `docs/evidence/FMUX-010_EVIDENCE_UX_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push exact candidate, native Verify, review, merge, merged-main verification, then claim next dependency-ready FMUX task.

## FMG-015 post-FMUX-010 synchronized closure checkpoint

State: SYNCHRONIZED LOCAL VERIFIED / FINAL EXACT-HEAD NATIVE VERIFY PENDING.
Run `36444058795` on pre-sync head `c341d6d`: SUCCESS on macOS / Windows x64 / Windows ARM64.
Latest main `61359a9` (FMUX-010) merged cleanly except governance state; FMG-015 + FMUX-010 contracts PASS, Windows Release 0 warnings/errors, full Windows regression 796 assertions PASS.
NEXT_EXACT_ACTION: push the synchronized FMG-015 head, require native Verify all three lanes, then scoped review -> PR/merge -> merged-main Verify. FMG-016 remains BLOCKED until FMG-015 MAIN VERIFIED.

## FMG-015 final exact-head verification / review

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.
Head `2ff1442`; Verify run `36445207427`: SUCCESS on macOS / Windows x64 / Windows ARM64. Scoped review PASS: read-only authority, per-entry path/version checks, aggregate budget, snapshot-bound ContentRef spill, no evidence/telemetry blob coupling, no temp/debug artifacts.
NEXT_EXACT_ACTION: commit/push evidence-only closure head, require native Verify all three lanes, then PR/merge -> merged-main Verify -> FMG-015 DONE / MAIN VERIFIED -> claim FMG-016.

## FMUX-014 local verification checkpoint

FMUX-014: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMUX-014-artifact-batch`.
Local proof: Artifact/Batch contract PASS; Windows Release 0 warnings/errors; Windows runtime 796 assertions PASS on unchanged rerun after the known nondeterministic FMG-014 tamper assertion; macOS build-script syntax PASS.
Evidence: `docs/evidence/FMUX-014_ARTIFACT_BATCH_UX_EVIDENCE.md`.
NEXT_EXACT_ACTION: inspect latest `fork/main` + remote FMUX-014 branch before any push/PR; sync if needed, rerun only affected gates, then exact-head native Verify -> review -> merge -> merged-main Verify -> FMUX-014 MAIN VERIFIED -> next dependency-ready FMUX task.

## FMUX-014 Windows x64 gate stabilization

Exact-head `7e83341cc526490762cc470d011d56ad13241f4e` passed macOS and Windows ARM64, but Windows x64 repeatedly hit the pre-existing FMG-014 tamper-fixture ambiguity (`Malformed ContentRef` before HMAC assertion).
Only the failing test fixture was hardened: tamper now changes the first signature-segment character, keeping base64url canonical while still requiring HMAC authentication rejection.
Local failed-stage rerun: Windows runtime PASS, 797 assertions.
NEXT_EXACT_ACTION: commit/push this test-fixture hardening, require native Verify on the new exact head, then review -> PR/merge -> merged-main Verify.

## FMUX-014 macOS gate stabilization

Exact-head `69a631d5cb447acd11324c32f07ece3da3fcd12c` exposed the same pre-existing FMG-014 tamper-fixture ambiguity in `tests/test_swift_runtime.sh`: final-character mutation could become non-canonical base64url and fail as Malformed ContentRef before HMAC authentication.
Only the Swift test fixture was hardened to mutate the first signature-segment character, matching the deterministic Windows proof. `bash -n tests/test_swift_runtime.sh` and `git diff --check` PASS locally.
NEXT_EXACT_ACTION: commit/push this macOS fixture hardening and require native Verify on the new exact head. No ArtifactContentStore/runtime authority changed.

## FMUX-014 closure / FMG-016 synchronized local checkpoint

FMUX-014: DONE / MAIN VERIFIED.
- PR #34.
- Merge main: `7ced7b604d67acbb526e280e7e3653ba15d37d11`.
- Merged-main Verify: run `36458827979` SUCCESS on macOS / Windows x64 / Windows ARM64.

FMG-016: LOCAL VERIFIED / MAIN SYNC IN PROGRESS on `chatgpt/FMG-016-quarantine-restore`.
Catalog: 1.8.0 / 29 canonical tools / SHA-256 `717917385167e7c9877f83d60165e295ea703c25f37a2422cdd6ab2abc4cb50e`.
Pre-sync local proof: quarantine contract + catalog/parity PASS; Release build 0 warnings/errors; Windows full runtime 818 assertions PASS; macOS script syntax PASS.
Evidence: `docs/evidence/FMG-016_QUARANTINE_DELETE_RESTORE_EVIDENCE.md`.
NEXT_EXACT_ACTION: finish latest-main merge, rerun only affected state/catalog/quarantine/build/runtime gates, push exact synchronized head, native Verify all three lanes, scoped review, PR/merge, merged-main Verify, then FMG-016 MAIN VERIFIED.

## FMG-016 post-main-sync verification

State: SYNCHRONIZED LOCAL VERIFIED / NATIVE CI PENDING.
Synced main: `7ced7b604d67acbb526e280e7e3653ba15d37d11` (FMUX-014 MAIN VERIFIED).
Post-sync proof: project-state + FMG-016 quarantine + FMUX-014 contracts PASS; catalog/parity 1.8.0 / 29 tools PASS; Windows Release 0 warnings/errors; Windows runtime 818 assertions PASS; macOS script syntax PASS; diff check PASS.
NEXT_EXACT_ACTION: finish merge commit -> push exact head -> native Verify all three lanes -> scoped review -> PR/merge -> merged-main Verify -> FMG-016 MAIN VERIFIED.

## FMG-016 native Verify attempt 1 remediation

Run `36461034791` on `16fb4c22d401b04d89580d6f8d866e2174a39f12`: Windows x64 + ARM64 failed only because `tests/test_exec_process_contract.ps1` still expected 25 tools instead of catalog v1.8.0 / 29; macOS failed warnings-as-errors because `QuarantineService.list(maxItems:)` used an unnecessary `try` around a non-throwing lock closure.
Remediation is test/static-only: contract expectation/output updated to 29; redundant Swift `try` removed. Local affected-stage proof: exec-process contract PASS, quarantine contract PASS, macOS shell syntax PASS, diff check PASS. Product quarantine semantics are unchanged.
NEXT_EXACT_ACTION: commit/push remediation and require a new exact-head native Verify on all three lanes.

## FMG-016 native Verify attempt 2 remediation

Run `36461564984` on `f9b4b598bd449b437fe118d954732214090eedaf`: Windows x64 SUCCESS; Windows ARM64 SUCCESS; macOS product typecheck + runtime progressed through catalog/result/policy/budget/artifact/process/correlation/runtime checks and failed only because four quarantine test assertions performed throwing `Data(contentsOf:)` calls inside non-throwing `precondition` autoclosures.
Remediation is test-only: each throwing file read is hoisted into a local value before `precondition`. Local proof: Swift shell syntax PASS; no `precondition(... try Data(contentsOf:))` remains; diff check PASS.
NEXT_EXACT_ACTION: commit/push test-only remediation and require exact-head native Verify all three lanes.

## FMG-016 exact-head verification / review

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.
Candidate `8dd03ede244da123c41fd035d740b33b52526a11`; Verify run `36461989589`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
Scoped review PASS for package-before-delete, expected-version + Mutation Guard + policy reauthorization, guarded atomic single-file restore, checkpoint-backed tree transaction, identity-safe rollback and retained recovery artifact on rollback failure.
Evidence: `docs/evidence/FMG-016_QUARANTINE_DELETE_RESTORE_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push this evidence-only closure head, require exact-head native Verify all three lanes, then PR/merge -> merged-main Verify -> FMG-016 DONE / MAIN VERIFIED -> claim FMG-017.

## FMG-016 final closure / FMG-017 claim

FMG-016: DONE / MAIN VERIFIED.
- PR #35 head: `6e14773880a92e2413ec4d51793a2f04f3a8f705`.
- Merge main: `59073351ee77505659aa6a426fe73ff08a29b085`.
- Final exact-head Verify: `36511125923` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Merged-main Verify: `36511411880` SUCCESS.
- Evidence: `docs/evidence/FMG-016_QUARANTINE_DELETE_RESTORE_EVIDENCE.md`.

FMG-017: CLAIMED / ACTIVE on `chatgpt/FMG-017-model-friendly-edit-adapters`.
NEXT_EXACT_ACTION: implement model-friendly edit adapters only: `apply_search_replace` + `apply_unified_diff`, preview/dry-run, deterministic compilation to canonical `apply_edits`, no direct writes, expected-version preservation, exact BOM/newline inheritance, ambiguity fail-closed, and negative tests for zero/multiple match, malformed diff, overlapping hunks, stale version, path-header escape and cancellation. Do not begin FMG-018 before FMG-017 MAIN VERIFIED.

## FMG-017 local verification checkpoint

State: LOCAL VERIFIED / MAIN SYNC + NATIVE CI PENDING on `chatgpt/FMG-017-model-friendly-edit-adapters`.
Catalog: 1.9.0 / 31 canonical tools / SHA-256 `7b053baec3ddd1ce8789e651bdd0e9f6d1354387c03f2ddf8a1a05763d32d4d8`.
Local proof: edit-adapter contract + catalog/parity + dependent mutation/version contracts PASS; Windows Release 0 warnings/errors; FMG-017 isolation 16 assertions PASS; full Windows regression 834 assertions PASS; diff check PASS. macOS implementation/runtime harness is wired; native Swift verification is pending GitHub macOS Verify because this Windows host has no usable Swift toolchain.
Evidence: `docs/evidence/FMG-017_MODEL_FRIENDLY_EDIT_ADAPTERS_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit local-verified FMG-017 candidate, sync latest fork/main, rerun affected local gates, push exact synchronized head, require native Verify macOS + Windows x64 + native Windows ARM64, scoped review, PR/merge, merged-main Verify, then mark FMG-017 DONE / MAIN VERIFIED and claim FMG-018.


## FMG-017 exact-head native verification / scoped review

State: EXACT-HEAD NATIVE VERIFIED / REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.
Candidate: `5abe84a2c4b455b645307e70bacec86bdc1b5e9f`.
Verify run `36518117949`: SUCCESS on macOS / Windows x64 / native Windows ARM64. Initial run `36517765343` exposed only a Swift test call-label error; remediation was test-only.
Scoped review PASS: adapters are compile-only, preserve expected_version, delegate every write to canonical apply_edits, and fail closed on ambiguity/malformed diff/overlap/path escape/stale source/cancellation.
Evidence: `docs/evidence/FMG-017_MODEL_FRIENDLY_EDIT_ADAPTERS_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push the evidence-only closure head, require exact-head native Verify all three lanes, then PR/merge -> merged-main Verify -> FMG-017 DONE / MAIN VERIFIED -> claim FMG-018.

## FMG-017 final closure / FMG-018 claim

FMG-017: DONE / MAIN VERIFIED.
- PR #36 head: `7b5b1b566adce24f0f61e75a1ba7310af3560544`.
- Merge main: `4cc14b2cabe5ff23a8f8537e93a5a54c957f99a8`.
- Final exact-head Verify: run `36518798422` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Merged-main Verify: run `36519464683` SUCCESS on all three lanes.

FMG-018: CLAIMED / ACTIVE on `chatgpt/FMG-018-repository-intelligence-core`.
NEXT_EXACT_ACTION: implement FMG-018 Repository Intelligence Core / Cache only: RepositoryIntelligenceProvider interface, built-in lexical heuristic provider, Git-tracked inventory + ignored-directory policy, lightweight language-aware symbols/imports, file/symbol relation ranking, rebuildable metadata-only cache, SourceStateRef generation/invalidation, bounded cancellation, corruption/stale recovery, and no authorization dependency on intelligence. Do not begin FMG-019 before FMG-018 MAIN VERIFIED.

## FMG-017 final closure / FMG-018 claim

FMG-017: DONE / MAIN VERIFIED.
- Exact verified head: `7b5b1b566adce24f0f61e75a1ba7310af3560544`.
- Exact-head Verify: run `36518798422` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #36 merged.
- Merge main: `4cc14b2cabe5ff23a8f8537e93a5a54c957f99a8`.
- Merged-main Verify: run `36519464683` SUCCESS.
- Evidence: `docs/evidence/FMG-017_MODEL_FRIENDLY_EDIT_ADAPTERS_EVIDENCE.md`.

FMG-018: CLAIMED / ACTIVE on `chatgpt/FMG-018-repository-intelligence-core`.
NEXT_EXACT_ACTION: implement FMG-018 Repository Intelligence Core / Cache only: RepositoryIntelligenceProvider interface, built-in LexicalSymbolProvider, Git-tracked inventory plus ignored-directory policy, language-aware lightweight symbol/import extraction, relation/ranking model, rebuildable metadata cache, SourceStateRef generation/invalidation, no raw full-source persistence by default; preserve baseline tools and authorization independence. Add negative coverage for giant repo, binary/vendor/generated files, case/path differences, stale/corrupt cache, parser/profile mismatch and cancellation. Do not begin FMG-019 before FMG-018 MAIN VERIFIED.

## FMG-018 Windows core checkpoint

State: WINDOWS CORE TARGETED VERIFIED / MACOS PARITY PENDING.
Windows implementation + adversarial isolation PASS: `windows-repo-intelligence-only-tests: ok (22 assertions)`.
Evidence: `docs/evidence/FMG-018_REPOSITORY_INTELLIGENCE_CORE_EVIDENCE.md`.
NEXT_EXACT_ACTION: port the same provider/source-state/cache contract to macOS using existing safe Git + SourceStateRef primitives; wire native Swift tests/build lists; then cross-platform contract -> affected local gates -> full Windows regression -> exact-head native Verify. FMG-019 remains BLOCKED until FMG-018 MAIN VERIFIED.

## FMG-018 local verification checkpoint

State: LOCAL VERIFIED / NATIVE CI PENDING.
Local proof: repository-intelligence/source-state/project-context/catalog/parity/state contracts PASS; Windows Release 0 warnings/errors; FMG-018 isolation 22 assertions PASS; full Windows regression 856 assertions PASS; diff check PASS. macOS provider/service/cache parity + native tests are wired; native Swift typecheck/runtime remains pending GitHub macOS Verify.
Evidence: `docs/evidence/FMG-018_REPOSITORY_INTELLIGENCE_CORE_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit local-verified candidate, sync latest fork/main, rerun affected gates if needed, push exact synchronized head, require native Verify macOS + Windows x64 + native Windows ARM64, scoped review, PR/merge, merged-main Verify, then mark FMG-018 DONE / MAIN VERIFIED and claim FMG-019.

## FMG-018 native Verify attempt 1 remediation

Run `36524611510` on `f5e9190`: Windows x64 + ARM64 SUCCESS; macOS static/catalog SUCCESS; macOS integration timed out only because the pre-listener fixture watchdog was 15s after FMG-018 added bounded Git/SourceStateRef adversarial scans. Remediation is test-only: readiness deadline 15s -> 45s. FMG-018 contract + diff check PASS; product semantics unchanged.
NEXT_EXACT_ACTION: commit/push remediation and require exact-head native Verify all three lanes. FMG-019 remains BLOCKED.

## FMG-018 exact-head native verification / scoped review - 2026-09-29

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.

Candidate: `f1517f84cb5d7f8ae1dce329d1673b97dda7c58f`.
Native Verify: run `36525032038` SUCCESS on macOS / Windows x64 / native Windows ARM64.

Attempt-1 remediation in `f1517f8` is test-harness only:
- FMG-018 cache fixtures use a unique sibling temporary cache base, isolated from the resolver workspace;
- pre-listener macOS fixture readiness watchdog increased from 15s to 45s for the added bounded Git/SourceStateRef adversarial scans;
- no repository-intelligence product authority/catalog/runtime semantics changed.

Scoped review PASS:
- inventory is Git-tracked only (`git ls-files --cached -z --`) and bounded;
- paths are normalized/resolved through existing workspace authority;
- vendor/generated/binary/oversized inputs degrade or skip deterministically;
- lexical provider emits provider id/version, parser-profile hash and `completeness=heuristic`;
- cache is metadata-only; raw source is not persisted;
- cache freshness binds SourceStateRef + provider/profile and stale/corrupt cache is deleted/rebuilt;
- SourceStateRef is rechecked immediately before cache publish and in-flight source changes fail;
- indexing is ToolBudget/cancellation bounded;
- outputs explicitly report `grants_authority=false`;
- baseline tool/catalog surface remains unchanged; FMG-019 query facade is still BLOCKED.

Evidence: `docs/evidence/FMG-018_REPOSITORY_INTELLIGENCE_CORE_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push this evidence-only closure head, require exact-head native Verify all three lanes, then PR/review/merge -> merged-main Verify -> FMG-018 DONE / MAIN VERIFIED -> claim FMG-019.

## FMG-018 final closure / FMG-019 claim

FMG-018: DONE / MAIN VERIFIED.
- Final closure head: `cd24498aaebed4a6d639ddbce6ec59043e43d7f5`.
- Push Verify run `36534517010`: macOS + native Windows ARM64 SUCCESS; Windows x64 initial transient ProcessRunner bounded-output fixture failure; rerun of the single failed Windows job SUCCESS on the same head.
- PR #37 merged.
- Merge main: `02a4b60c1bd7afd5c5fbd2c5d467ba4f3a59fbee`.
- PR Verify run `36536059112`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Merged-main Verify run `36536725420`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Evidence: `docs/evidence/FMG-018_REPOSITORY_INTELLIGENCE_CORE_EVIDENCE.md`.

FMG-019: CLAIMED / ACTIVE on `chatgpt/FMG-019-repository-intelligence-query-facade`.
NEXT_EXACT_ACTION: implement only `repo_map`, `symbol_search`, and `related_files` over the FMG-018 MAIN VERIFIED repository-intelligence core. Preserve provider/version/heuristic completeness, deterministic ranking, SourceStateRef freshness, ToolBudget/cursor bounds, explicit stale-generation behavior, and optional ContentRef spillover for oversized maps. Add negative tests for ambiguous symbols, unsupported/no-symbol provider, stale generation during query, very large graph, invalid cursor, and unavailable artifact. Do not begin FMG-020 before FMG-019 MAIN VERIFIED.

## FMG-019 local verification checkpoint

State: LOCAL VERIFIED / NATIVE CI PENDING.
Catalog: 1.10.0 / 34 canonical tools / SHA-256 `a11c9512d6b182c13ad760709b99ff9224a702cb477953409e831d7d4e21289d`.
Local proof: query contract + predecessor/source-state/project-context/catalog/parity and affected contracts PASS; Windows Release 0 warnings/errors; FMG-019 isolation 18 assertions PASS; full Windows regression 876 assertions PASS; diff check PASS. Cross-platform cursor codec was hardened against non-canonical Base64URL signature aliases discovered by full regression. macOS query implementation + native acceptance are wired; native Swift verification remains pending GitHub macOS Verify.
Evidence: `docs/evidence/FMG-019_REPOSITORY_INTELLIGENCE_QUERY_FACADE_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit local-verified FMG-019 candidate, sync latest fork/main, rerun affected local gates only if sync changes the candidate, push exact synchronized head, require native Verify macOS + Windows x64 + native Windows ARM64, scoped review, PR/merge, merged-main Verify, then mark FMG-019 DONE / MAIN VERIFIED and claim FMG-020.

## FMG-019 exact-head native verification / scoped review

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.
Candidate: `fbdb9d5eb36e1b0a90aab64234c2ff7f12c83753`.
Native Verify run `36544068228`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
Scoped review PASS: read-only/closed-world authority preserved; deterministic ranking/cursors; SourceStateRef freshness before return and post-publish; stale artifact cleanup; metadata-only ContentRef; canonical Base64URL cursor rejection cross-platform.
Evidence: `docs/evidence/FMG-019_REPOSITORY_INTELLIGENCE_QUERY_FACADE_EVIDENCE.md`.
NEXT_EXACT_ACTION: commit/push this evidence-only closure head, require exact-head native Verify all three lanes, then PR/merge -> merged-main Verify -> mark FMG-019 DONE / MAIN VERIFIED -> claim FMG-020.

## FMG-019 PR Verify attempt 1 remediation

PR #38 run `36545273004`: Windows x64 + native ARM64 SUCCESS; macOS failed only on the pre-listener fixture readiness watchdog after FMG-019 increased native startup work. Remediation is test-only: readiness watchdog 45s -> 90s; product semantics unchanged.
NEXT_EXACT_ACTION: commit/push remediation, require exact-head three-lane Verify/PR checks, then merge PR #38 with expected head SHA and require merged-main Verify.

## FMG-019 final closure / FMG-020 claim

FMG-019: DONE / MAIN VERIFIED.
- Final feature/remediation head: `a6822a5b4b0a372fd4973b6963a314ccb5481469`.
- PR #38 merged at `3623f96c1d6041f46bc6fcb7781f11a17ccb1d29`.
- Earlier exact-head native Verify `36544068228`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Closure push Verify `36544798050` on `0bfa1017...`: SUCCESS on all three lanes.
- PR attempt `36545273004`: Windows x64 + ARM64 SUCCESS; macOS hit only the pre-listener 45s readiness watchdog; fixed test-only to 90s in `a6822a5...`.
- Remediated push Verify `36549734370`: macOS + native ARM64 SUCCESS; Windows x64 hit a fixture-only 20s `git add` timeout while emitting CRLF warnings; no product/query assertion failed.
- Merged-main Verify `36550274743`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Catalog remains `1.10.0` / 34 tools / SHA-256 `a11c9512d6b182c13ad760709b99ff9224a702cb477953409e831d7d4e21289d`.
- Evidence: `docs/evidence/FMG-019_REPOSITORY_INTELLIGENCE_QUERY_FACADE_EVIDENCE.md`.

FMG-020: CLAIMED / ACTIVE on `chatgpt/FMG-020-persistent-pty`.
NEXT_EXACT_ACTION: audit existing process lifecycle, environment authority, artifact store, cursor/session identity, LocalTools/catalog and platform-specific primitives; freeze a persistent PTY contract for Windows ConPTY + macOS POSIX PTY, then implement the bounded session runtime without starting FMG-021.

## FMG-019 closure / FMG-020 claim - 2026-09-29

FMG-019: DONE / MAIN VERIFIED.
- PR: #38.
- Merge main: `3623f96c1d6041f46bc6fcb7781f11a17ccb1d29`.
- Merged-main Verify: run `36550274743` SUCCESS on macOS / Windows x64 / Windows ARM64.

FMG-020: CLAIMED / ACTIVE on `chatgpt/FMG-020-persistent-pty`.
Scope: Windows ConPTY + macOS POSIX PTY/forkpty semantics; pty_start/read/write/resize/signal/stop/list; scoped opaque session IDs; exec_process environment authority reuse; bounded RAM ring + cursor reads; idle/max TTL; optional short-lived PTY_OUTPUT spillover; process-tree cleanup; restart never fakes resume; no PTY bytes in evidence/telemetry.

NEXT_EXACT_ACTION: implement native PTY host + session manager + 7 tool facade only, then contract/native TTY tests -> local regression -> exact-head native Verify -> scoped review -> PR/merge -> merged-main Verify -> FMG-020 MAIN VERIFIED -> claim FMG-021.

## FMG-020 Windows PTY checkpoint

State: WINDOWS PTY TARGETED VERIFIED / MACOS PARITY PENDING.
Windows proof: Release build 0 warnings/errors; `windows-pty-only-tests: ok (23 assertions)`. ConPTY native terminal devices, ring routing, write/read, resize, Ctrl-C, tamper rejection, policy reauth, Job Object tree cleanup, bounded ring, PTY_OUTPUT spill/delete, cursor bounds, idle TTL, max lifetime and restart-no-resume all PASS.
Evidence: `docs/evidence/FMG-020_PERSISTENT_PTY_SESSION_RUNTIME_EVIDENCE.md`.
NEXT_EXACT_ACTION: port the same session contract to macOS using a real POSIX PTY (not pipes), wire seven LocalTools handlers + native Swift tests/build lists, then cross-platform FMG-020 contract -> affected local gates -> full Windows regression -> exact-head native Verify. FMG-021 remains BLOCKED until FMG-020 MAIN VERIFIED.

## Single PROJECT_ROOT consolidation - 2026-09-29

Canonical PROJECT_ROOT: `D:\Tools\FileMCP`.
State: CONSOLIDATED / VERIFIED.

Verified after consolidation:
- `git worktree list` contains exactly one worktree: `D:/Tools/FileMCP`;
- `D:\Tools` contains exactly one `FileMCP*` directory: `D:\Tools\FileMCP`;
- active branch is `chatgpt/FMG-020-persistent-pty`;
- preserved active checkpoint before this documentation commit: `92e4496cb8c4127716d3478645da03a045b41dbe`, pushed to `fork/chatgpt/FMG-020-persistent-pty`;
- stale PR #29 (`FMUX-007-settings-policy-v2`) was closed because it is superseded and would regress later merged FMUX UI/state;
- FMG-013 Git-fixture hardening was merged into FMG-020 and verified by Windows build 0 warnings/errors plus `repo-query-only` 18 assertions PASS;
- FMG-017 dirty alternate was intentionally not merged because PR #36/main contains the larger verified adapter implementation;
- FMG-018 divergent alternate core was intentionally not merged over PR #37/main because current main already contains equivalent cache/profile/scale/staleness hardening and FMG-019 is verified on that authority;
- all sibling `FileMCP-*-worktree` directories were removed and `git worktree prune` completed.

Evidence: `docs/evidence/PROJECT_ROOT_CONSOLIDATION_EVIDENCE.md`.

Continuation remains FMG-020 Persistent PTY from the canonical root only. Do not recreate a secondary worktree; the existing FMG-020 `NEXT_EXACT_ACTION` above remains authoritative.


## D:\ root FileMCP cleanup - 2026-09-29

Canonical PROJECT_ROOT remains `D:\Tools\FileMCP` only.

Audited external siblings before deletion:
- `D:\FileMCP-Lifecycle-Proof-20260922`: clean standalone toy lifecycle-proof repo; product source was not imported because canonical FileMCP has stronger real lifecycle proof. Provenance/evidence preserved at `docs/evidence/LEGACY_FILEMCP_LIFECYCLE_PROOF_2026-09-29.md`.
- `D:\FileMCP-OSS-Audit`: clean cache of 11 pinned OSS reference clones already absorbed by the frozen OSS audit/design. Full origin + 40-character SHA manifest preserved at `docs/audit/OSS_AUDIT_PINNED_SOURCE_MANIFEST_2026-09-29.md`.

No uncommitted source was discarded. No alternate project root is required for current work.
FMG-020 remains the active implementation track and must continue from the canonical root only.

## External D:\ FileMCP sibling cleanup - 2026-09-29

Completed after source audit:
- `D:\FileMCP-Lifecycle-Proof-20260922`: deleted; clean toy proof repo. Product source was not imported. Provenance/evidence preserved in `docs/evidence/LEGACY_FILEMCP_LIFECYCLE_PROOF_2026-09-29.md`.
- `D:\FileMCP-OSS-Audit`: deleted; all 11 nested repos were clean. Exact origin/branch/full-SHA pins and canonical dispositions preserved in `docs/audit/OSS_AUDIT_PINNED_SOURCE_MANIFEST_2026-09-29.md`.
- no uncommitted local source from either directory was discarded; no alternate runtime/project code was selected for import because canonical audit/design already contains the accepted stronger decisions.

Canonical PROJECT_ROOT remains `D:\Tools\FileMCP` only. FMG-020 remains the active implementation track.

## FMG-020 macOS parity local checkpoint - 2026-09-29

State: LOCAL CROSS-PLATFORM VERIFIED / NATIVE CI PENDING.

Windows checkpoint remains PASS and was not rerun:
- native ConPTY implementation;
- `windows-pty-only-tests: ok (23 assertions)`;
- Release build 0 warnings / 0 errors.

New macOS implementation:
- real POSIX PTY via `forkpty`;
- process-group ownership validation before group signaling;
- native `TIOCSWINSZ` resize;
- Ctrl-C terminal byte semantics and terminate signal;
- workspace-scoped opaque sessions, bounded ring/cursors, idle/max TTL, optional `PTY_OUTPUT` spill/delete;
- LocalTools parity for `pty_start/read/write/resize/signal/stop/list`;
- server shutdown stops owned PTY sessions;
- native Swift acceptance covers actual TTY, write/read, resize, Ctrl-C, session tamper, restart-no-resume, policy revoke, child-tree cleanup, output flood/spill, future cursor, idle TTL and hard lifetime.

Local affected-stage proof:
- project-state contract PASS;
- catalog contract PASS: 1.11.0 / 41 tools / SHA-256 `d997f8c9ea814876e48ba83f888355b75aad4c0215fc92eca9397f457a42cdbc`;
- persistent-PTY cross-platform contract PASS;
- Swift runtime shell syntax PASS;
- macOS build shell syntax PASS;
- `git diff --check` PASS.

NEXT_EXACT_ACTION: commit/push this exact FMG-020 candidate, require native Verify on macOS / Windows x64 / Windows ARM64, fix only failing lane/stage if any, then scoped review -> PR/merge -> merged-main Verify -> FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.

## FMG-020 exact-head Verify remediation - 2026-09-29

Exact-head `72383d140e8d9c5bc256783119a58945e417cfaf`, Verify run `36597408414`:
- Windows ARM64: SUCCESS.
- Windows x64: FAIL only at stale canonical-tool count assertions after catalog 1.11.0 / 41 tools.
- macOS: static/typecheck/catalog and pre-PTY runtime stages PASS; FAIL at native forkpty TTY assertion `forkpty child must observe terminal stdin/stdout`.

Remediation currently local:
- Windows test expectations updated to 36 non-shell local tools / 37 full local tools, with full runtime semantics unchanged.
- macOS `PosixPtyHost` now allocates stable heap-backed argv/envp pointer arrays before `forkpty`; child `execve` no longer enters Swift Array buffer closures after fork. This is a fork-safety/lifetime fix, not a PTY authority redesign.
- native PTY assertion now includes observed output in failure diagnostics.

Affected local proof:
- canonical catalog contract PASS: 1.11.0 / 41 tools / SHA-256 `d997f8c9ea814876e48ba83f888355b75aad4c0215fc92eca9397f457a42cdbc`;
- persistent-PTY contract PASS;
- Windows full core runtime PASS: 899 assertions;
- Windows PTY-only PASS: 23 assertions;
- project-state contract PASS;
- Swift runtime shell syntax PASS;
- macOS build shell syntax PASS;
- `git diff --check` PASS.

Native macOS forkpty proof remains pending and must be established by the next exact-head native Verify. Do not claim FMG-020 MAIN VERIFIED until macOS + Windows x64 + Windows ARM64 all pass on the same exact head, then PR/review/merge and merged-main Verify succeed.
NEXT_EXACT_ACTION: inspect latest `fork/main`, remote FMG-020 branch and PR state before side effects; if no duplicate/newer head exists, commit/push this exact remediation candidate and require a new exact-head native Verify.

## FMG-020 macOS diagnostic checkpoint

Exact-head `cbfb623735ff437bcb358b81073ea2359c7689ae`, Verify run `36599800550`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static verification: SUCCESS.
- macOS Integration: FAIL at native forkpty TTY assertion with empty captured output.

Because the failure does not yet distinguish child launch/exit from master-reader failure, the next change is test-diagnostic only: the assertion now reports the PTY session state and metadata (including exit code when terminal) from `pty_list`. No PTY runtime authority or product semantics are changed by this diagnostic.
NEXT_EXACT_ACTION: commit/push the diagnostic-only head, run native Verify, inspect only macOS integration evidence, then fix the proven macOS PTY defect.

## FMG-020 macOS native-launch remediation

Diagnostic head `5940a2da21ba2da29bdb3968847f05a10256fc7d`, Verify run `36600521628`, proved the native PTY child remained alive for the full timeout with `state=running`, `exit_code=null`, and `end_cursor=0`. This rules out an immediate exec failure and shows the raw `forkpty` child path was stuck before producing output.

Remediation replaces only the macOS launch primitive:
- allocate a real PTY with `openpty`;
- launch with `posix_spawn`, so no Swift runtime code executes in the child after a raw fork;
- use spawn file actions for cwd and slave-to-stdin/stdout/stderr binding;
- create a dedicated child process group with `POSIX_SPAWN_SETPGROUP`;
- use process-group SIGINT for `ctrl_c` and SIGTERM for terminate, preserving bounded owned-group signaling;
- backend truth label is now `macos-posix-openpty-spawn`.

Unchanged: workspace scope, opaque session IDs, policy reauthorization, ring/cursor semantics, TTL/hard lifetime, PTY_OUTPUT spill/delete, restart-no-resume, evidence/telemetry privacy, and the seven MCP tool contracts.

Local affected proof: persistent-PTY contract PASS; Swift runtime shell syntax PASS; macOS build shell syntax PASS; `git diff --check` PASS. Native typecheck/integration remains pending on macOS CI.
NEXT_EXACT_ACTION: verify remote/main state, commit/push this exact macOS launcher remediation, then require exact-head native Verify on macOS / Windows x64 / Windows ARM64.

## FMG-020 macOS PTY raw-FD remediation

Exact-head `c8b0d2a263110570789787d8734cb5694d4f2c59`, Verify run `36601440168`, proved the new `openpty + posix_spawn` launcher passes macOS static/typecheck but integration still returns an owned live session with `state=running`, `exit_code=null`, and `end_cursor=0`.

The next remediation is isolated to the PTY master I/O layer:
- replace Foundation `FileHandle` reads/writes with raw `Darwin.read/write` loops;
- retry `EINTR`;
- treat PTY-master `EIO` as a transient slave-lifecycle condition while the owned child is still running, instead of silently terminating the reader;
- preserve bounded partial-write handling;
- resize/close now use the same raw descriptors;
- native failure diagnostics include the descendant PID-file state, which distinguishes fixture execution from an output-reader failure.

Unchanged: `openpty + posix_spawn` launch topology, process-group ownership, workspace/session scope, policy reauthorization, ring/cursor/TTL/spill semantics, restart-no-resume, and PTY evidence/telemetry privacy.

Local affected proof already PASS: persistent-PTY contract; Swift runtime shell syntax; `git diff --check`.
NEXT_EXACT_ACTION: verify remote/main/PR state, commit/push the raw-FD remediation, require exact-head native Verify, then inspect only any failing lane/stage.

## FMG-020 macOS descendant-cleanup verification remediation - 2026-09-30

Exact-head `4711a62962a98777768ea1f2ca2ef9970494c7a8`, Verify run `36602361704`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration: FAIL only at `PTY descendant process-tree cleanup` after `pty_stop`.

The production stop path already proves process-group ownership and signals the owned group. The failing assertion required the descendant PID to disappear from the process table (`ESRCH`). On macOS a killed descendant can remain temporarily as a zombie until its reaper collects it; `kill(pid, 0)` remains successful even though the process is no longer runnable.

Remediation is test-only:
- add a fail-closed process-state probe using `/bin/ps -o state=`;
- cleanup passes only when the PID is absent or in zombie state;
- any live/runnable state still fails;
- production PTY/session/process-group semantics are unchanged.

Affected local proof:
- persistent-PTY contract: PASS;
- Swift runtime shell syntax: PASS;
- `git diff --check`: PASS.

NEXT_EXACT_ACTION: verify latest main/remote branch state, commit/push this test-only remediation, require exact-head native Verify on macOS / Windows x64 / Windows ARM64; if green, scoped review -> PR/merge -> merged-main Verify -> FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.

## FMG-020 macOS proven-process-group cleanup fixture - 2026-09-30

Exact-head `52fcf1694714a755a1ebc619cd45f6aaac80884a`, Verify run `36604291025`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS: FAIL only at descendant process-tree cleanup even after zombie-aware inspection, proving the descendant remained runnable.

The prior fixture spawned `/bin/sleep` via Foundation `Process`, which does not provide an explicit contract that the descendant remains in FileMCP's owned PTY process group. Because FMG-020 must never kill arbitrary PIDs without ownership proof, the fixture is now stronger and more precise:
- a dedicated child fixture explicitly joins the PTY parent's process group with `setpgid`;
- the parent waits until the child is running in that group before publishing its PID;
- the acceptance test verifies `child PGID == PTY owned PGID` before calling `pty_stop`;
- cleanup still requires the child to become non-runnable (PID absent or zombie only).

This is test-only ownership hardening; production PTY/process-group code is unchanged.
Affected local proof: persistent-PTY contract PASS; Swift runtime shell syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this ownership-proven fixture and require a fresh exact-head native Verify. If macOS still fails the same cleanup assertion, fix only production process-group cleanup; otherwise proceed to scoped review -> PR/merge -> merged-main Verify -> FMG-020 MAIN VERIFIED -> FMG-021.


## FMG-020 macOS invalid-resize assertion remediation - 2026-09-30

Exact-head `65b0375d2c9574da0a291c2a8c037938d5e32353`, Verify run `36666308781`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration progressed beyond the ownership-proven descendant cleanup and failed at generated `main.swift:240`, the `ptyInvalidResizeRejected` assertion.

Root cause is test-message specificity, not PTY authority: canonical schema validation rejects `columns: 0` before `PersistentPtyService.validateSize`, producing `Argument columns must be >= 1`; the test accepted only an error message containing `size`.

Remediation is test-only: the native macOS acceptance now treats the invalid resize as correctly rejected when the localized error identifies either PTY `size` validation or the canonical `columns` bound. Production PTY/runtime behavior is unchanged.

Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this test-only invalid-resize assertion hardening and require a fresh exact-head native Verify on macOS / Windows x64 / Windows ARM64. If green, scoped review -> PR/merge -> merged-main Verify -> FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.


## FMG-020 macOS post-resize diagnostic checkpoint - 2026-09-30

Exact-head `acf23e406590ee40645698c8ac682d4794c0d127`, Verify run `36667522493`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration moved beyond the invalid-resize assertion but terminated with SIGTRAP before the final PTY success marker; the job log did not emit a Swift source line for the new trap.

Diagnostic-only remediation: add flushed `FMG020_CHECKPOINT:*` markers after invalid-resize, restart-no-resume, policy-revoke, flood/spill cleanup, future-cursor, idle-expiry and lifetime-expiry acceptance points. Production runtime is unchanged.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this diagnostic-only head, inspect only the macOS Integration checkpoint boundary, then fix the exact proven failing substage. Do not change Windows/runtime behavior without evidence.


## FMG-020 macOS flood/spill diagnostic checkpoint - 2026-09-30

Exact-head `d6c9eb051943793db2a8d5814ec80a3b8a01b0fe`, Verify run `36668399919`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration checkpoints PASS through `invalid-resize`, `restart-no-resume`, and `policy-revoke`, then SIGTRAP before `flood-spill-cleanup`.

The failing region is therefore narrowed to the service-level bounded-ring / spill / artifact cleanup assertions. Diagnostic-only instrumentation now prints the actual `cursor_evicted`, spill-ref count, artifact reference count before stop, and artifact reference count after stop. Production PTY/runtime behavior remains unchanged.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this flood/spill diagnostic-only head, inspect macOS Integration values, then repair only the exact proven failing invariant.


## FMG-020 macOS flood diagnostic syntax remediation - 2026-09-30

Exact-head `673bfb5592ff91358da6635eb0be996b319fe5d9`, Verify run `36668772693`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS failed before PTY runtime diagnostics because two diagnostic-only Swift string interpolations escaped dictionary-key quotes inside interpolation, producing compile errors at generated main.swift lines 327/330.

Remediation is diagnostic-only: bind `cursor_evicted` and spill-ref count to local Swift variables before interpolation, eliminating nested escaped literals. Production runtime is unchanged.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push corrected diagnostic syntax, require fresh exact-head Verify, inspect the emitted `FMG020_FLOOD:*` values, then repair only the exact proven invariant.


## FMG-020 macOS flood-stage boundary diagnostic - 2026-09-30

Exact-head `bc6a970b5c0ed4623f439fa537bb1ac71790dc77`, Verify run `36669074011`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration passes checkpoints through `policy-revoke`, but none of the post-read `FMG020_FLOOD:*` values are emitted before SIGTRAP.

The failure is therefore earlier than the four flood/spill assertions. Diagnostic-only instrumentation now brackets service initialization, flood-command creation, PTY start, wait-for-exit and read so the next native run identifies the exact boundary. Production runtime remains unchanged.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this boundary diagnostic, inspect only macOS Integration stage markers, then fix the proven failing operation without changing already-green Windows behavior.


## FMG-020 macOS ring-index remediation - 2026-09-30

Exact-head `14931eabf1d4e107dfef1f6593e7acb70ae9f250`, Verify run `36669390759`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration emitted `before-service-init`, `before-command`, `before-start`, `after-start`, `before-wait`, `after-wait`, `before-read`, then SIGTRAP before `after-read`.

Root cause is the macOS bounded-ring read slice. After `Data.removeFirst(overflow)`, the collection's valid `startIndex` must not be assumed to be zero. The old code calculated a relative cursor index correctly but sliced `ring[index..<index+count]`, which can trap after eviction. Remediation converts the relative offset through `ring.index(ring.startIndex, offsetBy:)`, validates the relative range, and slices only with valid Data indices. The PTY contract now pins `ring.startIndex` usage to prevent regression.

Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push the ring-index remediation with retained diagnostics, require a fresh exact-head native Verify, then inspect flood/spill values and continue only if a remaining invariant fails.


## FMG-020 native PTY core PASS; post-PTY runtime diagnostic - 2026-09-30

Exact-head `d31a4128f2c08fc68ba77795de595c916ca6fbba`, Verify run `36669725567`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS PTY acceptance: PASS through read, eviction, spill and cleanup.
- Native values: `cursor_evicted=true`, `spill_refs=7`, artifact references `7 -> 0`, future-cursor rejection PASS, idle-expiry PASS, lifetime-expiry PASS.
- The run then failed outside the PTY acceptance block at the pre-existing LocalMCPRuntime test with `timed out waiting for first runtime`.

This proves the Data-index remediation fixed the FMG-020 macOS PTY failure. Because `main` Verify was green before FMG-020, the next diagnostic changes only the first-runtime wait to resolve on `.running` or `.failed`, print only a secret-sanitized failure log, and assert `.running`. No production runtime behavior changes.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push the fail-fast post-PTY runtime diagnostic, inspect the exact sanitized LocalMCPRuntime failure, then repair only the proven interference/regression before final FMG-020 review/merge.


## FMG-020 post-PTY runtime profile fixture remediation - 2026-09-30

Exact-head `8cd0d5e11672a009f77ffecd0e15a73fd22bef5b`, Verify run `36670371331`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS PTY acceptance: PASS through native TTY, owned descendant cleanup, invalid resize rejection, restart-no-resume, policy revoke, bounded-ring eviction, spill/delete, future cursor, idle expiry and lifetime expiry.
- macOS Integration then failed outside FMG-020 PTY core because the runtime test profile was the literal `runtime-test-\\(UUID().uuidString)`, which violates the profile character contract.
- Sanitized runtime evidence: `Profile must start with a letter or number and contain only letters, numbers, '.', '_' or '-'`.

Remediation is test-only: restore real Swift interpolation in the existing runtime fixture as `runtime-test-\(UUID().uuidString)`. Production PTY and LocalMCPRuntime behavior are unchanged.
Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS; exact fixture assertion PASS; `git diff --check` PASS.
NEXT_EXACT_ACTION: commit/push this test-only profile fixture remediation, require fresh exact-head Verify macOS + Windows x64 + Windows ARM64; if all green, perform scoped FMG-020 review -> PR/merge -> merged-main Verify -> mark FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.


## FMG-020 macOS deployment-target spawn-chdir remediation - 2026-09-30

Exact-head `bfed45e959e111e986cf40b2821e3068b150bb77`, Verify run `36670793927`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static/typecheck/catalog: SUCCESS.
- macOS Integration: SUCCESS, including the full FMG-020 native PTY acceptance and pre-existing runtime integration.
- macOS Build app: FAIL only because `posix_spawn_file_actions_addchdir` is unavailable for the app deployment target `macOS 12.0` and is SDK-available only on macOS 26+.

Remediation is limited to PTY launch compatibility: keep the existing `posix_spawn` topology and use the standard `posix_spawn_file_actions_addchdir` on macOS 26+, with `posix_spawn_file_actions_addchdir_np` isolated behind an availability-bounded helper for macOS 12..25. PTY ownership, process-group, cwd containment, environment, ring/cursor/spill, policy and cleanup semantics are unchanged.

Affected local proof: persistent-PTY contract PASS; Git Bash syntax PASS for runtime/build scripts; `git diff --check` PASS. Native macOS compile/build remains the authoritative proof for SDK availability.
NEXT_EXACT_ACTION: commit/push this deployment-target compatibility remediation, require fresh exact-head Verify macOS + Windows x64 + Windows ARM64; if all green, scoped review -> PR/merge -> merged-main Verify -> FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.


## FMG-020 macOS SDK-26 deprecation remediation - 2026-09-30

Exact-head `72c2adcf0abd0d0a52028be5885a0c5c39578201`, Verify run `36672151953`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS failed only at Static verification before Integration/Build.
- Compiler evidence: direct `posix_spawn_file_actions_addchdir_np` is deprecated on the macOS 26 SDK and `-warnings-as-errors` rejects it; the availability-obsoleted helper was also considered unavailable at the fallback call site.

Remediation keeps the already-proven `openpty + posix_spawn` topology and cwd file-action semantics while removing compile-time reference to the deprecated symbol. macOS 26+ uses `posix_spawn_file_actions_addchdir`; macOS 12..25 resolves the legacy `posix_spawn_file_actions_addchdir_np` symbol dynamically with `dlopen`/`dlsym`, fail-closed if the compatibility symbol is unavailable. PTY ownership, process-group signaling, workspace containment, environment authority, ring/cursor/spill, TTL, restart-no-resume and evidence/privacy semantics are unchanged.

Current worktree is remediation-only; no CI run exists for this uncommitted dlsym candidate yet.
NEXT_EXACT_ACTION: verify changed-scope local contracts, commit/push the dlsym compatibility remediation, require a fresh exact-head native Verify; do not rerun or modify already-green Windows behavior except as the branch workflow naturally verifies the pushed head.


## FMG-020 exact-head native PASS + scoped-review cleanup - 2026-09-30

Exact-head `be848d23d9a01cb446a501e0cde8775a1a6dba61`, Verify run `36673260254`, attempt 2: SUCCESS.
- macOS: Static/typecheck/catalog PASS; Integration PASS; Build app PASS; bundled legal resources PASS.
- Windows ARM64: full job PASS including native build/smoke/package.
- Windows x64 initial attempt failed only on a transient exclusive file lock while reading `runtime-dynamic-health.health-url`; the failure was unrelated to the macOS-only code change. The exact failed Windows x64 job was rerun without code changes and then passed integration, x64/arm64 package builds, app smoke, resources and upload.

Scoped review against `fork/main` confirmed FMG-020 production invariants remain intact: ConPTY + kill-on-close Job Object on Windows; POSIX openpty + posix_spawn + proven process-group signaling on macOS; workspace-scoped sessions; restart-no-resume; bounded ring/cursor/TTL/spill; PTY bytes absent from evidence/telemetry; macOS 12..25 legacy cwd spawn action resolved fail-closed via dlsym and macOS 26+ uses the standard API.

Review cleanup removes only temporary `FMG020_CHECKPOINT:*` and `FMG020_FLOOD_*` debug prints/temporary variables from the macOS native acceptance test. It keeps the actual TTY marker, write/read round-trip, final `swift-persistent-pty: ok` marker and sanitized runtime failure diagnostic.
NEXT_EXACT_ACTION: verify changed-scope contracts after review cleanup, commit/push the cleanup+state sync, require fresh exact-head Verify, then create/review/merge the FMG-020 PR if green.


## FMG-020 MAIN VERIFIED -> FMG-021 CLAIMED - 2026-09-30

FMG-020 Persistent PTY Session Runtime is DONE / MAIN VERIFIED.
- PR #39 merged successfully as `4f99a60ba91abc0040364f70c9df86478fc4dab2`.
- Merged-main Verify run `36675201004`: SUCCESS on macOS, Windows x64 and Windows ARM64, including native integration/build/smoke/package gates.
- Canonical working tree is now on branch `chatgpt/FMG-021-workspace-checkpoint` created directly from merged main; no secondary worktree was created.

FMG-021 Workspace Checkpoint Capture is CLAIMED / ACTIVE. Dependencies FMG-014 Artifact Store, FMG-006 SourceStateRef/versioning and FMG-011 metadata-only evidence are all DONE / MAIN VERIFIED.
NEXT_EXACT_ACTION: deep-read the frozen checkpoint-capture requirements and existing cross-platform primitives for Artifact Store, SourceStateRef/Git source state, safe path/symlink handling, ignored/untracked enumeration, TTL/quota and metadata evidence; then implement the smallest cross-platform checkpoint capture service + tool surface + adversarial tests without starting FMG-022 restore.


## FMG-021 Windows capture core checkpoint - 2026-09-30

Windows Workspace Checkpoint Capture core is implemented and affected behavior test is PASS: `windows-checkpoint-only-tests: ok (20 assertions)`.
Verified invariants: explicit capture only; staged index bytes and divergent worktree bytes are captured separately including binary content; staged/unstaged/untracked coverage; ignored files excluded by default and captured only by explicit opt-in; repository Git status is unchanged by capture; file/byte bounds fail closed; SourceStateRef revalidation aborts concurrent workspace changes and cleans partial CHECKPOINT ContentRefs; TTL expiry prunes record/artifacts; manifest corruption is rejected; lexical symlink/reparse entries are rejected before canonical resolution; delete cleans manifest and payload refs.
Catalog candidate is now 1.12.0 / 45 tools with checkpoint_capture/list/get/delete. Windows Core + test assembly compile PASS with 0 warnings/errors.
NEXT_EXACT_ACTION: port the same manifest/capture/list/get/delete contract to macOS using the existing Artifact Store + SourceStateRef/Git primitives, add cross-platform contract/native tests and Verify wiring, then run only affected gates before broader exact-head Verify.
## FMG-021 cross-platform candidate ready for native Verify - 2026-09-30

FMG-021 remains ACTIVE; FMG-022 remains BLOCKED.
- Windows checkpoint-only behavior: PASS, `27 assertions`.
- Canonical catalog: `1.12.0`, 45 tools; catalog/parity hash `fed4db13cf86a994564a42bef4ee80cfd0b4ef4a5ceee2c66c32f255cd9a3ea6`.
- Project-state contract: PASS.
- Swift/bash static checkpoint contract: PASS; native macOS behavior block is wired into `tests/test_swift_runtime.sh` and `WorkspaceCheckpoint.swift` is wired into static/build lanes.
- Capture semantics now match the frozen architecture: ignored and generated payloads excluded by default; ignored/generated require explicit bounded opt-in; oversized single-file payloads are reported as excluded rather than failing the whole checkpoint; staged/worktree bytes remain separate; scoped SourceStateRef race guard includes opt-in ignored/generated paths; disk-full/concurrent-change failures clean partial Artifact Store refs; temporary staged-blob files on macOS are mode 0600.
- `git diff --check`: PASS.
- No native macOS runner evidence exists for this uncommitted candidate yet.

NEXT_EXACT_ACTION: commit the FMG-021 candidate and state sync on `chatgpt/FMG-021-workspace-checkpoint`, push the exact head once, then require fresh Verify on macOS / Windows x64 / Windows ARM64. If a lane fails, repair only the proven failing stage; if all lanes pass, perform scoped review -> PR/merge -> merged-main Verify -> FMG-021 MAIN VERIFIED -> claim FMG-022.
## FMG-021 exact-head Verify scoped remediation ready - 2026-09-30

Exact-head candidate `252d77b11ea5d177e66fb9d806bed9820ded4241`, Verify run `36691938173`:
- Windows ARM64 job `109810925781`: PASS; unchanged.
- Windows x64 job `109810925432`: failed only in Windows integration due stale local-tool surface counts after adding 4 checkpoint tools.
- macOS job `109810925888`: failed only in Static verification because unused `try?` delete result is rejected by `-warnings-as-errors`; Integration/Build were skipped.
- Scoped macOS fix: explicit `_ = try? artifactFactory().delete(...)`; local static/bash remediation check PASS.
- Scoped Windows fix: catalog local counts 40/41, restricted/full LocalTools counts 32/41, correlated MCP facade count 36.
- Added `tool-surface-only` targeted regression selector so future catalog-surface changes can be verified without rerunning the full Windows suite.
- Windows affected-scope proof: build PASS 0 warnings/errors; `windows-tool-surface-only-tests: ok (127 assertions)`.
- `git diff --check`: PASS.

NEXT_EXACT_ACTION: commit the scoped remediation + state sync, push branch once, require fresh exact-head Verify on macOS / Windows x64 / Windows ARM64. Do not rerun the already-passed old ARM64 job. If fresh exact-head all-green, scoped review -> PR/merge -> merged-main Verify -> FMG-021 MAIN VERIFIED -> claim FMG-022.
## FMG-021 Verify 36695888973 results + Swift harness remediation - 2026-09-30

Exact-head `3aa0f5977beef12435871fc337332cb4a1c25630`, Verify run `36695888973`:
- Windows ARM64 job `109823629747`: SUCCESS / full job PASS.
- Windows x64 job `109823629843`: FMG-021 contracts and prior static gates PASS; integration later failed in pre-existing ProcessRunner/Repository Intelligence path because Windows Job Object assignment returned `Access is denied`. This code path is unchanged by FMG-021 and the same exact-head ARM64 lane passed, so no security weakening is justified from this single x64 runner failure.
- macOS job `109823629945`: Static verification PASS; canonical catalog PASS; Integration failed while compiling the FMG-021 Swift acceptance block because throwing calls were embedded in non-throwing `precondition` autoclosures.
- Swift harness remediation hoists all throwing checkpoint calls/usage queries to `let` bindings before `precondition`.
- `tests/test_workspace_checkpoint_contract.ps1` now rejects FMG-021 `try`-inside-`precondition` regressions.
- Local evidence after remediation: workspace-checkpoint contract PASS; Git Bash syntax PASS; `git diff --check` PASS.

NEXT_EXACT_ACTION: commit/push this test-harness-only remediation, require a fresh exact-head Verify. Do not modify ProcessRunner/Job Object semantics unless the x64 failure reproduces on the new exact head or independent evidence proves a product defect. FMG-022 remains BLOCKED until FMG-021 MAIN VERIFIED.

## FMG-021 MAIN VERIFIED -> FMG-022 CLAIMED - 2026-09-30

FMG-021 Workspace Checkpoint Capture is DONE / MAIN VERIFIED.
- PR #40 merged to main as `12874be49a3bc8eaacdeb0dfb2aea33eb9ac087e`.
- Exact-head `1bfc56a75a433603faff087025b1fa38766054d1`: push Verify `36696693545` SUCCESS and PR Verify `36697495870` SUCCESS.
- Merged-main Verify run `36698092398`: SUCCESS on macOS, Windows x64 and Windows ARM64.
- FMG-022 Checkpoint Restore Transaction is CLAIMED / ACTIVE on branch `chatgpt/FMG-022-checkpoint-restore`.
- Dependencies FMG-021, FMG-008, FMG-009, FMG-016 are all DONE / MAIN VERIFIED.
NEXT_EXACT_ACTION: deep-read the existing WorkspaceCheckpointService/manifest format plus Mutation Guard, apply_edits/versioned mutation, quarantine restore transaction and SourceStateRef/Git primitives; implement restore plan + divergence guard + mandatory rollback checkpoint + staged/unstaged/untracked/index restore + verification/rollback terminal states. Do not begin FMG-023 before FMG-022 MAIN VERIFIED.

## FMG-022 local verification checkpoint - 2026-09-30

State: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING on `chatgpt/FMG-022-checkpoint-restore`.
Local proof: state + checkpoint-restore contract PASS; catalog 1.13.0 / 46 tools + parity PASS; targeted Windows restore 29 assertions PASS; Windows Release 0 warnings/errors; full Windows runtime 955 assertions PASS; macOS runtime/build shell syntax PASS.
Evidence: `docs/evidence/FMG-022_CHECKPOINT_RESTORE_TRANSACTION_EVIDENCE.md`.
NEXT_EXACT_ACTION: inspect latest `fork/main` and remote FMG-022 branch/PR before commit/push; sync only if needed, then exact-head native Verify -> scoped review -> PR/merge -> merged-main Verify -> FMG-022 MAIN VERIFIED -> claim FMG-023.

## Final local diff-hygiene checkpoint

Before commit, scoped diff review found one literal NUL byte in `WorkspaceCheckpointGit.cs`, causing Git to classify the C# source as binary. The source byte was normalized to the canonical C# escape `\0` without changing runtime semantics. Post-fix proof: `git diff --check` PASS; Windows test-project build PASS 0 warnings/errors; targeted checkpoint restore PASS 29 assertions.

## Native Verify attempt 1 remediation - 2026-09-30

Run `36709124346` on `381b5eacf32942df54337c003239f84fc14c5728`: Windows ARM64 passed; macOS product static verification and catalog passed, then Swift integration compilation failed only because one FMG-022 test assertion executed throwing `String(contentsOf:)` inside non-throwing `precondition` autoclosure. Product restore code was not implicated.

Remediation is test-only: the throwing file read is hoisted into `crDryTrackedText` before `precondition`. Local affected-stage proof: zero remaining `precondition(try String(contentsOf:))` occurrences, Swift shell syntax PASS, checkpoint-restore contract PASS, `git diff --check` PASS.

NEXT_EXACT_ACTION: commit/push this test-only remediation and require a new exact-head native Verify on macOS / Windows x64 / Windows ARM64.

## FMG-022 native Verify attempt 2 remediation - 2026-10-01

Run `36709652846` on exact head `4ddd8ab8afaab916f089e9cafd132927cc596613`: Windows x64 SUCCESS; Windows ARM64 SUCCESS; macOS static/catalog PASS, then Swift runtime reached FMG-022 restore fixtures but the server-test process did not open the four HTTP listeners within the existing 90-second pre-listener watchdog.

Root cause is test-harness startup budget, not checkpoint-restore product semantics: the server-test executable intentionally runs repository-intelligence/query, PTY, checkpoint-capture and transactional checkpoint-restore native fixtures before constructing/listening on the HTTP servers. FMG-021/022 materially increased legitimate pre-listener fixture time beyond the stale 90-second watchdog.

Remediation is test-harness only:
- pass SERVER_PID into the readiness probe;
- extend only the pre-listener fixture watchdog from 90s to 240s;
- fail fast if the server-test process exits before listeners become ready;
- keep all FileMCP product timeouts unchanged.

Affected-stage local proof: project-state contract PASS; checkpoint-restore contract PASS (catalog 1.13.0 / 46 tools / transactional parity); Swift shell syntax PASS; `git diff --check` PASS.

NEXT_EXACT_ACTION: commit/push this test-only watchdog remediation, require a new exact-head native Verify on macOS / Windows x64 / Windows ARM64, then scoped review -> PR/merge -> merged-main Verify -> FMG-022 DONE / MAIN VERIFIED -> claim FMG-023.

## FMG-022 + drive-root hotfix closure / FMG-023 claim - 2026-10-02

FMG-022 Checkpoint Restore Transaction is DONE / MAIN VERIFIED.
- PR #41 merged as `f3e4254c5a32d48d95b28372d0eff56880aeb5f5`.
- Exact-head push Verify `36750333286`: SUCCESS.
- Merged-main Verify `36986797605`: SUCCESS on macOS / Windows x64 / Windows ARM64.

Drive-root `project_context` hotfix is MAIN VERIFIED.
- PR #42 exact head `aa681c99bddd145bcbba9a0b62d6d566eef9691c`.
- Push Verify `36988088942`: SUCCESS.
- PR Verify `36991043837`: SUCCESS.
- Merge main `9b6162fd9c79e755922f2865efef6b1eefc6402e`.
- Merged-main Verify `36991621549`: SUCCESS.
- Live D:\ FileMCP runtime PID 16240 remains active from the already-swapped verified binary.

FMG-023 Execution Backend Interface is CLAIMED / ACTIVE on `chatgpt/FMG-023-execution-backend`, based directly on merged main `9b6162fd9c79e755922f2865efef6b1eefc6402e`.
NEXT_EXACT_ACTION: implement only the frozen process+PTY backend abstraction: IExecutionBackend + HostExecutionBackend, backend identity/version/capabilities, workspace mapping, environment mediation hooks, health/lifecycle/cleanup and evidence backend identity. File/Git tools remain host-native. FMG-024 remains blocked until FMG-023 MAIN VERIFIED.

## FMG-023 resume checkpoint - 2026-10-02

Runtime recovery classification: PASS for the previously interrupted full Windows runtime stage; it was not restarted.
- prior wrapper result marker: exit code 0
- log completed windows-core-tests: ok (974 assertions)
- FMG-023 targeted execution-backend suite had already passed 18 assertions
- existing PTY-only suite had already passed 23 assertions
- new static execution-backend contract had already passed
- live FileMCP connector process remains PID 16240 from the verified FMG013-ready binary and was not restarted

FMG-023 remains ACTIVE on chatgpt/FMG-023-execution-backend.
Checkpoint now PASS: Windows full runtime regression.
NEXT_EXACT_ACTION: run only remaining affected non-runtime gates (Release/warnings-as-errors + catalog/parity + exec/PTY/evidence/execution-backend contracts), inspect scoped diff, then commit/push exact candidate for native macOS/Windows x64/Windows ARM64 Verify. Do not rerun the 974-assertion Windows runtime unless source changes after this checkpoint.


## FMG-023 local verification - 2026-10-02

State: LOCAL VERIFIED / NATIVE CI PENDING on chatgpt/FMG-023-execution-backend.
Local proof: Windows Release solution build with warnings-as-errors PASS (0 warnings / 0 errors using existing restore assets); full Windows runtime 975 assertions PASS; targeted execution-backend 19 assertions PASS; catalog/parity + exec_process + PTY + evidence + execution-backend contracts PASS; diff check PASS.
Scoped review PASS after repairing one forward-compatibility issue: backend descriptor modes are bounded generic identifiers so FMG-024 Docker can supply container-mounted/network/resource modes without weakening host defaults.
Evidence: docs/evidence/FMG-023_EXECUTION_BACKEND_INTERFACE_EVIDENCE.md.
NEXT_EXACT_ACTION: commit/push exact FMG-023 candidate, require native Verify on macOS + Windows x64 + Windows ARM64, then scoped exact-head review -> PR/merge -> merged-main Verify -> FMG-023 MAIN VERIFIED -> claim FMG-024.


## FMG-023 exact-head native verification / review - 2026-10-02

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.
Candidate: fe05746759592d3ef3354e92b4969b9f246fdb41.
Verify run 36996922253: SUCCESS on macOS / Windows x64 / native Windows ARM64.
Scoped review: PASS; no P0/P1 FMG-023 finding remains.
NEXT_EXACT_ACTION: commit/push evidence-state closure head, require native Verify all three lanes, then PR/merge -> merged-main Verify -> FMG-023 DONE / MAIN VERIFIED -> claim FMG-024.


## FMG-023 closure / FMG-024 claim - 2026-10-02

FMG-023 Execution Backend Interface is DONE / MAIN VERIFIED.
- PR #43 head `ba5cf3ebdf91a7c3eb34263948d7a99729ba6d6f`; PR Verify `36998198466`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Merge commit `d71fbc08e9e08f65c59ce5e05649e0dc629f7935`.
- Merged-main Verify `36998939456`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Existing live FileMCP connector PID 16240 was not restarted.

FMG-024 Optional Docker Isolated Backend is CLAIMED / ACTIVE on `chatgpt/FMG-024-docker-backend`, based directly on verified main `d71fbc08e9e08f65c59ce5e05649e0dc629f7935`.
NEXT_EXACT_ACTION: deep-read FMG-023 backend + policy/config/artifact/evidence primitives; probe Docker availability read-only; implement only frozen FMG-024 scope. Docker remains optional, HostExecutionBackend remains the startup/default fallback.


## FMG-024 interrupted-work recovery - 2026-10-02

Recovery classification: INTERRUPTED, not restarted from task start.
A forced Git index refresh exposed three real source modifications that normal status initially missed because worktree stat metadata was stale: windows/src/FileMCP.Core/EvidenceStore.cs, ExecutionBackend.cs and LocalTools.cs. These partial changes extend execution-backend evidence identity/metadata for FMG-024 but were incomplete: EvidenceCoordinator still called the old EvidenceBackendId API and the Windows core did not compile. Docker CLI 29.6.2 is installed locally, but the Docker daemon is currently unavailable (local npipe endpoint missing).
Checkpoint preserved: FMG-023 remains DONE / MAIN VERIFIED; FMG-024 remains ACTIVE. Resume the partial evidence-identity work, complete cross-platform parity, then implement the frozen Docker backend. Do not discard or restart these partial changes.


## FMG-024 local affected-gate checkpoint - 2026-10-02

State: ACTIVE / LOCAL AFFECTED GATES PASS / NATIVE VERIFY PENDING on `chatgpt/FMG-024-docker-backend`.

Implemented scope currently includes: optional server-owned Docker process+PTY backend; digest-pinned local image allowlist; workspace-only bind mount revalidation; non-root user; read-only rootfs; cap-drop ALL; no-new-privileges; CPU/memory/PID caps; network-none default; explicit network policy gate; no hidden image pull (`--pull never`); image healthcheck disabled; local-only Docker daemon authority; request Docker-control environment override rejection; owned-label lifecycle/orphan cleanup; evidence backend/image/resource/network metadata; Windows/macOS config/runtime wiring; host backend remains default when Docker mode is not selected.

Local proof:
- Windows solution Release warnings-as-errors: PASS, 0 warnings / 0 errors.
- FMG-024 Windows targeted runtime: 21 assertions PASS.
- catalog/parity/exec_process/PTY/evidence/execution-backend/docker-backend contracts: PASS; catalog unchanged 1.13.0 / 46 tools.
- Docker CLI 29.6.2 is installed; local Docker daemon is currently unavailable, so no claim of live container-engine success is made.
- Full Windows runtime attempt reached unrelated pre-existing desktop single-instance test and timed out; isolated retry reproduced that unrelated timeout. FMG-024-specific gates remain PASS. Native Verify is the next authoritative cross-platform/full-regression gate.

NEXT_EXACT_ACTION: complete state contract + scoped diff review, commit/push the exact FMG-024 candidate, require native Verify on macOS / Windows x64 / native Windows ARM64, repair only failed stages, then exact-head review -> PR/merge -> merged-main Verify -> FMG-024 MAIN VERIFIED -> claim FMG-025.


## FMG-024 native Verify attempt 1 remediation - 2026-10-03

Verify run `37042165795` on `8fe0217e941e6b3c78e4f7ec487ad03e1733d745`: Windows x64 SUCCESS including full integration/build/smoke; native Windows ARM64 SUCCESS. macOS failed only at warnings-as-errors static typecheck because the `LocalTools` call placed `dockerExecutionBackend:` before the earlier-declared `skillRegistry:` argument. No Docker behavior/runtime assertion failed.

Remediation is macOS wiring-only: reorder those two named arguments to match the initializer declaration. Preserve all Windows PASS checkpoints.
NEXT_EXACT_ACTION: commit/push this macOS-only remediation and require fresh native Verify; repair only any newly failed stage.


## FMG-024 native Verify attempt 2 remediation - 2026-10-03

Verify run `37042897103` on `a5e55248857f2c9e65bb222acbf8a1c8202b4d13`: Windows x64 SUCCESS including full integration/build/smoke/resources; native Windows ARM64 SUCCESS. macOS failed only at warnings-as-errors static typecheck because `LocalMCPConfiguration` was missing its struct-closing brace after the initializer. No Docker runtime/contract failure occurred.

Remediation is macOS syntax-only: restore the missing struct-closing brace. Preserve all Windows PASS checkpoints and do not rerun local Windows stages.
NEXT_EXACT_ACTION: commit/push this macOS syntax-only remediation and require fresh native Verify; repair only any newly failed stage.


## FMG-024 exact-head native verification / scoped review - 2026-10-03

FMG-024 Optional Docker Isolated Backend is EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / LIVE DOCKER ENVIRONMENT-BLOCKED.
- Exact candidate: `557ddaa157f5897bf3d5c5be8e6a1f498fbc2200`.
- Verify run `37043531330`: SUCCESS on macOS / Windows x64 / native Windows ARM64; Docker backend contract and full native build/integration gates PASS.
- Canonical catalog unchanged: `1.13.0` / 46 tools / SHA-256 `30ecf017a35db8ebeb6344786576664035f504cae8996a0c4a223df797254364`.
- Scoped security review: PASS; no P0/P1 finding remains. Host backend remains default, Docker selection is local/server-owned, image is digest-pinned and local-allowlisted, network-none default is policy-gated, workspace-only bind and resource/security controls are verified, Docker socket/privileged mode are absent, request Docker-control overrides fail closed, and cleanup does not delete containers failing ownership/workspace label checks.
- Docker Desktop/engine semantics and limitations are documented in `docs/evidence/FMG-024_OPTIONAL_DOCKER_ISOLATED_BACKEND_EVIDENCE.md`.
- Local Docker CLI 29.6.2 is present but the daemon was unavailable during verification, so live container-engine success is explicitly NOT claimed; this is allowed by the frozen FMG-024 availability rule and must remain environment-blocked until a real engine proof exists.

NEXT_EXACT_ACTION: commit/push the evidence/state-only FMG-024 closure head, require native Verify on that exact head, then PR/merge -> merged-main Verify -> mark FMG-024 DONE / MAIN VERIFIED -> claim FMG-025 Advanced Cross-Platform Adversarial Gate.


## FMG-024 MAIN VERIFIED / FMG-025 claimed - 2026-10-03

FMG-024 Optional Docker Isolated Backend is DONE / MAIN VERIFIED.
- Closure head: `d0495da7f0d70e1fc14e93e928ba52a2d9ffee89`.
- PR #44 Verify `37094506166`: SUCCESS after rerunning only the transiently failed Windows x64 job; macOS / Windows x64 / native Windows ARM64 all PASS.
- PR #44 merged as `2bd859a966f9f49075ffc7d0a544154cb5d76498`.
- Merged-main Verify `37095113136`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Live Docker engine proof remains explicitly environment-blocked because the local daemon is unavailable; no fake live PASS is claimed.

FMG-025 Advanced Cross-Platform Adversarial Gate is CLAIMED / ACTIVE on `chatgpt/FMG-025-adversarial-gate` from merged main `2bd859a966f9f49075ffc7d0a544154cb5d76498`.

NEXT_EXACT_ACTION: audit existing advanced negative/runtime coverage against the frozen FMG-025 scope, add the missing cross-platform adversarial gate and only the missing negative tests, run affected local gates, record evidence/state, then exact-head native Verify -> review -> PR/merge -> merged-main Verify -> FMG-025 MAIN VERIFIED -> claim FMG-026.


## FMG-024 closure / FMG-025 claim - 2026-10-03

FMG-024 Optional Docker Isolated Backend is DONE / MAIN VERIFIED.
- PR #44 head `d0495da7f0d70e1fc14e93e928ba52a2d9ffee89` merged as `2bd859a966f9f49075ffc7d0a544154cb5d76498`.
- Exact-head push Verify `37094158297`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR Verify `37094506166`: final SUCCESS on macOS / Windows x64 / native Windows ARM64. The first Windows x64 integration attempt hit the pre-existing bounded-output timing/assertion flake; rerun on the identical head passed without source changes, so no unrelated code change was introduced.
- Merged-main Verify `37095113136`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Live Docker engine proof remains explicitly ENVIRONMENT-BLOCKED because the local Docker daemon is unavailable; no fake live PASS is claimed. The frozen availability rule permits FMG-024 closure with this limitation recorded.
- Evidence: `docs/evidence/FMG-024_OPTIONAL_DOCKER_ISOLATED_BACKEND_EVIDENCE.md`.
- Existing live FileMCP connector PID 16240 was not restarted.

FMG-025 Advanced Cross-Platform Adversarial Gate is CLAIMED / ACTIVE on `chatgpt/FMG-025-adversarial-gate`, based directly on verified main `2bd859a966f9f49075ffc7d0a544154cb5d76498`.
NEXT_EXACT_ACTION: inventory the frozen FMG-014..024 advanced surfaces and existing negative/contract suites, build the FMG-025 adversarial matrix, run only the required cross-platform/privacy/security/parity gates, add missing adversarial coverage if a real gap is found, preserve live Docker as environment-blocked unless an engine becomes available, then evidence/review/commit/PR/merge/main-verify before FMG-026.


## FMG-025 local adversarial gate - 2026-10-03

FMG-025 inventory found no production/runtime implementation gap. Existing FMG-014..024 negative suites already cover the frozen advanced capabilities; the missing task-level gap was an aggregate CI-enforced gate proving complete cross-platform wiring plus privacy/foundation invariants.
- Added `tests/test_advanced_adversarial_gate.ps1`.
- Wired the aggregate gate exactly once into Windows x64 Verify and once into native Windows ARM64 Verify; macOS remains independently verified by native Swift typecheck/runtime/build.
- Local aggregate gate: PASS.
- `git diff --check`: PASS.
- Evidence: `docs/evidence/FMG-025_ADVANCED_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.
- Production/runtime implementation files changed: none.

NEXT_EXACT_ACTION: commit the FMG-025 gate/evidence/state candidate, push the exact head, require native Verify on macOS / Windows x64 / native Windows ARM64, repair only a real failed stage, then exact-head review -> PR/merge -> merged-main Verify -> FMG-025 DONE / MAIN VERIFIED -> claim FMG-026.


## FMG-025 exact-head verified / review pass - 2026-10-03

FMG-025 candidate head `a4098e2c72fa3ba92f1fcff4898d726ed42aa614` is EXACT-HEAD NATIVE VERIFIED.
- Push Verify `37096296869`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- New aggregate adversarial gate: PASS in Windows x64 and native Windows ARM64 jobs.
- macOS native static verification, integration runtime, app build and bundled-resource verification: PASS.
- Exact-head diff review against `fork/main`: PASS; no Windows/macOS production/runtime implementation file changed, no tool-catalog drift, no privacy/security weakening, no duplicate advanced runtime-suite execution introduced.
- Evidence updated: `docs/evidence/FMG-025_ADVANCED_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.

NEXT_EXACT_ACTION: commit/push the evidence/state-only FMG-025 closure head, require native Verify on that exact closure head, then reuse/create exactly one PR -> require green PR verification -> merge with expected-head guard -> merged-main Verify -> FMG-025 DONE / MAIN VERIFIED -> claim FMG-026.


## FMG-025 MAIN VERIFIED / FMG-026 claim - 2026-10-03

FMG-025 Advanced Cross-Platform Adversarial Gate is DONE / MAIN VERIFIED.
- Closure head `48cb3f0a6b9fee6a935c47a18a03ec79a26793bd`: push Verify `37096948452` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #45 Verify `37106541799`: final SUCCESS on all three lanes. Initial Windows x64 runtime attempt hit a transient `runtime-dynamic-health.health-url` file-sharing race; only the failed Windows job was rerun on the identical head and passed without source changes.
- PR #45 merged with expected-head guard as `59ee366f504160b2132355e3d2dae9ce3b524646`.
- Merged-main Verify `37107116084`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Evidence: `docs/evidence/FMG-025_ADVANCED_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.

FMG-026 Complete Regression + Live Advanced Proof is CLAIMED / ACTIVE on `chatgpt/FMG-026-complete-regression`, based directly on verified main `59ee366f504160b2132355e3d2dae9ce3b524646`.
Existing live FileMCP/tunnel processes are preserved; do not restart them merely for FMG-026 discovery.

NEXT_EXACT_ACTION: inventory existing FMG-026/final-regression/live-proof scripts and prior durable evidence; map each frozen FMG-026 scope item to an existing executable proof, identify only real coverage gaps, then execute the required final complete regression and live advanced proof without duplicating already-running processes. Optional Docker live proof remains subject to the frozen availability rule.


## FMG-026 pre-restart regression/live-proof checkpoint - 2026-10-03

FMG-026 remains CLAIMED / ACTIVE on `chatgpt/FMG-026-complete-regression`.
- Resume classification: INTERRUPTED at claim/inventory; no FMG-026 test/build process was alive, so work resumed from the durable inventory checkpoint rather than restarting prior tasks.
- Full regression/package authority: `.github/workflows/verify.yml` already covers original runtime + FMG-001..025 contracts, Windows x64/native ARM64 build/package/smoke, and native macOS runtime/build/resource verification.
- Existing FileMCP PID `16240` plus tunnel PIDs `10896` / `15204` were preserved.
- Tunnel discovery: `filemcp` and `filemcp-e` `/healthz=live`, `/readyz=ready`; no restart performed.
- Live basic FileMCP proof: correlation + file write/read + versioned apply_edits + Git status + exec_process + project_context + evidence dispatch PASS; temp proof file deleted and worktree restored clean.
- Canonical source catalog: 46 tools, SHA-256 `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`.
- Current ChatGPT/FileMCP connector discovery: 22 tools. Advanced batch/quarantine/edit-adapter/repo-intelligence/checkpoint/PTY/run-command surfaces are not yet discoverable, so live advanced proof is BLOCKED rather than falsely marked PASS.
- Prepared `dist/windows-x64/FileMCP-FMG026-ready/FileMCP.exe`, SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`, with bundled canonical 46-tool catalog matching source.
- Prepared archive `dist/FileMCP-FMG026-ready-windows-x64.zip`, SHA-256 `db0b0d8e31362d29e5e41554f305c84881b560fd1cdf39cabe976bfd2a0ad9aa`.
- Docker CLI exists but daemon is unavailable; optional live Docker proof remains ENVIRONMENT BLOCKED per frozen rule.
- Evidence: `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.

NEXT_EXACT_ACTION: commit/push this FMG-026 checkpoint and require exact-head native Verify as the full regression/package gate. Repair only an actual failed stage. When native Verify is green, preserve that PASS and replace the active desktop with `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, reconnect/rediscover the canonical 46-tool connector, then resume LIVE ADVANCED PROOF ONLY; do not rerun the green regression.


## FMG-026 exact-head native regression PASS / live advanced blocker - 2026-10-03

- Exact head verified: `21d0c6ed05a749be363b108a7a965a7f0deaef9e`.
- Push Verify `37109212534`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Full contract/runtime/package/smoke regression is now a durable PASS checkpoint and must not be rerun merely because the desktop connector is restarted.
- Remaining FMG-026 blocker is only live advanced connector proof: active desktop PID `16240` serves the stale 22-tool connector while canonical source/FMG026-ready contains 46 tools.
- FMG026-ready executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`.

NEXT_EXACT_ACTION: USER-RUNTIME HANDOFF ONLY — close the currently running FileMCP desktop normally, launch `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, then reconnect/resume ChatGPT with FileMCP. On resume, first verify the new process/hash and that connector discovery exposes all 46 canonical tools; then run LIVE ADVANCED PROOF ONLY. Do NOT rerun Verify `37109212534` or any already-PASS regression stage.


## FMG-026 reconnect blocker - 2026-10-03

Post-user-restart verification did NOT replace the live desktop runtime.
- Git branch: `chatgpt/FMG-026-complete-regression`.
- Local HEAD: `b702e66fdd43c2c72db82d6f97c03bdc77e3e706`.
- Worktree: clean.
- Exact-head native Verify `37109212534` remains preserved PASS on macOS / Windows x64 / native Windows ARM64; DO NOT rerun it.
- Active FileMCP remains PID `16240` at `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`, SHA-256 `69c86f752321ef318c4ddd27dd566a9883a98fea774cd5fc021ec72b92117a7d`.
- Current connector still discovers 22 tools, not the canonical 46 tools.
- FMG026-ready binary remains prepared at `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`.
- Attempt to launch an out-of-process helper that would stop the old FileMCP and start FMG026-ready was blocked by the OpenAI safety layer; no process was killed or restarted.

BLOCKER: the old FileMCP desktop instance must be exited manually before launching FMG026-ready. Opening the new EXE while PID `16240` is alive triggers single-instance behavior and leaves the old runtime active.

NEXT_EXACT_ACTION: manually exit the currently running FileMCP desktop/tray instance so PID `16240` disappears, then launch `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`, reconnect this FileMCP connector, and resume LIVE ADVANCED PROOF ONLY. Do not rerun Verify `37109212534`.


## FMG-026 live advanced proof PASS / GitHub closure pending - 2026-10-03

FMG-026 remains ACTIVE on `chatgpt/FMG-026-complete-regression`, but the runtime/deployment blocker and live advanced proof are now resolved.
- Active runtime: PID `17860`, `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`.
- Runtime SHA-256: `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`.
- Both child tunnel profiles are live/ready and forward to local MCP ports `8008` / `8010`.
- Canonical catalog remains `1.13.0` / `46` tools / SHA-256 `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`.
- Effective current policy surface is intentionally `45/46`: custom/high allows direct execution and all effects, but `CustomPolicyAllowShell=false`, so only `run_command` is hidden. Do not enable shell merely to reach 46.
- Exact-head native full regression/package Verify `37109212534` remains frozen PASS on macOS / Windows x64 / native Windows ARM64. DO NOT rerun it merely for closure.
- Prior live basic file/Git/direct-exec/project-context/evidence proof remains PASS.
- LIVE ADVANCED PROOF now PASS: batch + ContentRef; quarantine delete/list/get/restore; search/replace + unified-diff adapters; repo-intelligence facade on bounded Git fixture; checkpoint capture/list/get/dry-run restore/restore/delete; native Windows ConPTY start/list/resize/write/read/signal/stop.
- Full FileMCP repo `repo_map` first uncached request returned one upstream `502`; bounded live fixture proved the same handler/query facade works. Existing repository-intelligence contracts/runtime remain covered by frozen full regression. No production defect or repair is claimed from that large-repo first-build transport timeout.
- Temporary proof fixture was fully cleaned up; no source/product implementation file changed.
- Optional Docker live engine proof remains explicitly ENVIRONMENT BLOCKED because the daemon is unavailable.
- Evidence: `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.

STATUS: **PASS_LOCAL / LIVE_ADVANCED_PASS / GITHUB_CLOSURE_PENDING**.

NEXT_EXACT_ACTION: run project-state contract + `git diff --check` + exact closure diff review; commit only FMG-026 evidence/state closure files; inspect real remote branch/PR state before side effects; push exact closure candidate; require exact-head GitHub Verify/checks; review/create exactly one PR targeting `main`; merge exact reviewed head; require merged-main Verify; only then record `COMPLETE_UPGRADE_MAIN_VERIFIED` / FMG-026 DONE.

DO_NOT_REPEAT: do not rerun Verify `37109212534`; do not restart PID `17860`; do not enable `run_command` shell authority; do not repeat live advanced proof unless a material runtime/source change invalidates this checkpoint.


## FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED / state-sync pending - 2026-10-03

Primary FMG-026 technical closure is verified on real post-merge `main`.
- Primary closure head: `e39877808b3fb0394b5b5a2608d6489ad6d8404f`.
- Push Verify `37120899485`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #47 Verify `37121297945`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #47 merged with expected-head guard.
- Resulting main commit: `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`.
- GitHub emitted the PR merged event but no main PushEvent/check suite for this merge. A verification-only ref with zero commit/tree delta was created pointing exactly to the actual main commit: `verify/FMG-026-main-03cf7c0`.
- Exact-main-commit Verify `37121899760`, `headSha=03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- There was no main-branch workflow run for this merge; do not claim one.
- Durable evidence: `docs/evidence/COMPLETE_UPGRADE_MAIN_VERIFIED.md` and `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.
- Optional Docker live engine proof remains ENVIRONMENT BLOCKED under the frozen availability rule; no fake live Docker PASS.

Technical result: `FMG-026 = DONE / MAIN VERIFIED`; FileMCP complete-upgrade core = `COMPLETE_UPGRADE_MAIN_VERIFIED` at `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`.

CURRENT STATE-SYNC: ACTIVE on `state/FMG-026-main-verified`, based exactly on verified main `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`. This state-sync itself must complete GitHub push -> PR -> review -> merge -> exact resulting-main verification before dependent FMUX work may be claimed.

NEXT_EXACT_ACTION: finish the state-sync diff, project-state contract and diff review; commit/push this state-only closure; exact-head Verify; one PR to `main`; review/merge with head guard; verify the exact resulting main commit. Then re-evaluate the frozen FMUX graph and claim the lowest dependency-ready task (current graph indicates FMUX-011).

DO_NOT_REPEAT: do not rerun FMG-026 live proof or Verify `37109212534`; do not restart correct runtime PID `17860`; do not enable shell authority merely to expose `run_command`.

## FMG-026 state-sync MAIN VERIFIED / FMUX-011 claimed - 2026-10-03

Repo/runtime recovery proved the governance closure completed after the prior stream ended:
- PR #48 state-sync head `552edec938379d309d26a3eab2b0005f0cefcdeb` passed push Verify `37134381070` and PR Verify `37134966010` on macOS / Windows x64 / native Windows ARM64;
- PR #48 merged into actual `main` commit `5a5abed27e523dac4f62c27e8808c3bb03a6d874`;
- merged-main PushEvent Verify `37135393780` completed SUCCESS on all three native lanes;
- `fork/main` points exactly to `5a5abed27e523dac4f62c27e8808c3bb03a6d874`;
- correct FMG026-ready runtime remains PID `17860`; do not restart it.

Therefore the FMG-026 governance state-sync is DONE / MAIN VERIFIED and dependency authority permits the next FMUX task.

FMUX-011 Repository Intelligence is CLAIMED / ACTIVE on `chatgpt/FMUX-011-repository-intelligence`, created directly from verified `fork/main=5a5abed27e523dac4f62c27e8808c3bb03a6d874`. Side-effect guard found no existing FMUX-011 branch, PR or commit.

Frozen scope: Repository page only; repository summary; observed `repo_map`, `symbol_search`, `related_files`; provider/version/completeness prominently shown; bounded metadata-only presentation; never persist/log raw source or raw ContentRef tokens; repository intelligence never grants authority or claims exhaustive symbol truth.

EXACT-HEAD CHECKPOINT: FMUX-011 candidate `8c84912c5280fb599ad91632f5458d8b7a42f2a0` is NATIVE VERIFIED and scoped review PASS. Push Verify `37138794626` succeeded on macOS / Windows x64 / native Windows ARM64, including native integration/build/package/smoke gates and the FMUX Repository Intelligence presentation contract. No P0/P1 remains in scope. Runtime PID `17860` remains correct and was not restarted.

FMUX-011 FINAL: DONE / MAIN VERIFIED. Closure head `0b9c08f052418a20f48e4b688cc41dc93eb21117` passed push Verify `37139506323`; PR #49 exact-head Verify `37139999329` passed all three native lanes; PR #49 merged as `d378faa0807435be7ca21eff1c573518779c5dd4`; merged-main Verify `37140380944` SUCCESS on macOS / Windows x64 / native Windows ARM64.

FMUX-012 Terminal / PTY is ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-012-terminal-pty`, based directly on verified `fork/main=d378faa0807435be7ca21eff1c573518779c5dd4`. Dependencies FMUX-002, FMUX-003 and FMG-020 are DONE / MAIN VERIFIED. Runtime PID `17860` remains correct and was not restarted.

Frozen scope: session list; active terminal; bounded output; stop/signal/resize controls; backend/policy/session status. UI must consume real FMG-020 structured PTY truth only, preserve bounded output, never persist/log secret-like stdin or raw PTY bytes beyond existing runtime semantics, never invent resume after restart, and never expand authority.

Local FMUX-012 evidence: Terminal contract PASS; app-shell PASS; presentation PASS; Repository regression PASS; persistent PTY contract PASS; project-state contract PASS; `git diff --check` PASS; Windows Release build for the FMUX-012 Windows source checkpoint PASS with 0 warnings / 0 errors. Evidence: `docs/evidence/FMUX-012_TERMINAL_PTY_UX_EVIDENCE.md`.

Exact-head attempt 1: candidate `bae6bea5cf23a2577cd474068472de752cb1944e`, Verify `37175574357` = FAIL. Windows x64 + native ARM64 failed only at stale FMUX-011 lifecycle assertion; macOS failed integration compile because `withPresentationServer` captured non-escaping `body`. Both causes were repaired without restarting runtime.

Exact-head attempt 2: fix checkpoint `edd996bd43642e8c5399a90ca14cb109db858fd1`, push Verify `37176690710` = SUCCESS on macOS / Windows x64 / native Windows ARM64. Scoped review PASS: presentation bridge allowlist is only `pty_list`, `pty_read`, `pty_resize`, `pty_signal`, `pty_stop`; no `pty_start`/`pty_write` presentation authority; bounded output remains 16 KiB/read and 64 KiB/display; PTY bytes are not copied into diagnostics/activity; `presentation_grants_authority=false`; no P0/P1 remains. Runtime PID `17860` remains unchanged.

NEXT_EXACT_ACTION: commit/push the evidence-state-only FMUX-012 closure head, require exact-head Verify on that closure SHA, then create/review exactly one PR to `main` -> merge exact reviewed head with guard -> verify the exact resulting `main`. Do not rerun successful Verify `37176690710`, FMUX-011/FMG-020 proof, or restart correct runtime PID `17860`.


FMUX-012 FINAL: DONE / MAIN VERIFIED. Closure head `feb365864c32a3f7bb297bc4bba59c6171a73a9d` passed push Verify `37177215836` and PR #50 exact-head Verify `37177568204` on macOS / Windows x64 / native Windows ARM64. PR #50 merged as `38b20e633957ea6c279b110dac54072b29df14a6`; merged-main Verify `37177832479` SUCCESS on the exact resulting main commit across all three native lanes. Runtime PID `17860` remained correct and was not restarted.

State-sync checkpoint: current branch `state/FMUX-012-main-verified` is based directly on verified main `38b20e633957ea6c279b110dac54072b29df14a6`. FMUX-013 and FMUX-015 core dependencies are all DONE / MAIN VERIFIED; after this state-sync itself reaches MAIN VERIFIED, the dependency-valid lowest-numbered next task is FMUX-013 Recovery.

NEXT_EXACT_ACTION: complete this FMUX-012 state-only closure through commit -> push -> exact-head Verify -> reviewed PR -> merge -> merged-main Verify. Only after the state-sync is MAIN VERIFIED, claim FMUX-013 Recovery from the resulting verified `main`; do not rerun FMUX-012 implementation proof or restart correct runtime PID `17860`.


State-sync attempt 1: head `6a6d247f774a379426dc32c9e7022477d888ed95`, push Verify `37183274280` completed FAILURE. macOS lane SUCCESS. Windows x64 and native ARM64 each failed only `Verify FMUX Terminal / PTY presentation contract` because the historical FMUX-012 contract accepted only active lifecycle states after the graph correctly moved FMUX-012 to `DONE / MAIN VERIFIED`. The contract is now scoped to the FMUX-012 section and accepts `DONE / MAIN VERIFIED`; targeted `test_fmux_terminal_pty_contract.ps1`, project-state contract and `git diff --check` PASS locally. No product/runtime source was changed and PID `17860` was not restarted.

NEXT_EXACT_ACTION: commit the state-sync lifecycle-contract fix -> side-effect guard remote branch still at `6a6d247f774a379426dc32c9e7022477d888ed95` and no PR -> push new exact head -> require one new three-lane Verify -> reviewed state-sync PR -> merge -> merged-main Verify -> then claim FMUX-013 Recovery.


State-sync attempt 2 checkpoint: fix head `ad199846fd2d7fe50311c7965f11ca88ddda0999` is EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS. Push Verify `37183856103` completed SUCCESS on macOS / Windows x64 / native Windows ARM64. Review confirms the only behavioral change is the FMUX-012 lifecycle contract accepting `DONE / MAIN VERIFIED` after closure; no product/runtime authority changed. Runtime PID `17860` remains correct and was not restarted.

NEXT_EXACT_ACTION: commit/push this evidence-state-only checkpoint as the final state-sync closure head -> require exact-head three-lane Verify on that new closure SHA -> create/review exactly one PR to `main` -> merge exact reviewed head -> verify exact resulting `main`; only then claim FMUX-013 Recovery.


FMUX-012 governance state-sync: DONE / MAIN VERIFIED. PR #51 head `35420f96965ad46bec61a3e804800fcbe989ce13` passed PR Verify `37185895914`; merged as `dad103c569cbfc6d68b343445287152013c6f29e`; merged-main Verify `37186288521` SUCCESS on macOS / Windows x64 / native Windows ARM64.

FMUX-013 Recovery: ACTIVE / CLAIMED on `chatgpt/FMUX-013-recovery`, based exactly on verified main `dad103c569cbfc6d68b343445287152013c6f29e`. Dependencies FMUX-002, FMUX-003, FMG-016, FMG-021 and FMG-022 are all DONE / MAIN VERIFIED. Frozen scope: quarantine, checkpoints, restore plan, rollback, partial-recovery states. Runtime PID `17860` remains correct and was not restarted.

NEXT_EXACT_ACTION: inspect existing Windows/macOS quarantine/checkpoint/restore presentation bridges and frozen Recovery UX specs; then implement the smallest truthful FMUX-013 Recovery surface without expanding runtime authority, followed by targeted contract/build evidence.


FMUX-013 local verification checkpoint: ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-013-recovery`, base `dad103c569cbfc6d68b343445287152013c6f29e`. Recovery now presents quarantine/checkpoint master-detail truth on Windows/macOS through a dedicated six-tool least-authority bridge (`quarantine_list/get/restore`, `checkpoint_list/get/restore` only). Quarantine restore is original-path-only; checkpoint restore requires a successful dry-run plan and uses `history_mode=preserve`; `partial_recovery_required` is HIGH SEVERITY and persistent across refresh.

Local gates PASS: FMUX-013 Recovery contract; app-shell contract; presentation contract; project-state contract; `git diff --check`; Verify YAML parse; Windows Release build 0 warnings / 0 errors. Windows host has no `swiftc`; exact-head GitHub macOS native Verify is mandatory. Runtime PID `17860` remains correct and was not restarted.

NEXT_EXACT_ACTION: final scoped diff review -> commit FMUX-013 candidate -> side-effect guard -> push exact head -> require GitHub Verify SUCCESS on macOS / Windows x64 / native Windows ARM64 -> then closure evidence/state, PR/review/merge and merged-main Verify. Local verification is not DONE.


FMUX-013 exact-head checkpoint: candidate `8e444cc5ffa76b0c97cb756d04b3be7620a87ccc` is EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS. GitHub Verify `37189165659` SUCCESS on macOS / Windows x64 / native Windows ARM64, including macOS typecheck/integration/build and Windows Recovery contract/build/integration/package/smoke. Forbidden UI-authority scan remains empty; runtime PID `17860` remains correct and was not restarted.

NEXT_EXACT_ACTION: commit/push evidence-state-only FMUX-013 closure head -> require exact-head three-lane Verify on the closure SHA -> create/review exactly one PR to `main` -> guarded merge -> merged-main Verify. Do not rerun successful Verify `37189165659`.
