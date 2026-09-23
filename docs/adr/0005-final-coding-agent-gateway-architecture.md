# ADR-0005 - Final Coding-Agent Gateway Architecture

Status: ACCEPTED / ARCHITECTURE FROZEN
Date: 2026-09-23
Supersedes: ADR-0004 where this ADR is more specific
Retains: ADR-0003 unsigned-distribution scope

## Context

FileMCP is already a verified secure local execution bridge. ADR-0004 established a ChatCMD-inspired baseline. A final source-first cross-repo audit then compared FileMCP, ChatCMD, OpenAI Codex, OpenHands, Aider, Cline and Goose, followed by function-level mapping, contradiction synthesis, independent red-team, repair and re-audit.

## Product decision

FileMCP remains a secure local coding-agent execution gateway. ChatGPT remains the reasoning/orchestration layer. FileMCP provides controlled files, Git, process execution, build/test and structured verification evidence.

It does not become a browser automation system, local general agent platform, MCP-of-MCP provider host or transcript/task database.

## Preserve

KEEP:
- loopback MCP listener;
- runtime local authentication;
- OpenAI Secure MCP Tunnel;
- native Windows C# and macOS Swift runtimes;
- Git safe mode;
- privacy-minimal observability;
- existing native ProcessRunner cleanup semantics;
- compatible existing file/Git tool surface.

KEEP + HARDEN:
- path handling with commit-time Mutation Guard;
- file/list/search/write/delete with versions/budgets/cancellation;
- run_command as explicit high-risk shell compatibility;
- cross-platform schema/parity/native verification.

## Phase A required architecture

1. canonical language-neutral tool catalog authority;
2. structured result envelope;
3. server-owned policy model + legacy migration;
4. common ToolBudget/cancellation/cursor primitives;
5. structured exec_process + environment authority;
6. strong file/source-state identity;
7. AuthorizedPathSnapshot / Mutation Guard;
8. version-checked current mutation hardening;
9. atomic versioned apply_edits;
10. bounded project-context provenance/digest;
11. metadata-only evidence/freshness;
12. full Windows/macOS adversarial/native verification.

## Catalog authority

A versioned repository artifact, target path `contracts/tool_catalog.v1.json` unless implementation discovery proves an equivalent frozen path necessary, is the single canonical MCP schema/capability authority.

It owns tool names, input/output schemas, protocol/catalog versions and risk/effect/capability metadata. Windows/macOS advertised catalogs and handler registries exact-validate against it. Catalog metadata never grants authority.

## Policy and migration

Only server-owned local policy grants authority.

Minimum user-facing profiles: restricted, workspace-auto, custom.

Migration:
- EnableCommands=false -> restricted-equivalent;
- EnableCommands=true -> migration-only legacy-command-compatible;
- workspace-auto requires explicit local user selection;
- model/repository content cannot broaden policy.

Prepared side effects capture policy generation/hash and reauthorize immediately before exec/commit.

## Process execution

KEEP native ProcessRunner.

ADD exec_process with executable, argv, contained cwd, bounded explicit environment overrides, timeout/output budget, structured terminal result and operation/evidence identity. No implicit shell interpolation.

exec_process does not inherit arbitrary host environment by default. FileMCP supplies a documented minimal platform baseline; local configuration controls additional pass-through names/patterns; request overrides are bounded and policy checked; secret-like environment variables are not implicitly forwarded.

KEEP run_command for compatibility; classify it high-risk/open-world. Existing legacy environment behavior may remain during migration.

## Filesystem mutation

ADD strong version identity and SourceStateRef.

A mutation commits only when active policy still allows, expected strong version matches, AuthorizedPathSnapshot/Mutation Guard confirms the same authorized root/parent/target identity, and atomic publish/delete succeeds.

Mutation Guard is object-identity based, not string-path-only.

ADD canonical apply_edits with expected version, non-overlap validation, dry-run, explicit BOM/newline semantics, staging, final version + Mutation Guard recheck and atomic publish.

Higher-level model edit adapters are deferred and cannot bypass this primitive.

## Resource control

ADD ToolBudget with hard server caps, caller-lower-only semantics, cooperative cancellation and explicit usage/truncation.

Read cursors are opaque/authenticated, bind tool/options/root/generation/position, are bounded-lifetime and never mutation authority.

## Evidence

ADD metadata-only evidence/freshness.

Verification states: passed, failed, not-run, unknown, stale, blocked, not-applicable.

Stdout text containing PASS is not verification authority.

Evidence may persist only operation/result metadata, SourceStateRef, artifact metadata/hash and criterion identifiers. Raw prompt/chat/tool args/commands/file contents/Git messages/secrets remain forbidden by default.

## SourceStateRef

Git-backed evidence may bind canonical worktree identity, HEAD OID, index/tree identity, tracked dirty fingerprint, scoped relevant untracked fingerprint, catalog hash, policy generation and relevant file-version references. Only metadata/digests persist.

## Project context

ADD bounded project-context provenance/digest. Repository instructions influence behavior but never authorization.

## Deferred future architecture

Separate focused ADR/profiling required for optional isolated backend, repository symbol-map implementation, workspace checkpoint/restore, persistent PTY, artifact spillover and durable command idempotency registry.

## Rejected from current core

Public bearer-token primary MCP endpoint, browser DOM/session automation, broad transcript/tool/command/file-content persistence, mandatory Docker/VM, MCP-of-MCP provider hosting, local general task manager, local sub-agent/model runtime, full-source persistent index, language rewrite and custom application-layer crypto for local obfuscation.

## Cross-platform law

No common feature passes with one-platform evidence. Every common task includes Windows + macOS implementation, equivalent security/failure semantics, adversarial tests and native/package verification where applicable.

## Migration and rollback

Phase A is additive. Existing tools remain compatible while safer primitives are introduced. No deprecation/removal without a separate compatibility decision.

New subsystems must be disableable/removable without making safe basic file/Git execution dependent on evidence/policy persistence. Persistence failure never creates false PASS.

## Freeze evidence

Cross-repo audit COMPLETE; contradiction matrix COMPLETE; function upgrade matrix COMPLETE; security/execution/large-repo/recovery designs COMPLETE; independent red-team COMPLETE; all P1 repairs COMPLETE; repair re-audit PASS; master task graph COMPLETE.

Architecture is frozen. Implementation authority is tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md.

Feature coding remains not started in this design-only handoff. Future implementation begins by claiming FMG-001 only.