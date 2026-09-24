# PROJECT STATE

Project: FileMCP
Active branch: `chatgpt/FMG-001-canonical-catalog`
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

State: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING.
Branch: `chatgpt/FMG-001-canonical-catalog`.
Scope: Canonical Catalog Authority only.
Canonical candidate hash: `d597f611374045825808d930f2bb0ef7e995515bb816a52ceccb47fd42a8e6aa`.
Local proof: Windows runtime 470 assertions PASS; Release build 0 warnings / 0 errors; contract/parity PASS; isolated x64+ARM64 package build PASS; packaged x64 catalog/app smoke PASS.
Evidence: `docs/evidence/FMG-001_CANONICAL_CATALOG_EVIDENCE.md`.
Next gate: exact-head native GitHub Verify -> review -> merge fork main -> MAIN VERIFIED.
Later FMG tasks remain BLOCKED by dependency graph.
