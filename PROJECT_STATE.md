# PROJECT STATE

Project: FileMCP
Active branch: `chatgpt/FMG-018-repository-intelligence-core`
Git SHA source of truth: resolve dynamically with git rev-parse HEAD.
Architecture law: docs/process/IDEA_CAPTURE_AND_DESIGN_LAW.md
Execution law: docs/CHATCODE_GLOBAL_MULTI_PROJECT_EXECUTION_LAW.md

## Completed

- FMR-001 PASS.
- OBS-001 through OBS-013 PASS.
- V11-001 through V11-008 PASS.
- FPA-001 PASS.
- FPA-002 PASS.
- FPA-003 PASS.
- FPA-005 PASS.
- FPA-006 PASS.
- FPA-007 PASS.
- FPA-008 PASS.
- FPA-009 PASS.

Whole-repository technical remediation: COMPLETE.

## Verified quality baseline

- Windows Release build warnings-as-errors: PASS.
- Windows runtime suite: 444 assertions PASS.
- x64 package/app smoke: PASS.
- native Windows ARM64 assurance: PASS.
- native macOS Verify: PASS.
- native Windows x64 Verify: PASS.
- native Windows ARM64 Verify: PASS.
- dependency vulnerability audit: no vulnerable packages reported.
- production release signing/notarization plumbing: VERIFIED.

## FPA-004

State: OUT-OF-SCOPE BY PRODUCT AUTHORITY for the current release target.

ADR: `docs/adr/0003-unsigned-distribution-scope.md`.
Evidence: `docs/evidence/FPA-004_SCOPE_DECISION_EVIDENCE.md`.

Current distribution target is unsigned developer/internal/direct-use distribution. Public-market signed/notarized distribution is not part of current acceptance. Existing signing/notarization plumbing remains verified and preserved as an optional future capability. No claim is made that current artifacts are signed/notarized.

If public-market signed distribution is required later, reopen FPA-004-F/G and provide real production identity plus real artifact evidence.

## V11-009

State: EXTERNAL-BLOCKED ONLY ON UPSTREAM MERGE AUTHORITY.

Technical fork-main verification is complete:
- exact verified main commit before evidence-only closure: 71bc829bb6ea0476c2325a7c4d264b4cd8dd048d;
- native Verify run 35874974993: macOS / Windows x64 / Windows ARM64 SUCCESS;
- local Windows Release build: 0 warnings / 0 errors;
- Windows runtime suite: 444 assertions PASS;
- x64/ARM64 package resource verification PASS;
- x64 packaged app smoke PASS;
- PR #2 is open, clean and mergeable at the exact verified tree.

The authenticated bot has upstream READ only. Merge API is unavailable to this account.

Evidence:
docs/evidence/V11-009_FINAL_TECHNICAL_MAIN_EVIDENCE.md

Current authoritative action is owned by tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md.
## Future architecture - ChatCMD-inspired integration

State: DESIGN-FROZEN / NOT ACTIVE IMPLEMENTATION.

ADR-0004 freezes Phase A:
- canonical tool catalog/hash;
- structured result envelope;
- structured exec_process;
- file version tokens;
- atomic versioned apply_edits;
- common budget/cursor semantics;
- metadata-only execution evidence;
- project-context digest;
- server-owned policy profiles.

Persistent PTY is deferred. Sub-agents require a separate ADR. Browser DOM automation, public tokenized MCP transport, broad task-content persistence and a Rust rewrite are rejected.

Candidate queue:
tasks/CHATCMD_INTEGRATION_CANDIDATE_QUEUE.md

No feature code was changed by the audit/design task.
## Final coding-agent gateway architecture

State: ARCHITECTURE FROZEN / IMPLEMENTATION NOT STARTED.

ADR-0005 supersedes ADR-0004 where more specific. Final Phase A graph is tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md with FMG-001 as the only root implementation task.

Design proof complete:
- source-first cross-repo audits;
- final contradiction matrix;
- final function upgrade matrix;
- security/trust model;
- execution/edit/evidence model;
- large-repo context decision;
- recovery/checkpoint decision;
- independent red-team;
- P1 blocker repairs;
- repair re-audit PASS.

