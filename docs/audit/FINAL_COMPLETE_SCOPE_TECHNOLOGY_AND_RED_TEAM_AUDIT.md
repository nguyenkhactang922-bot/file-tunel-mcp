# FINAL Complete-Scope Technology and Independent Audit

Status: RED-TEAM FINDINGS - REPAIR REQUIRED BEFORE COMPLETE-SCOPE FREEZE
Date: 2026-09-24
Target: MASTER_FILEMCP_COMPLETE_UPGRADE_ARCHITECTURE_V2.md

## Technology decisions

### Artifact storage: filesystem content-addressed store vs SQLite/blob

Decision: filesystem blob store + small metadata index.

Why:
- large content does not bloat observability/evidence DB;
- atomic file publish is simpler;
- quota/TTL cleanup is explicit;
- content can be streamed without loading whole blob into DB memory.

Reject: raw arbitrary local file path as ContentRef; large BLOBs inside telemetry DB.

### Checkpoint: Git-only vs artifact-backed transactional snapshot

Decision: Artifact Store-backed changed/untracked payload + Git/source metadata.

Why:
- Git-only does not capture all untracked/staged/worktree state safely;
- automatic commits/stashes surprise users and mutate repository history/state;
- content-addressed snapshot lets FileMCP capture only explicit checkpoint material.

### PTY: shell emulation vs native PTY

Decision: native ConPTY on Windows and native POSIX PTY on macOS.

Why:
- shell pipes do not implement terminal resize/TTY semantics correctly;
- explicit native boundary is testable and avoids pretending redirected stdio is PTY.

### Repository intelligence: mandatory tree-sitter/ctags vs dependency-free provider

Decision: provider architecture + built-in lexical provider for current complete scope.

Why:
- Aider proves parser-backed maps are useful, but FileMCP has dual native runtimes and intentionally small package surface;
- bundling parser grammars or GPL-tagging executables introduces packaging/licensing/runtime cost before evidence that parser precision is required;
- frozen provider contract permits later richer provider implementation without changing MCP/API architecture.

Lexical provider is explicitly heuristic and non-exhaustive.

### Isolation: native OS sandbox vs optional Docker backend

Decision: optional Docker backend after host backend interface.

Why:
- Codex proves native OS sandboxing is platform-specific and substantial;
- OpenHands proves a real container backend needs lifecycle/resource/mount/credential controls;
- Docker Desktop supplies one optional cross-host operational path for Windows/macOS without replacing host execution.

Reject: mandatory Docker and generic arbitrary-volume Docker workspace.

### Command idempotency registry

Decision: REJECT.

Reason: dispatch deduplication cannot prove external side effects are idempotent. Crash uncertainty should yield UNKNOWN + verification, not auto-replay.

## Independent red-team findings

### BRT-01 - P1 - ContentRef could become an authority bypass

Risk:
A reference copied from another workspace/session could expose content that normal path tools could not read.

Required repair:
- ContentRef is authenticated and scoped to FileMCP installation + workspace authority id + blob id + expiry + content class;
- resolving a ref requires current policy to allow the relevant content class;
- no API accepts arbitrary filesystem path as a ref;
- current-user-only filesystem ACL/permissions on artifact root;
- refs are non-transferable across workspace roots by default.

### BRT-02 - P1 - Checkpoint rollback can itself fail

Risk:
A restore transaction can partially change workspace and then fail while rollback also fails.

Required repair:
- restore always creates a rollback checkpoint before destructive mutation;
- rollback checkpoint is retained until post-restore verification succeeds;
- if primary restore and rollback both fail, terminal state is BLOCKED/PARTIAL_RECOVERY_REQUIRED, cleanup stops, rollback material is retained and evidence contains manifest/digest metadata only;
- no false PASS/RESTORED state.

### BRT-03 - P1 - PTY buffer is content persistence and may capture secrets

Risk:
Interactive programs may echo tokens/passwords. A durable ring buffer would violate privacy law.

Required repair:
- PTY ring buffer is memory-only by default;
- optional spillover uses short-lived Artifact Store class PTY_OUTPUT and current-user permissions;
- no PTY bytes enter telemetry/evidence;
- spillover refs expire aggressively and are deleted at session end unless caller explicitly retains within bounded policy;
- secret-like stdin is never persisted by FileMCP.

### BRT-04 - P1 - Tree quarantine restore cannot be truly one-filesystem-call atomic

Risk:
Restoring a directory tree can fail after some children are restored.

Required repair:
- tree restore is a checkpoint-backed transaction;
- pre-restore rollback checkpoint is mandatory for non-empty/multi-file restore;
- per-file atomic publish + final manifest verification;
- partial failure triggers rollback transaction;
- terminal state distinguishes restored / rolled_back / partial_recovery_required.

### BRT-05 - P1 - Docker mount/image/network supply chain is a new authority surface

Required repair:
- configured image must be allowlisted locally and resolved/pinned to digest before launch;
- model cannot choose image, mount or Docker daemon endpoint;
- workspace mount source is re-resolved/reparse-checked immediately before container creation;
- no Docker socket mount;
- network none default; network-enabled backend is a distinct locally authorized capability;
- resource caps mandatory, not optional defaults;
- FileMCP-owned labels/instance id prevent deleting foreign containers;
- image digest/backend policy recorded in evidence.

### BRT-06 - P1 - Checkpoint capture expands privacy scope intentionally

Risk:
Checkpoint stores file bytes, unlike normal evidence/telemetry.

Required repair:
- checkpoint store is explicitly classified USER-REQUESTED WORKSPACE CONTENT, not observability/evidence;
- checkpoint capture capability is separately policy-classified;
- bounded TTL/quota and delete/checkpoint-list APIs;
- no automatic checkpoint on every tool call;
- ignored/generated/large files excluded by default;
- manifests store relative paths and digests, not chat/task text.

### BRT-07 - P2 - Lexical repo intelligence can mislead callers

Repair:
- output declares provider id/version and `completeness=heuristic`;
- no security/authorization decision can depend on symbol map;
- unsupported languages degrade to file-level relations;
- cache SourceStateRef generation invalidates stale entries.

### BRT-08 - P2 - PTY orphan cleanup can kill foreign processes

Repair:
- cleanup acts only on session/process identities created by current FileMCP instance and persisted ownership marker where safe;
- after restart, if ownership cannot be proven, mark orphaned/unknown rather than killing by PID alone;
- process identity includes creation-time/native handle data where available.

### BRT-09 - P2 - Backend abstraction can spread through all file/Git code and cause rewrite

Repair:
- V2 freezes backend abstraction to structured process + PTY execution only;
- file/Git tools remain native host-side for this complete scope;
- isolated backend workspace mount is the process workspace, not a second FileMCP filesystem implementation.

## Audit verdict

No P0 finding.

BRT-01 through BRT-06 are P1 and must be integrated before ADR-0006.
BRT-07 through BRT-09 must be represented in task acceptance.

After repair, complete-scope architecture can be frozen without waiting for Phase A implementation.