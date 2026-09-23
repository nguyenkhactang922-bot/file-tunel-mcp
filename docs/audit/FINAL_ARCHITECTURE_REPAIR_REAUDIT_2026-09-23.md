# FINAL Architecture Repair Re-Audit

Status: PASS — ARCHITECTURE READY FOR ADR FREEZE
Date: 2026-09-23

Inputs:
- FINAL_INDEPENDENT_RED_TEAM_ARCHITECTURE_AUDIT.md
- MASTER_FILEMCP_CODING_AGENT_GATEWAY_ARCHITECTURE_V1.md
- FINAL_SECURITY_TRUST_BOUNDARY_MODEL.md
- FINAL_EXECUTION_EDITING_EVIDENCE_MODEL.md
- FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md

## Re-audit objective

Verify that the independent red-team P1 blockers were not merely acknowledged but converted into explicit architecture contracts and dependency inputs.

## P1 closure

### RT-01 canonical catalog authority — CLOSED

Repair present:
- one versioned repository catalog artifact is the schema/capability authority;
- target path is contracts/tool_catalog.v1.json unless equivalent frozen naming is justified;
- Windows/macOS runtime schema and handler coverage must exact-validate;
- catalog hash is derived from canonical normalized catalog representation;
- catalog descriptions cannot grant authority.

Residual risk: implementation tooling/generation approach. This is task-level, not architecture ambiguity.

### RT-02 undefined source-state digest — CLOSED

Repair present:
- explicit SourceStateRef contract;
- dependency scope can be narrow file-version or repository/workspace state;
- Git-backed evidence can bind HEAD, index/tree, tracked dirty fingerprint, scoped untracked fingerprint, catalog hash and policy generation;
- only metadata/digests persist;
- freshness uses same provider/algorithm version.

Residual risk: performance of workspace fingerprint. Mitigated by scoped evidence dependencies and task benchmarks.

### RT-03 EnableCommands migration ambiguity — CLOSED

Repair present:
- false -> restricted-equivalent;
- true -> migration-only legacy-command-compatible;
- workspace-auto requires explicit local selection;
- model cannot select/elevate profile.

Residual risk: long-term legacy profile retirement. Separate future compatibility decision.

### RT-04 exec_process environment ambiguity — CLOSED

Repair present:
- no arbitrary host environment inheritance by default;
- minimal platform baseline;
- local allowlisted pass-through;
- bounded policy-checked request overrides;
- secret-like variables not implicitly forwarded;
- existing run_command may retain legacy semantics temporarily and is high-risk.

Residual risk: toolchain-specific variable requirements. Covered by local pass-through configuration and integration tests.

### RT-05 Mutation Guard object identity — CLOSED

Repair present:
- AuthorizedPathSnapshot;
- parent/target identity, or parent + expected absence for new target;
- final no-follow identity recheck;
- fail closed on mismatch/ambiguity;
- platform-specific native primitives with equivalent adversarial swap behavior.

Residual risk: exact Windows/macOS API choice. Implementation task must prove with race/swap tests.

## P2 integration

RT-06 cursor lifecycle:
- bound tool/options/root/generation/position;
- authenticated and expiring;
- restart invalidation accepted;
- never mutation authority.

RT-07 evidence ownership/retention:
- local workspace/FileMCP ownership;
- bounded configurable retention/quota;
- storage failure -> unknown/unavailable, never false pass;
- basic tools remain available unless evidence explicitly required.

RT-08 policy generation:
- operation context captures policy generation/hash;
- side effects reauthorize before exec/commit.

RT-09 project-context versioning:
- architecture requires provenance/digest; implementation task must include schema/algorithm version and ordered source provenance.

## Cross-check against master audit spec

- exact current FileMCP source baseline: verified unchanged since 38026d8 for feature code;
- ChatCMD revalidation: complete;
- Codex deep/source audit: complete;
- OpenHands deep/source audit: complete;
- Aider audit: complete;
- Cline audit: complete;
- Goose audit: complete;
- contradiction matrix: complete;
- function upgrade matrix: complete;
- security/trust model: complete;
- host-vs-isolation decision: complete;
- execution/edit/evidence model: complete;
- large-repo decision: complete;
- recovery/checkpoint decision: complete;
- PTY decision: complete;
- local sub-agent decision: complete;
- performance/resource strategy: complete;
- failure-injection requirements: complete;
- independent red-team: complete;
- P1 repair re-audit: PASS.

## Final re-audit verdict

No unresolved P0 or P1 architecture blocker remains.

Deferred items are explicit product/phase decisions, not unknowns.

The design is eligible for:
1. ADR-0005 final architecture freeze;
2. master dependency/task graph creation.

Feature implementation remains forbidden until those two artifacts are written and state is synchronized.