Historical ADR-0005 note: the foundation architecture originally marked optional isolation, repo intelligence, checkpoint, PTY, artifact spillover and command idempotency registry as DEFER. ADR-0006 subsequently superseded that planning state for the complete current scope by resolving former DEFER items to BUILD or REJECT before implementation.

## Complete upgrade scope frozen before implementation

State: COMPLETE-SCOPE ARCHITECTURE/TASK GRAPH FROZEN / IMPLEMENTATION NOT STARTED.

ADR-0006 extends ADR-0005. Former Phase B candidates have been resolved before coding:
- BUILD: artifact/content refs, batch read/stat, quarantine restore, edit adapters, repository intelligence, PTY, checkpoint/restore, execution backend interface, optional Docker isolated backend;
- REJECT: arbitrary-command idempotency/auto-replay and previously rejected agent/browser/provider/product expansions.

`tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md` is the complete ordering authority FMG-001..FMG-026. FMG-001 is the only initial READY task. FMG-013 is foundation verification; FMG-026 is COMPLETE_UPGRADE_MAIN_VERIFIED.
## FMG-001 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-001-canonical-catalog`.
Scope: Canonical Catalog Authority only.
Canonical candidate hash: `d597f611374045825808d930f2bb0ef7e995515bb816a52ceccb47fd42a8e6aa`.
Local proof: Windows runtime 470 assertions PASS; Release build 0 warnings / 0 errors; contract/parity PASS; isolated x64+ARM64 package build PASS; packaged x64 catalog/app smoke PASS.
Evidence: `docs/evidence/FMG-001_CANONICAL_CATALOG_EVIDENCE.md`.
Main proof: merge commit `71d658131342581f14407276bcfe18164a0afa37`; Verify run `35988856441` SUCCESS across macOS, Windows x64 and Windows ARM64.
Later FMG tasks remain BLOCKED by dependency graph.

## FMG-002 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-002-structured-result-envelope`.
Depends: FMG-001 DONE / MAIN VERIFIED.
Scope: Structured Result Envelope only.
Later dependent tasks remain BLOCKED by the frozen dependency graph.

