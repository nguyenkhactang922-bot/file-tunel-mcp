# MASTER FileMCP Complete Upgrade Architecture V2

Status: PROPOSED COMPLETE-SCOPE MASTER - PRE RED-TEAM
Date: 2026-09-24
Supersedes as planning scope: MASTER_FILEMCP_CODING_AGENT_GATEWAY_ARCHITECTURE_V1 after final complete-scope freeze

## Goal

Freeze the complete currently-approved FileMCP upgrade before feature coding starts. No architecture phase may be left intentionally undecided and rediscovered only after Phase A implementation.

The complete scope is split into:
- FOUNDATION: FMG-001..FMG-013 (previous Phase A);
- ADVANCED CAPABILITIES: planned now and implemented only after foundation is MAIN VERIFIED;
- EXPLICIT EXCLUSIONS: rejected now, not deferred ambiguously.

## Product boundary

FileMCP remains a secure local coding-agent execution gateway. ChatGPT remains orchestration/reasoning authority.

FileMCP may add advanced local execution/recovery/context capabilities, but does not become a model provider, chat database, local general task manager, browser automation product or MCP-of-MCP provider manager.

## Complete architecture layers

ChatGPT/MCP
-> Secure Tunnel + loopback/local auth
-> canonical catalog
-> server-owned policy
-> operation context/budgets/cancellation
-> file/Git/process foundation
-> evidence/freshness
-> ADVANCED SERVICES:
   - ephemeral artifact/content-reference store
   - batch file metadata/read service
   - quarantine delete/restore
   - model-friendly edit adapters over apply_edits
   - repository intelligence service
   - persistent PTY session manager
   - explicit workspace checkpoint/restore
   - execution backend interface
   - optional Docker isolated backend
-> cross-platform adversarial verification
-> full live proof

## Advanced service A - Ephemeral Artifact / ContentRef Store

BUILD.

Purpose:
- preserve bounded MCP responses while allowing large output/files/checkpoint payloads;
- provide reusable content references for PTY, batch reads, checkpoint and quarantine.

Storage:
- local FileMCP data directory outside repository;
- content-addressed blobs by strong digest;
- metadata index contains blob id, size, media/type class, owner scope, created/expires timestamps and ref-count/lease metadata;
- no blob bytes in telemetry/evidence database;
- hard per-item, per-workspace and global quota;
- bounded TTL and garbage collection;
- caller must possess an opaque scoped ContentRef, not an arbitrary filesystem path.

Security:
- artifact store is not authorization to read host files;
- refs bind local FileMCP installation + workspace/scope + blob identity;
- refs expire and are authenticated;
- content is never served across workspace authority boundaries;
- secret scanning/redaction rules are metadata/reporting controls, not an excuse to persist arbitrary secrets indefinitely.

Failure behavior:
- missing/expired/corrupt blob -> explicit unavailable/stale;
- quota exhaustion -> fail before partial durable write;
- cleanup must not alter repository state.

## Advanced service B - Batch Read / Stat

BUILD.

Tools:
- batch_stat(paths[]);
- batch_read(requests[]) with per-entry bounds and aggregate ToolBudget.

Rules:
- every path individually passes SafePathResolver;
- version tokens returned per file;
- aggregate budget caps file count/bytes/output;
- partial completion is explicit per entry;
- large individual payload may return ContentRef instead of inline content;
- no batch call expands authority beyond the union of individually authorized calls.

## Advanced service C - Quarantine Delete / Restore

BUILD as an explicit safer alternative, not silent replacement for delete.

quarantine_delete:
- policy classified destructive but recoverable;
- requires expected version + Mutation Guard;
- copies/moves target content into Artifact Store-backed quarantine package before removing target;
- returns QuarantineRef with original relative path, source version, manifest hash, expiry.

quarantine_restore:
- never overwrites a changed target silently;
- target must be absent or caller supplies an explicit expected target version/replace mode authorized by policy;
- Mutation Guard applies;
- restoration is atomic per file where possible and transactionally reported for trees;
- expiry/quota bounded.

Direct delete remains available under policy; quarantine is preferred for autonomous destructive cleanup.

## Advanced service D - Model-Friendly Edit Adapters

BUILD above canonical apply_edits.

Initial adapters:
- apply_search_replace: exact/search block -> canonical ranges;
- apply_unified_diff: validated unified diff -> canonical ranges.

Rules:
- adapters read current version and compile to apply_edits;
- ambiguity/multiple-match fails closed unless tool contract explicitly selects one match;
- no adapter performs direct writes;
- expected-version + Mutation Guard remain final authority;
- preview/dry-run returns planned canonical edits.

