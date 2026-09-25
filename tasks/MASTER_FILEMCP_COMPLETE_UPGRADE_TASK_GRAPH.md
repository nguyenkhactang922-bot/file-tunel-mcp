# MASTER FileMCP Complete Upgrade Task Graph

Status: FROZEN COMPLETE IMPLEMENTATION PLAN - NO FEATURE CODE STARTED
Date: 2026-09-24
Architecture authorities:
- docs/adr/0005-final-coding-agent-gateway-architecture.md
- docs/adr/0006-complete-upgrade-scope-freeze.md
- docs/design/MASTER_FILEMCP_COMPLETE_UPGRADE_ARCHITECTURE_V2.md

## Completion law

The project does not stop at FMG-013 for another architecture cycle.

Complete path:

FMG-001..FMG-013 FOUNDATION MAIN VERIFIED
-> FMG-014..FMG-024 ADVANCED CAPABILITIES
-> FMG-025 ADVANCED ADVERSARIAL GATE
-> FMG-026 COMPLETE REGRESSION/LIVE PROOF
-> COMPLETE UPGRADE MAIN VERIFIED.

Every task follows CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> REVIEW -> MERGE -> MAIN VERIFIED -> NEXT READY TASK.

## Full dependency graph

```text
FMG-001 Canonical Catalog
  +-> FMG-002 Structured Result
  +-> FMG-003 Policy + Migration

FMG-002 -> FMG-004 ToolBudget/Cancellation/Cursor
FMG-002 + 003 + 004 -> FMG-005 exec_process
FMG-001 + 002 -> FMG-006 File Version + SourceStateRef
FMG-006 -> FMG-007 Mutation Guard
FMG-007 + 003 -> FMG-008 Existing Mutation Hardening
FMG-004 + 008 -> FMG-009 apply_edits
FMG-001 + 004 + 006 -> FMG-010 Project Context
FMG-002 + 003 + 006 + 010 -> FMG-011 Evidence/Freshness
FMG-001..011 -> FMG-012 Foundation Adversarial Gate
FMG-012 -> FMG-013 Foundation Full Regression/Live Proof

FMG-013 + 004 + 006 + 011 -> FMG-014 Artifact/ContentRef Store
FMG-014 + 004 + 006 -> FMG-015 Batch Read/Stat
FMG-014 + 008 + 011 -> FMG-016 Quarantine Delete/Restore
FMG-013 + 009 -> FMG-017 Edit Adapters
FMG-014 + 010 + 006 -> FMG-018 Repository Intelligence Core/Cache
FMG-018 -> FMG-019 repo_map/symbol_search/related_files
FMG-014 + 005 + 003 + 004 -> FMG-020 Persistent PTY
FMG-014 + 006 + 011 -> FMG-021 Checkpoint Capture
FMG-021 + 008 + 009 + 016 -> FMG-022 Checkpoint Restore Transaction
FMG-013 + 005 + 011 -> FMG-023 Execution Backend Interface
FMG-023 + 020 + 014 + 003 + 004 -> FMG-024 Optional Docker Isolated Backend
FMG-014..024 -> FMG-025 Advanced Cross-Platform Adversarial Gate
FMG-025 -> FMG-026 Complete Regression + Live Advanced Proof
```

## Foundation task specifications FMG-001..FMG-013

For FMG-001..FMG-013, the detailed scope/acceptance/negative-test text in `tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md` is incorporated by reference. The headings/dependencies below are repeated here so this file is a complete single graph authority.

## FMG-001 - Canonical Catalog Authority

State: DONE / MAIN VERIFIED
Depends: ADR-0005 + ADR-0006
Detailed specification: `tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md` FMG-001.

## FMG-002 - Structured Result Envelope

State: DONE / MAIN VERIFIED
Depends: FMG-001
Detailed specification: foundation graph FMG-002.

## FMG-003 - Server-Owned Policy + Migration

State: ACTIVE / CLAIMED
Depends: FMG-001
Detailed specification: foundation graph FMG-003.

## FMG-004 - ToolBudget / Cancellation / Cursor Core

State: BLOCKED
Depends: FMG-002
Detailed specification: foundation graph FMG-004.

## FMG-005 - Structured exec_process + Environment Authority

State: BLOCKED
Depends: FMG-002, FMG-003, FMG-004
Detailed specification: foundation graph FMG-005.

## FMG-006 - Strong File Version + SourceStateRef

State: BLOCKED
Depends: FMG-001, FMG-002
Detailed specification: foundation graph FMG-006.