## FMG-003 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-003-server-policy`.
Candidate head: `facbd35acc1c629138556af02c300be9f12822b2`.
Merge main: `8259fd6e0d4d35b6a54498c9d91156b05d2424cc`.
Native merged-main Verify: run `36097504088` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: Windows runtime 539 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-003_SERVER_POLICY_EVIDENCE.md`.

## FMG-004 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-004-toolbudget-cursor`.
Final candidate head: `6e90b2c049e9a85ac408853c9e593a76d8617f54`.
Merge main: `9e65230a672cac533f74d6b007f2f08ce83d8687`.
Native merged-main Verify: run `36114335810` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: Windows runtime 576 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-004_TOOL_BUDGET_CURSOR_EVIDENCE.md`.

## FMG-005 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-005-exec-process`.
Final candidate head: `e7c3e1764a3bd229ac1060f628a19c5049d256cf`.
PR: #8.
Merge main: `ec4f762c811be658cf9d5a82e0300ee7e79ef2ba`.
Native merged-main Verify: run `36121843677` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: Windows runtime 611 assertions PASS; catalog/parity/exec-process contract PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-005_EXEC_PROCESS_ENVIRONMENT_AUTHORITY_EVIDENCE.md`.

## FMG-006 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-006-file-version-source-state`.
Primary candidate head: `b0e66b08f743a3e2c13c4e2c7a9f19e577900b54`.
Primary PR: #9 -> main `03365ef6051d309aa276b1322f6013eb485ae6df`.
Test-only follow-up: `406e7dbeb2e458c6ace0705b0680476ede7e3f9d`, PR #10.
Final main: `4ce571a8fd22448701cc6ad135a828c2328d12fe`.
Final merged-main native Verify: run `36164398847` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local proof: catalog/parity/FMG-006 contract PASS; Windows runtime 627 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-006_FILE_VERSION_SOURCE_STATE_EVIDENCE.md`.

## FMG-007 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-007-mutation-guard`.
Final candidate head: `2319488761c845df7be5010dca0283485a41a8e9`.
PR: #11.
Merge main: `ad78b0f75564728c7a4aa5dae218d4e79d697569`.
Native merged-main Verify: run `36167404567` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: Mutation Guard/catalog/parity/FM??G-006 prerequisite contracts PASS; Windows runtime 637 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-007_MUTATION_GUARD_EVIDENCE.md`.

## FMG-008 implementation

State: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING.
Branch: `chatgpt/FMG-008-existing-mutation-hardening`.
Depends: FMG-007, FMG-003 DONE / MAIN VERIFIED.
Scope: Harden existing `write_file`, `delete_file`, `delete_directory` mutations only.
NEXT_EXACT_ACTION: integrate expected-version + Mutation Guard + commit-time policy reauthorization/dry-run semantics while preserving existing compatibility and root/link protections. Add stale/path-swap/cancellation/delete-race/policy-removal tests. Do not begin FMG-009 before FMG-008 MAIN VERIFIED.


FMG-007 final main proof: merge `ad78b0f75564728c7a4aa5dae218d4e79d697569`; native Verify `36167404567` SUCCESS on all three platform jobs; local merged-main Windows runtime 637 assertions and Release build PASS.

## FMG-008 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-008-existing-mutation-hardening`.
Final candidate: `35ef237a0f4d32f0940491b9163a0dcbea7e6c61`.
PR: #12.
Merge main: `8a58a223814505518e581ebe79856846555cb4b4`.
Native merged-main Verify: run `36212103370` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: catalog/parity + FMG-005/FM??G-006/FM??G-007/FM??G-008 contracts PASS; Windows core 655 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-008_EXISTING_MUTATION_HARDENING_EVIDENCE.md`.

## FMG-009 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-009-apply-edits`.
Final candidate: `d7d5e5d45f79fc27f35bd0758ba6e1675bda6b92`.
PR: #13.
Merge main: `e054aee3d18196881fbb8033037441959b255b73`.
Native merged-main Verify: run `36225126052` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: catalog/parity + FMG-005..FMG-009 contracts PASS; Windows runtime 682 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-009_APPLY_EDITS_EVIDENCE.md`.

## FMG-010 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-011-metadata-evidence`.
Primary PR: #14.
Follow-up PRs: #15, #16.
Final main: `9340377f42abfe97bc708d0683f77dea26e86b50`.
Native merged-main Verify: run `36235453791` SUCCESS on macOS / Windows x64 / Windows ARM64.
Local merged-main proof: project-context/catalog/parity/source-state contracts PASS; Windows runtime 715 assertions PASS; Release build 0 warnings / 0 errors.
Evidence: `docs/evidence/FMG-010_PROJECT_CONTEXT_CANDIDATE_EVIDENCE.md`.

## FMG-011 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-011-metadata-evidence`.
Depends: FMG-002, FMG-003, FMG-006, FMG-010 DONE / MAIN VERIFIED.
Scope: Metadata-Only Evidence / Freshness only.
Later dependent tasks remain BLOCKED by the frozen graph.


FMG-011 design freeze complete:
- docs/design/FMG-011_METADATA_EVIDENCE_FRESHNESS_FROZEN.md
- docs/design/FMG-011_INDEPENDENT_REVIEW.md
- docs/design/FMG-011_DECISION_MATRIX.md
- tasks/FMG-011_TASK_GRAPH.md
- NEXT_EXACT_ACTION: implement FMG-011-A shared evidence contracts/IDs/states only; do not begin store integration before contracts pass.


FMG-011 local candidate:
- State: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING.
- Scope remains Metadata-Only Evidence / Freshness only.
- A-G local implementation/adversarial gates PASS.
- Windows runtime: 750 assertions PASS.
- Native macOS/Windows x64/Windows ARM64 Verify is the remaining H-gate.
- Evidence: `docs/evidence/FMG-011_METADATA_EVIDENCE_CANDIDATE_EVIDENCE.md`.
- FMG-012 remains BLOCKED until FMG-011 MAIN VERIFIED.
Final candidate: `54270a86e03ebcdb86d01954d791065d5abdf1bc`.
PR: #17.
Merge main: `ddc8b27839469dcc5a6ff36bb531cf0b3dda87aa`.
Native merged-main Verify: run `36296831946` SUCCESS on macOS / Windows x64 / Windows ARM64.
Evidence: `docs/evidence/FMG-011_METADATA_EVIDENCE_CANDIDATE_EVIDENCE.md`.