Do not add model-specific syntax as a second mutation engine.

## Advanced service E - Repository Intelligence

BUILD with a provider architecture that avoids mandatory third-party parser/runtime dependencies.

Core tools:
- repo_map;
- symbol_search;
- related_files.

Provider V1:
- built-in LexicalSymbolProvider using Git-tracked file inventory, language-aware lightweight symbol/import patterns, file/path relations and bounded ranking;
- no external executable required;
- unsupported language returns file-level metadata rather than fabricated symbols.

Provider contract is frozen so richer parsers can be added later without changing MCP tools, but no additional parser provider is part of this complete scope.

Cache:
- local rebuildable metadata cache outside observability/evidence;
- stores path/symbol/type/relation/hash metadata, not full source text by default;
- schema/provider version + repository SourceStateRef generation;
- root containment and ignore rules;
- corruption -> delete/rebuild;
- absence -> baseline search tools continue to work.

Ranking:
- bounded deterministic scoring from changed files, symbol references/import links, path proximity and explicit query terms;
- output is context heuristic, never exhaustive truth or authority.

## Advanced service F - Persistent PTY

BUILD.

Cross-platform implementation:
- Windows: ConPTY native integration;
- macOS: POSIX PTY/forkpty-style native integration.

Tools:
- pty_start;
- pty_read(cursor);
- pty_write;
- pty_resize;
- pty_signal/pty_stop;
- pty_list scoped to current FileMCP instance/workspace policy.

Session contract:
- session id is opaque and scoped;
- server-owned policy required at start and write/signal actions;
- contained cwd;
- environment authority reuses exec_process policy;
- bounded ring buffer + optional Artifact ContentRef spillover;
- cursor-based reads;
- idle TTL + hard max lifetime + output/storage quota;
- process-tree cleanup on stop/restart;
- FileMCP restart marks old sessions terminated/lost unless platform proves child adoption safely; no fake resume.

PTY output is not verification evidence by itself.

## Advanced service G - Workspace Checkpoint / Restore

BUILD as explicit user/agent tool, separate from Git history/task state/evidence.

Checkpoint capture:
- binds canonical repository/workspace identity and HEAD OID;
- captures index/staged state metadata;
- captures tracked worktree changes and selected untracked files as Artifact Store content-addressed blobs;
- ignored/generated directories excluded by default unless explicit bounded opt-in;
- manifest is strong-hash signed/authenticated and TTL/quota bounded;
- no prompt/chat/tool transcript stored.

Checkpoint restore transaction:
1. resolve checkpoint + verify workspace identity;
2. refuse if repository history diverged from checkpoint base unless explicit history-moving mode is locally policy-authorized;
3. capture rollback checkpoint of current state;
4. validate staged/unstaged/untracked restoration plan;
5. apply restore with version/Mutation Guard semantics;
6. restore index/staged state;
7. verify manifest/source state;
8. on any failure, rollback from rollback checkpoint;
9. cleanup temporary refs/artifacts only after terminal result.

Default restore does not rewrite later commits.

Checkpoint privacy is explicit content storage initiated by checkpoint tools and isolated from observability/evidence.

## Advanced service H - Execution Backend Interface

BUILD after foundation exec_process is stable.

Interface owns:
- backend id/version;
- workspace mapping;
- exec request/result mapping;
- environment/secret mediation;
- health/lifecycle;
- resource/network capabilities;
- cleanup;
- evidence backend identity.

HostExecutionBackend wraps existing ProcessRunner and remains default.

Filesystem/Git MCP tools remain native host tools in this scope; backend abstraction initially applies to structured process/PTY execution, avoiding a risky rewrite of every FileMCP subsystem.

## Advanced service I - Optional Docker Isolated Backend

BUILD as OPTIONAL capability. Docker is never required for FileMCP startup or normal host execution.

Technology decision:
- use Docker CLI/engine available on host;
- user/local admin config supplies an allowlisted image pinned by digest;
- FileMCP does not execute arbitrary model-supplied image names;
- one isolated workspace session/container may be reused for bounded exec/PTY operations within a workspace lease.

Required hardening:
- workspace mount only, explicit rw/ro policy;
- no arbitrary host volume mounts;
- run non-root where supported;
- cap-drop ALL;
- no-new-privileges;
- PID/memory/CPU limits;
- temporary writable locations via controlled tmpfs/volumes;
- network none by default; network-enabled backend mode requires explicit local policy profile and is a distinct capability;
- no host Docker socket inside container;
- sanitized environment; secrets only via explicit local mediation;
- container label includes FileMCP instance/workspace/backend lease ids;
- startup health timeout, idle TTL, stop/delete cleanup;
- startup/restart orphan cleanup only for containers bearing valid FileMCP labels/ownership markers;
- evidence records image digest + backend id + effective network/resource policy.

