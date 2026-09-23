# MASTER FileMCP Coding-Agent Gateway Architecture V1

Status: FROZEN MASTER ARCHITECTURE - ADR-0005 AUTHORITY
Date: 2026-09-23

## Product definition

FileMCP remains a secure local coding-agent execution gateway. ChatGPT is the reasoning/orchestration agent. FileMCP supplies controlled files, Git, process execution and verification evidence.

It does not become a browser automation system, general local agent platform, MCP-of-MCP provider host or transcript/task database.

## Architecture

ChatGPT/MCP -> Secure Tunnel -> loopback + local auth -> canonical catalog -> server-owned policy -> operation context(workspace + project context + budget/cancel) -> filesystem/Git/process -> structured result/evidence -> separate observability/health.

## Preserve

KEEP: loopback, runtime local auth, Secure MCP Tunnel, Git safe mode, native C#/Swift runtimes, privacy-minimal observability, native ProcessRunner cleanup, compatible ordinary tools.

KEEP + HARDEN: SafePathResolver with Mutation Guard; file/search/write/delete with versions/budgets/cancellation; run_command as high-risk compatibility; exact cross-platform parity.

## Phase A additions

1. canonical language-neutral tool manifest/hash;
2. structured result envelope;
3. structured exec_process;
4. sanitized execution environment contract;
5. strong opaque file version identity;
6. Mutation Guard;
7. atomic versioned apply_edits;
8. common ToolBudget;
9. opaque bound cursors where needed;
10. metadata-only evidence/freshness;
11. bounded project-context provenance/digest;
12. server-owned policy profiles;
13. adversarial native Windows/macOS regression.

## Dependency principles

Catalog/risk metadata precedes policy. Structured result precedes exec/evidence. Strong version + Mutation Guard precede apply_edits. ToolBudget precedes cursor expansion. Evidence semantics precede final verification gates. Cross-platform contract is part of each task, not cleanup.

## Deferred

Optional isolated backend, repository intelligence implementation, checkpoint/restore, PTY, artifact spillover and durable command idempotency registry require later focused ADR/profile proof.

## Rejected from current core

Public tokenized MCP primary endpoint, browser DOM/session automation, broad content persistence, mandatory Docker/VM, MCP-of-MCP hosting, local task manager, local sub-agent/model runtime, full-source persistent index, language rewrite and custom application crypto.

## Authority invariant

Only local/user configuration grants authority. Catalog describes capability; project instructions describe behavior; model requests actions. None can elevate authority. Runtime enforcement is authoritative.

## Mutation invariant

A mutation commits only if policy still allows AND expected strong version matches AND canonical/no-follow path authority still matches AND staging/atomic publish succeeds.

## Verification invariant

A verification claim is authoritative only from structured evidence linked to required source state and criterion. Stdout PASS has no independent authority.

## Privacy invariant

No raw prompt/chat/tool args/command/file content/Git message/secrets enter observability or durable evidence by default.

## Large-repo invariant

Baseline tools work without an index. Phase A adds budgets/cancellation/cursors where justified. Optional repo intelligence is rebuildable metadata/cache and never authority.

## Recovery invariant

Unknown crash side effects are not auto-replayed. Checkpoint/restore is separate future architecture. Git, task state, evidence and observability remain distinct.

## Cross-platform invariant

No common feature passes on one-platform evidence. C# and Swift may use different native primitives but must have equivalent contracts, security semantics and failure states.

## Migration

Phase A is additive. Existing tools remain while safer primitives are added. No deprecation/removal without compatibility evidence and a separate decision.

## Rollback

New subsystems must be disableable/removable without making basic file/Git execution dependent on new evidence/policy persistence. Catalog/schema changes are versioned.

## Freeze condition

Freeze only after final function matrix, contradiction matrix, independent red-team, blocker repair, ADR-0005 and master task graph are complete.
## Red-team repair contracts

### Canonical catalog authority

The single catalog source of truth is a versioned repository artifact, target path `contracts/tool_catalog.v1.json` unless implementation discovery proves an equivalent path is necessary. It owns canonical tool names, input/output schemas, protocol/catalog versions and risk/effect/capability metadata. Windows and macOS must derive advertised schemas from, or exact-validate them against, this artifact. Handler registries must prove one-to-one coverage. CI/package/live runtime expose a catalogHash from canonical normalized catalog content. Descriptions do not grant authority.

### SourceStateRef

Evidence freshness uses a versioned SourceStateRef provider rather than an undefined digest. Git-backed repository evidence can bind canonical worktree identity, HEAD OID, index/tree identity, tracked dirty-worktree fingerprint, scoped relevant untracked-file fingerprint, catalog hash, effective policy generation and optional file-version refs. Only digests/metadata persist, never raw diff/file content. Evidence declares its dependency scope so unrelated state need not invalidate narrow evidence.

### Policy migration

Upgrade migration is explicit: current EnableCommands=false maps to restricted-equivalent behavior. Current EnableCommands=true maps to a migration-only legacy-command-compatible policy preserving existing run_command availability. New installs default restricted until the local user selects another profile. workspace-auto is never inferred from the legacy boolean and cannot be activated by model request.

### Execution environment authority

exec_process does not inherit arbitrary host environment by default. FileMCP supplies a documented minimal platform baseline. Local configuration controls additional pass-through variable names/patterns. Requests may provide bounded overrides only for policy-allowed names. Secret-like variables are not automatically forwarded. Existing run_command may retain legacy environment behavior during compatibility migration and is explicitly high-risk.

### AuthorizedPathSnapshot / Mutation Guard

Mutation Guard is object-identity based, not a second string canonicalization. It captures authorized root/parent/target identities using platform-native stable identity where available. Existing targets bind target plus ancestor/parent identity. New targets bind parent identity plus expected leaf state/absence. Final publish/delete reopens/rechecks without following unexpected links/reparse targets and fails closed on mismatch/ambiguity/authority change. Windows and macOS may use different native primitives but must pass equivalent path-swap tests.

### Cursor lifecycle

Read cursors bind tool/options hash, root authority ID, position and schema generation, are authenticated, bounded-lifetime and invalidated by incompatible root/policy/catalog generation. Restart invalidation is acceptable in Phase A. Cursor is never mutation authority.

### Evidence ownership and retention

Durable evidence belongs to the local FileMCP/workspace identity, not a TCP connection. It has bounded configurable retention/quota. Storage failure yields unknown/unavailable evidence rather than false PASS and must not block basic tools unless evidence was explicitly required.

### Policy generation

Operation context captures effective policy generation/hash. Side-effect authority is rechecked immediately before exec/commit; authority removal invalidates a prepared action. Evidence records the effective generation for completed actions.
