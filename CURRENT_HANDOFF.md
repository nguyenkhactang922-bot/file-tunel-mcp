# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `chatgpt/FMG-014-artifact-contentref-store`
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
Branch: `chatgpt/FMG-009-apply-edits`

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
Branch: `chatgpt/FMG-014-artifact-contentref-store`.
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