Windows/macOS behavior is Docker Desktop/Linux-container semantics and must be documented/tested honestly; it is not native Windows/macOS OS sandboxing.

If Docker is unavailable, backend reports unavailable and HostExecutionBackend remains functional.

## Durable command idempotency registry

REJECT from complete current scope.

Reason:
- arbitrary shell/process commands are not semantically idempotent;
- a registry key can prevent duplicate FileMCP dispatch but cannot prove external side effects did not occur;
- crash/retry should surface UNKNOWN and require verification rather than automatic replay.

No task is created for this subsystem.

## Explicit exclusions frozen now

REJECT from complete scope:
- local general task manager;
- local sub-agent/model runtime;
- MCP-of-MCP provider hosting;
- browser DOM/cookie/session automation;
- public bearer-token primary MCP endpoint;
- broad transcript/tool-body/command/file-content history;
- mandatory container runtime;
- full-source persistent repository index;
- automatic low-level Git commits;
- arbitrary command auto-replay/idempotency claims;
- rewrite of FileMCP into Rust/Python/Node.

## Complete implementation sequencing

Foundation FMG-001..FMG-013 remains unchanged.

Advanced implementation begins only after FMG-013 MAIN VERIFIED, then follows the complete task graph frozen by ADR-0006.

No additional architecture/design phase is required between foundation and advanced tasks. Task-level implementation detail may be refined inside frozen contracts; architectural deviations require a new ADR.
## Independent red-team repairs - frozen requirements

### Artifact ContentRef authority

ContentRef is an authenticated capability reference scoped to FileMCP installation identity, workspace authority id, blob id, content class and expiry. It is not a filesystem path and cannot be converted from an arbitrary path. Resolution rechecks current policy/content class. Artifact root is current-user-only by filesystem ACL/permissions. Cross-workspace ref reuse fails closed.

### Artifact/Checkpoint content classification

Artifact bytes and checkpoint snapshots are explicit ephemeral/user-requested workspace content stores, not telemetry or verification evidence. Their content may exist only because a caller invoked a feature that requires content retention. They use independent quota/TTL/delete lifecycle and never become broad session history.

### PTY content privacy

PTY ring buffer is memory-only by default. No PTY bytes enter observability/evidence. Spillover, if required by quota, uses short-lived `PTY_OUTPUT` ContentRefs and is deleted at session end unless explicitly retained under bounded policy. FileMCP never persists secret-like stdin itself.

### Quarantine tree transaction

Multi-file/tree restore cannot claim single-operation filesystem atomicity. Before restore, capture a rollback checkpoint. Restore children using versioned/guarded atomic file operations, verify final manifest, and rollback the transaction on failure. Terminal states include `restored`, `rolled_back`, and `partial_recovery_required`. Rollback material is retained if rollback itself fails.

### Checkpoint rollback failure

Rollback checkpoint survives until post-restore verification succeeds. If both restore and rollback fail, cleanup stops, state becomes `partial_recovery_required`, and the recovery material remains available. No false PASS/RESTORED claim is allowed.

### Checkpoint privacy and policy

Checkpoint capture is a separately classified capability. It is not automatic on every tool call. Ignored/generated/oversized files are excluded by default. Manifests contain relative paths, source/Git state metadata and digests, never prompt/chat/task text. Explicit list/delete tools control retained checkpoints.

### Docker authority and supply chain

Docker backend accepts only locally configured allowlisted image references resolved and pinned to immutable digest. Model cannot choose image, volume mounts or daemon endpoint. Workspace mount source is re-resolved/reparse-checked immediately before create. Docker socket is never mounted. Network is `none` by default; a network-enabled isolated backend mode is a distinct local policy capability. Resource caps are mandatory. Cleanup acts only on containers labeled with current FileMCP installation/workspace/lease ownership. Evidence records image digest, backend id and effective network/resource policy.

### Repository intelligence truth label

Lexical provider outputs provider id/version and `completeness=heuristic`. Unsupported languages degrade to file-level relationships. Repository intelligence never authorizes actions or claims exhaustive symbol truth.

### PTY orphan safety

PID alone never proves session ownership after restart. Cleanup uses native creation/handle identity where available plus FileMCP ownership metadata. If ownership cannot be proven, mark unknown/orphaned and do not kill a potentially foreign process.

### Execution backend scope

ExecutionBackend abstraction is limited to structured process and PTY execution in this complete scope. Native FileMCP file/Git implementations remain authoritative and are not rewritten behind a remote workspace interface.