## FMG-012 implementation

State: DONE / MAIN VERIFIED.
Branch: `chatgpt/FMG-012-cross-platform-gate`.
Depends: FMG-001 through FMG-011 DONE / MAIN VERIFIED.
Scope: Cross-Platform Adversarial Contract Gate only. No new feature scope unless verification finds a concrete defect.
NEXT_EXACT_ACTION: run exact catalog/schema parity, all Phase A negative/adversarial contracts, Windows Release/runtime/package gates, then native macOS/Windows x64/Windows ARM64 Verify; fix only concrete failing stages.
Evidence: `docs/evidence/FMG-012_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.
Local proof: all Phase A contracts PASS; Windows runtime 750 assertions PASS; Release 0 warnings/errors; x64/ARM64 package builds and static integrity PASS.
Claim-head native Verify: run `36297166252` SUCCESS on macOS / Windows x64 / Windows ARM64.
Final exact-head native Verify remains required after evidence commit.
Final candidate: `364b7945f2885e5ec39ee1ad1da9e8a08618735c`.
PR: #18.
Merge main: `d3a3670f6fb60ab75d8471b3d982c811337fa951`.
Native merged-main Verify: run `36297870457` SUCCESS on macOS / Windows x64 / Windows ARM64.
Evidence: `docs/evidence/FMG-012_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.

## FMG-013 implementation

