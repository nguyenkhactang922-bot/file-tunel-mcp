# ADR-0006 - Complete Upgrade Scope Freeze Before Implementation

Status: ACCEPTED / COMPLETE-SCOPE ARCHITECTURE FROZEN
Date: 2026-09-24
Extends: ADR-0005
Authority: product owner requirement that all currently planned architecture/task design be completed before feature coding begins.

## Context

ADR-0005 froze the FileMCP foundation but deliberately deferred several advanced capabilities until after Phase A. Product authority now requires a different execution law:

> design the complete currently desired upgrade, resolve technology choices, audit it, freeze dependencies, split every task, and only then begin coding. Do not finish Phase A and reopen architecture for Phase B.

The deferred capabilities were therefore re-evaluated using the existing source-first audits of ChatCMD, Codex, OpenHands, Aider and Cline, plus an independent advanced-scope red-team and repair re-audit.

## Decision

The implementation program is now one complete frozen scope:

1. Foundation FMG-001..FMG-013 under ADR-0005;
2. Advanced capability FMG-014..FMG-026 under this ADR;
3. no architecture design pause between them.

FMG-013 is a foundation verification milestone, not the final product-upgrade completion point.

The final completion point is FMG-026 COMPLETE UPGRADE MAIN VERIFIED.

## Advanced capabilities approved to build

### 1. Ephemeral Artifact / ContentRef Store

BUILD.

Content-addressed local storage outside repositories with authenticated refs, workspace/content-class scope, current-user-only permissions, hard quota and TTL.

Artifact/checkpoint/PTY content stores are explicit feature content stores and are separate from telemetry/evidence.

### 2. Batch Read / Stat

BUILD.

Batch operations preserve per-path authorization/versioning and aggregate ToolBudget. Large payloads may return ContentRefs.

### 3. Quarantine Delete / Restore

BUILD.

Quarantine is a safer recoverable destructive path using version + Mutation Guard + artifact-backed package. Multi-file restore is a checkpoint-backed transaction with rollback and `partial_recovery_required` terminal state where necessary.

### 4. Model-Friendly Edit Adapters

BUILD.

Search/replace and unified-diff adapters compile only to canonical versioned `apply_edits`. They never bypass Mutation Guard or become a second storage engine.

### 5. Repository Intelligence

BUILD.

MCP tools: repo_map, symbol_search and related_files.

Current complete-scope provider: built-in dependency-free LexicalSymbolProvider using Git file inventory, bounded language-aware symbol/import heuristics and ranking.

Output is explicitly heuristic/non-exhaustive and never authorization.

Metadata cache is rebuildable, SourceStateRef-versioned, separate from observability/evidence and stores no raw full source by default.

### 6. Persistent PTY

BUILD.

Windows uses ConPTY; macOS uses native POSIX PTY semantics. Sessions are scoped, budgeted and policy-controlled. Ring buffer is memory-only by default; short-lived Artifact Store spillover is allowed. Restart never fakes PTY resume.

### 7. Workspace Checkpoint / Restore

BUILD.

Checkpoint content is explicit USER-REQUESTED WORKSPACE CONTENT with separate policy, quota and TTL.

Capture binds repository/workspace/Git/source state and stores changed/untracked payloads in Artifact Store without transcript/task content.

Restore is transactional: divergence guard -> rollback checkpoint -> plan -> guarded restore -> index restore -> verification -> commit cleanup; failure triggers rollback. Failed rollback yields `partial_recovery_required` and preserves recovery material.

### 8. Execution Backend Interface

BUILD after structured exec/PTY foundation.

Scope is limited to process + PTY execution. Native file/Git tools remain host-side and are not rewritten behind a workspace abstraction.

HostExecutionBackend remains default.

### 9. Optional Docker Isolated Backend

BUILD as optional capability.

Docker is never required for normal FileMCP startup.

Security contract:
- locally configured allowlisted image pinned to immutable digest;
- model cannot choose image/mount/daemon endpoint;
- workspace mount only after final path/reparse revalidation;
- no arbitrary volumes;
- no Docker socket mount;
- non-root where supported;
- cap-drop ALL;
- no-new-privileges;
- mandatory PID/memory/CPU limits;
- network none by default;
- network-enabled isolated execution is a distinct locally authorized capability;
- sanitized env and explicit secret mediation;
- FileMCP-owned labels and bounded lifecycle/cleanup;
- evidence records backend/image/network/resource policy.

Windows/macOS support is honestly Docker Desktop/Linux-container behavior, not a claim of native OS sandbox equivalence.

## Explicitly rejected rather than deferred

The following are not part of the complete implementation program and require a future product-scope change, not a routine Phase B design session:

- durable arbitrary-command idempotency/auto-replay registry;
- local general task manager;
- local sub-agent/model runtime;
- MCP-of-MCP provider host;
- browser DOM/cookie/session automation;
- public bearer-token primary MCP endpoint;
- broad prompt/tool/command/file-content history;
- mandatory Docker/VM runtime;
- full-source persistent repository index;
- automatic low-level Git commits;
- language rewrite of FileMCP.

## Technology decisions frozen

- Artifact storage: filesystem content-addressed store + small metadata index, not telemetry DB BLOBs.
- Checkpoint: artifact-backed transactional changed-state snapshot, not Git-only reset/stash semantics.
- PTY: native ConPTY/POSIX PTY, not redirected stdio pretending to be a terminal.
- Repository intelligence: provider interface + built-in lexical provider for current scope; no mandatory parser dependency.
- Isolation: optional Docker backend behind process/PTY backend interface; host remains default.
- Idempotency: no automatic replay of unknown arbitrary command side effects.

## Complete dependency authority

`tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md` is the ordering/implementation authority.

`tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md` remains detailed normative specification for FMG-001..FMG-013 where the complete graph references it.

## Implementation law

No feature coding starts until:
- ADR-0006 committed;
- complete task graph committed;
- complete-scope red-team/re-audit PASS evidence committed;
- CURRENT_HANDOFF and PROJECT_STATE point to FMG-001 as the first implementation action.

After coding starts, the project must continue through the frozen graph rather than pausing after FMG-013 for a new design cycle.

Task-level implementation details may evolve inside the frozen contracts. Changes to trust boundaries, persistence classes, product boundary, or dependency architecture require an explicit new ADR.

## Final completion definition

The upgrade is complete only after FMG-026:
- foundation verified;
- advanced capabilities verified;
- Windows/macOS cross-platform gates complete;
- optional Docker backend availability behavior and real backend proof are documented according to environment;
- full regression/live MCP proof complete;
- review/merge complete;
- MAIN VERIFIED;
- state/evidence updated.