## FMG-007 - AuthorizedPathSnapshot / Mutation Guard

State: BLOCKED
Depends: FMG-006
Detailed specification: foundation graph FMG-007.

## FMG-008 - Harden Existing write/delete Mutations

State: BLOCKED
Depends: FMG-007, FMG-003
Detailed specification: foundation graph FMG-008.

## FMG-009 - Atomic Versioned apply_edits

State: BLOCKED
Depends: FMG-004, FMG-008
Detailed specification: foundation graph FMG-009.

## FMG-010 - Project Context Provenance / Digest

State: BLOCKED
Depends: FMG-001, FMG-004, FMG-006
Detailed specification: foundation graph FMG-010.

## FMG-011 - Metadata-Only Evidence / Freshness

State: BLOCKED
Depends: FMG-002, FMG-003, FMG-006, FMG-010
Detailed specification: foundation graph FMG-011.

## FMG-012 - Foundation Cross-Platform Adversarial Contract Gate

State: BLOCKED
Depends: FMG-001 through FMG-011
Detailed specification: foundation graph FMG-012.

## FMG-013 - Foundation Full Regression + Live MCP Proof

State: BLOCKED
Depends: FMG-012
Detailed specification: foundation graph FMG-013.

FMG-013 is FOUNDATION MAIN VERIFIED only; it is not the final complete-upgrade completion point.

## FMG-014 - Ephemeral Artifact / ContentRef Store

State: BLOCKED
Depends: FMG-013, FMG-004, FMG-006, FMG-011

Scope:
- local content-addressed blob store outside repository;
- metadata index;
- authenticated ContentRef;
- installation/workspace/content-class/expiry binding;
- quotas and TTL garbage collection;
- current-user-only permissions;
- stream read/write;
- explicit content classes including TOOL_OUTPUT, PTY_OUTPUT, CHECKPOINT, QUARANTINE.

Acceptance:
- arbitrary path cannot be converted to ContentRef;
- ref from another workspace/root rejected;
- expired/tampered ref rejected;
- atomic blob publish;
- quota exhaustion has no partial durable artifact;
- GC cannot touch repository state;
- no blob bytes enter telemetry/evidence.

Negative tests:
- ref tamper;
- cross-workspace replay;
- metadata/blob mismatch;
- corruption;
- disk full;
- concurrent put/delete;
- expired lease;
- permission/ACL regression.

Cross-platform:
- Windows ACL/current-user storage proof;
- macOS POSIX owner-permission proof;
- identical ref semantics.

## FMG-015 - Batch Read / Stat

State: BLOCKED
Depends: FMG-014, FMG-004, FMG-006

Scope:
- batch_stat;
- batch_read;
- per-entry SafePathResolver/version checks;
- aggregate ToolBudget;
- per-entry result states;
- optional ContentRef for oversized items.

Acceptance:
- no batch authorization amplification;
- deterministic per-entry errors;
- aggregate cap cannot be bypassed by many small entries;
- cancellation returns explicit partial result;
- version token returned per eligible file.

Negative tests:
- mixed valid/escape paths;
- duplicate paths;
- huge path list;
- cancellation mid-batch;
- individual file changes mid-read;
- artifact quota exhaustion.

## FMG-016 - Quarantine Delete / Restore

State: BLOCKED
Depends: FMG-014, FMG-008, FMG-011

Scope:
- quarantine_delete;
- quarantine_list/get metadata;
- quarantine_restore;
- expected-version + Mutation Guard;
- artifact-backed payload/manifest;
- TTL/quota;
- tree restore rollback transaction.

Acceptance:
- source delete only after quarantine package verified;
- restore never silently overwrites changed target;
- single files use guarded atomic publish;
- tree restore captures rollback checkpoint/transaction material;
- terminal states restored / rolled_back / partial_recovery_required;
- failed rollback retains recovery artifacts.

Negative tests:
- stale source version;
- path swap;
- expired quarantine ref;
- destination appeared after plan;
- tree partial failure;
- rollback failure;
- quota/disk full.

## FMG-017 - Model-Friendly Edit Adapters

State: BLOCKED
Depends: FMG-013, FMG-009

Scope:
- apply_search_replace;
- apply_unified_diff;
- preview/dry-run;
- compilation to canonical apply_edits.

Acceptance:
- adapters never write directly;
- ambiguity fails closed;
- expected version preserved;
- BOM/newline semantics inherited from apply_edits;
- preview exactly matches compiled canonical edits.