State: LIVE VERIFIED / EXACT-HEAD NATIVE CI PENDING.
Branch: `chatgpt/FMG-013-full-regression-live-proof`.
Depends: FMG-012 DONE / MAIN VERIFIED.
Scope: Foundation Full Regression + Live MCP Proof only. No new feature scope unless verification finds a concrete defect.
NEXT_EXACT_ACTION: run exact full regression and live MCP proof against the current FileMCP connector, verify catalog/schema/live tools parity and failure semantics, package/native gates, then merge only exact green evidence.
Evidence: `docs/evidence/FMG-013_FULL_REGRESSION_LIVE_MCP_EVIDENCE.md`.
Regression/native CI proof: PASS.
Blocker: current live desktop connector is old binary PID 11960 and exposes 19 tools vs canonical 23.
Ready build: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`.
Resume only live MCP proof after normal desktop restart/reconnect; do not rerun completed regression.


## FMG-013 post-restart checkpoint - 2026-09-28

State: BLOCKED / CHATGPT CONNECTOR DISCOVERY STALE.

Desktop deployment is current:
- PID `10688`;
- executable `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`;
- SHA-256 `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`.

This chat still exposes 19 FileMCP tools, so the required live 23-tool catalog/hash proof is not yet satisfied. Foundation regression/native CI remain PASS and must not be rerun solely because connector discovery is stale. FMG-014 remains BLOCKED.


## FMG-013 reconnect verification - 2026-09-28

State remains BLOCKED / CHATGPT CONNECTOR DISCOVERY STALE.

Verified current runtime/tunnel: ready binary PID `10688`; tunnel `healthz=live`, `readyz=ready`; main MCP channel probe `ok`; direct route to `127.0.0.1:8008`; successful control-plane-to-MCP forwarding observed; fresh logical correlation resume and bound read PASS.

ChatGPT still exposes 19/23 tools, so FMG-013 cannot be marked FOUNDATION MAIN VERIFIED and FMG-014 cannot be claimed.


## FMG-013 connector refresh checkpoint - 2026-09-28T15:49:09+07:00

Targeted D tunnel reconnect completed successfully (PID 2620 -> 2552; health live; readiness ready) without rerunning regression. ChatGPT-visible registry remains 19/23, with exec_process/apply_edits/project_context/evidence_get absent. State remains BLOCKED / CHATGPT CONNECTOR DISCOVERY STALE. FMG-014 remains blocked.


## FMG-013 live connector acceptance - 2026-09-28T15:59:05+07:00

State: LIVE VERIFIED / EXACT-HEAD NATIVE CI PENDING.

Canonical live registry: 23 tools; catalog version `1.6.0`; catalog SHA-256 `98ba484931717cc7ee8efbce83941afc33aa5fbaddb6b667882100a423bfacee`. Live proofs PASS for exec_process, project_context, apply_edits, evidence_get dispatch/error semantics, and logical-chat correlation. Remaining work is exact-head native Verify -> scoped review -> PR/merge -> merged-main verification. FMG-014 remains BLOCKED until FMG-013 FOUNDATION MAIN VERIFIED.

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

## FMG-013 final closure

FMG-013: DONE / FOUNDATION MAIN VERIFIED.
Final candidate: `db34185e4989953b54a504c9e03a1b5b7253ba3d`.
PR: #21.
Merge main: `0158bc5a7b94df7531d9d19c183c9b1c2f8af6c2`.
Candidate PR Verify: run `36402363852` SUCCESS on macOS / Windows x64 / Windows ARM64 after retrying only a transient ARM64 setup-dotnet runner failure.
Merged-main native Verify: run `36403091233` SUCCESS on macOS / Windows x64 / Windows ARM64.
Evidence: `docs/evidence/FMG-013_FULL_REGRESSION_LIVE_MCP_EVIDENCE.md`.

## FMG-014 implementation

State: ACTIVE / LOCAL VERIFIED / CROSS-PLATFORM CI PENDING.
Branch: `chatgpt/FMG-014-artifact-contentref-store`.
Depends: FMG-013, FMG-004, FMG-006, FMG-011 DONE / MAIN VERIFIED.
Scope: Ephemeral Artifact / ContentRef Store only.
NEXT_EXACT_ACTION: implement the authenticated content-addressed store foundation and its cross-platform security/failure contracts. Do not begin FMG-015 before FMG-014 MAIN VERIFIED.


## FMG-014 local verification checkpoint

Evidence: `docs/evidence/FMG-014_ARTIFACT_CONTENTREF_STORE_EVIDENCE.md`.
Windows local contract/build/integration: PASS (776 assertions; 0 warnings / 0 errors).
macOS native compile/integration: pending exact-head Verify.
FMG-015 remains BLOCKED until FMG-014 MAIN VERIFIED.


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


## FMG-014 final closure

FMG-014: DONE / MAIN VERIFIED.
Final evidence head: `d4d2c75ce91efd1b1b3f5f87d58e86f52f6ced53`.
PR: #26.
PR exact-head Verify: run `36417272966` SUCCESS on macOS / Windows x64 / native Windows ARM64.
Merge main: `d7669ed0d60c51eb1cfb12813abc8f34d3d3ff0e`.
Merged-main Verify: run `36417632075` SUCCESS on macOS / Windows x64 / native Windows ARM64.
Evidence: `docs/evidence/FMG-014_ARTIFACT_CONTENTREF_STORE_EVIDENCE.md`.

## FMG-015 implementation

State: CLAIMED / ACTIVE.
Branch: `chatgpt/FMG-015-batch-read-stat`.
Depends: FMG-014, FMG-004, FMG-006 DONE / MAIN VERIFIED.
Scope: Batch Read / Stat only.
NEXT_EXACT_ACTION: implement batch_stat + batch_read with per-entry path/version authority, aggregate budget, deterministic entry states, explicit partial cancellation and optional ContentRef for oversized payloads. FMG-016 remains BLOCKED.


## FMG-014 closure / FMG-015 claim

FMG-014: DONE / MAIN VERIFIED.
PR #26 head `d4d2c75ce91efd1b1b3f5f87d58e86f52f6ced53`; merge main `d7669ed0d60c51eb1cfb12813abc8f34d3d3ff0e`; PR Verify `36417272966` SUCCESS; merged-main Verify `36417632075` SUCCESS on macOS / Windows x64 / native Windows ARM64.

FMG-015: CLAIMED / ACTIVE on `chatgpt/FMG-015-batch-read-stat`.
NEXT_EXACT_ACTION: implement batch_stat + batch_read with per-entry resolver/version authority, one aggregate ToolBudget, deterministic per-entry results, explicit cancellation/partial state, and optional Artifact ContentRef spill for oversized content; then negative tests -> local verify -> exact-head native Verify -> review -> PR/merge -> merged-main Verify. FMG-016 remains BLOCKED until FMG-015 MAIN VERIFIED.

## FMG-015 implementation verification - 2026-09-28

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