Negative tests:
- zero match;
- multiple matches;
- malformed unified diff;
- overlapping hunks;
- stale version;
- path header escape;
- cancellation.

## FMG-018 - Repository Intelligence Core / Cache

State: BLOCKED
Depends: FMG-014, FMG-010, FMG-006

Scope:
- RepositoryIntelligenceProvider interface;
- built-in LexicalSymbolProvider;
- Git-tracked inventory + ignored-directory policy;
- language-aware lightweight symbol/import extraction;
- relation/ranking model;
- rebuildable metadata cache;
- SourceStateRef generation/invalidation;
- no raw full-source persistence by default.

Acceptance:
- provider id/version/completeness emitted;
- `completeness=heuristic` for lexical provider;
- unsupported language degrades to file-level relations;
- cache corruption -> delete/rebuild;
- cache absence does not block baseline tools;
- indexing bounded/cancellable;
- no authorization depends on intelligence results.

Negative tests:
- giant repo;
- binary/vendor/generated files;
- case/path differences;
- stale cache;
- corrupted cache;
- parser/profile mismatch;
- cancellation.

## FMG-019 - repo_map / symbol_search / related_files

State: BLOCKED
Depends: FMG-018

Scope:
- bounded repo_map;
- symbol_search;
- related_files;
- ranking and query contract;
- ContentRef spillover for large maps.

Acceptance:
- deterministic bounded output for same provider/state/query;
- result explains provider/version/heuristic completeness;
- query does not trigger unrestricted full-source persistence;
- stale generation handled explicitly;
- output respects ToolBudget/cursor contracts.

Negative tests:
- ambiguous symbols;
- no symbol support;
- stale generation during query;
- very large graph;
- invalid cursor;
- artifact unavailable.

## FMG-020 - Persistent PTY Session Runtime

State: BLOCKED
Depends: FMG-014, FMG-005, FMG-003, FMG-004

Scope:
- Windows ConPTY;
- macOS native POSIX PTY/forkpty semantics;
- pty_start/read/write/resize/signal/stop/list;
- scoped session IDs;
- environment authority reuse;
- bounded RAM ring buffer;
- cursor reads;
- idle/max TTL;
- PTY_OUTPUT spillover;
- process-tree cleanup.

Acceptance:
- actual TTY behavior, not redirected stdio;
- memory-only output by default;
- PTY bytes absent from evidence/telemetry;
- secret-like stdin not persisted;
- resize and EOF/signal semantics documented per platform;
- FileMCP restart never reports dead PTY as resumed;
- orphan kill requires proven ownership beyond PID alone.

Negative tests:
- session ref tamper;
- output flood;
- idle expiry;
- FileMCP crash/restart;
- PID reuse;
- child process tree;
- invalid resize;
- policy revoked mid-session.

## FMG-021 - Workspace Checkpoint Capture

State: BLOCKED
Depends: FMG-014, FMG-006, FMG-011

Scope:
- checkpoint_capture/list/delete/get metadata;
- explicit policy capability;
- base worktree/repo identity + HEAD/index/source state;
- tracked changed content + selected untracked content in Artifact Store;
- ignored/generated/oversized exclusion defaults;
- manifest digest/version/TTL/quota.

Acceptance:
- no automatic checkpoint on every tool call;
- no prompt/chat/task transcript stored;
- checkpoint accurately reports staged/unstaged/untracked coverage;
- manifest/content integrity verified;
- deletion/expiry cleans content safely;
- repository itself is not mutated merely to capture checkpoint.

Negative tests:
- giant untracked tree;
- symlink/reparse entry;
- changing file during capture;
- disk full;
- artifact corruption;
- ignored path opt-in/out.

## FMG-022 - Checkpoint Restore Transaction

State: BLOCKED
Depends: FMG-021, FMG-008, FMG-009, FMG-016

Scope:
- restore plan;
- divergence/history guard;
- mandatory rollback checkpoint;
- staged/unstaged/untracked restoration;
- version/Mutation Guard per mutation;
- index/staged state restoration;
- post-restore manifest verification;
- rollback transaction;
- partial_recovery_required terminal state.

Acceptance:
- later/diverged commits refused by default;
- restore failure triggers rollback;
- rollback material retained until verification succeeds;
- rollback failure cannot yield PASS;
- ignored/generated files follow manifest policy;
- direct history-moving mode requires explicit stronger local policy.

Negative tests:
- amended/diverged HEAD;
- race after validation;
- staged + unstaged + untracked mix;
- file locked;
- rollback failure;
- FileMCP crash mid-restore;
- artifact missing/corrupt.

## FMG-023 - Execution Backend Interface

State: BLOCKED
Depends: FMG-013, FMG-005, FMG-011

Scope:
- IExecutionBackend contract for process + PTY only;
- HostExecutionBackend wrapping existing ProcessRunner/PTY;
- backend identity/version/capabilities;
- workspace mapping;
- environment/secret mediation hooks;
- health/lifecycle/cleanup;
- evidence backend identity.

Acceptance:
- host behavior unchanged except routing;
- file/Git tools remain host-native outside interface;
- backend capabilities explicit;
- unavailable backend cannot break HostExecutionBackend.

Negative tests:
- backend unavailable;
- capability mismatch;
- lifecycle failure;
- result normalization mismatch;
- backend identity spoof attempt.

## FMG-024 - Optional Docker Isolated Backend

State: BLOCKED
Depends: FMG-023, FMG-020, FMG-014, FMG-003, FMG-004

Scope:
- Docker CLI/engine adapter;
- locally configured digest-pinned image allowlist;
- isolated workspace session/container lifecycle;
- explicit workspace mount;
- non-root mapping where supported;
- cap-drop/no-new-privileges;
- mandatory CPU/memory/PID caps;
- network-none default;
- separate network-enabled policy capability;
- sanitized env/secret mediation;
- FileMCP ownership labels;
- health/idle/stop/delete/orphan cleanup;
- exec + PTY backend implementation.

Acceptance:
- FileMCP starts/works without Docker;
- model cannot choose image/mount/daemon;
- image resolved to digest before create;
- no Docker socket mount;
- mount source path/reparse revalidated at create time;
- network disabled by default and verified;
- foreign containers never deleted;
- evidence records backend/image/resource/network policy;
- Docker Desktop semantics on Windows/macOS documented honestly.

Negative tests:
- Docker absent;
- daemon unreachable;
- unpinned/changed image;
- malicious mount request;
- docker socket attempt;
- resource cap omission;
- network policy bypass;
- startup timeout;
- orphan cleanup with foreign labels;
- container escape assumptions not claimed as proof.

Live proof requirement:
- if Docker is available in verification environment, run one real isolated exec + PTY/network-none proof;
- if unavailable, task can be CODE/CONTRACT VERIFIED but complete-product evidence must explicitly mark live Docker proof environment-blocked, never fake PASS.

## FMG-025 - Advanced Cross-Platform Adversarial Gate

State: BLOCKED
Depends: FMG-014 through FMG-024

Scope:
- Windows/macOS contract parity for all advanced common tools;
- artifact/quarantine/checkpoint privacy/security tests;
- PTY native tests;
- repo-intelligence scale/corruption tests;
- backend lifecycle/security tests.

Acceptance:
- all advanced negative suites PASS or external live Docker proof is explicitly environment-blocked;
- no cross-platform semantic drift;
- no raw advanced content enters telemetry/evidence;
- no feature weakens ADR-0005 foundation invariants.

## FMG-026 - Complete Regression + Live Advanced Proof

State: BLOCKED
Depends: FMG-025

Scope:
- entire original app regression;
- FMG-001..025 regression;
- packaged Windows/macOS/native verification;
- live Secure MCP Tunnel discovery;
- live file/Git/exec/evidence proof;
- live artifact/batch/quarantine/edit/repo-intelligence/PTY/checkpoint proof;
- optional Docker backend proof according to availability rule;
- final docs/state/evidence;
- review/merge/main verification.

Acceptance:
- original FileMCP behavior preserved;
- all complete-scope contracts verified;
- no fake PASS from stdout;
- final merged main reruns required regression;
- COMPLETE_UPGRADE_MAIN_VERIFIED evidence exists;
- CURRENT_HANDOFF/PROJECT_STATE/task graph mark complete program DONE.

## Explicit no-task exclusions

No implementation task will be created for:
- arbitrary command idempotency/auto-replay registry;
- local task manager;
- sub-agent/model runtime;
- MCP provider host;
- browser DOM/session automation;
- public bearer endpoint;
- broad transcript/content history;
- mandatory Docker;
- full-source persistent index;
- automatic low-level Git commits;
- language rewrite.

## Start gate

Only FMG-001 is READY initially.

No feature code starts until ADR-0006, this graph, complete-scope red-team and repair re-audit are committed and state is synchronized.

After FMG-001 is claimed, continue through this graph without a new architecture/design pause after FMG-013.