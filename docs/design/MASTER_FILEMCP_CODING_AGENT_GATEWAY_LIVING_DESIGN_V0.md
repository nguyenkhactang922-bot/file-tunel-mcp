# MASTER FileMCP Coding-Agent Gateway Living Design V0

Status: LIVING DRAFT — NOT ARCHITECTURE FREEZE
Date: 2026-09-23
Baseline HEAD: 38026d8a23136b9371369855354acabe4bb8b3e2
Authority inputs: the 14 new Markdown artifacts created on 2026-09-23 plus current AGENTS/process/execution laws and exact current source.

## Purpose

This is the continuously updated working design for the next FileMCP architecture. It intentionally sits above ADR-0004 while the final cross-repo audit is in progress. It must change when source evidence or independent review disproves an assumption.

No feature code may be implemented from this document until the final comparative audit, ADR-0005 and master dependency graph are complete.

## Problem statement

FileMCP is already a verified local execution bridge with strong loopback authentication, shared-root containment, Git safe mode, native Windows/macOS runtimes, bounded one-shot process execution, tool-surface parity checks and privacy-minimal observability. The next problem is not to rebuild those strengths. The problem is to make the bridge substantially more reliable for coding-agent work without expanding its trust surface unnecessarily.

The next architecture must answer five gaps that remain source-visible today:

1. tool contracts are duplicated across native implementations and lack one canonical catalog hash/version authority;
2. MCP command execution is shell-string-facing even though native ProcessRunner layers already support executable + argv;
3. file reads/writes lack optimistic-concurrency identity and version-checked mutation;
4. large-repository list/search/read operations use fixed limits rather than one resumable budget/cursor contract;
5. FileMCP has observability but not a formal metadata-only evidence/freshness model for deciding whether a verification claim still applies to current source state.

The final audit must also decide whether FileMCP actually needs additional primitives that ADR-0004 only deferred or did not settle: optional sandboxing, repository-symbol maps, checkpoint/recovery, PTY, MCP composition, a local task engine and sub-agents.

## Current strengths that begin as preservation candidates

These are not pre-declared immutable winners; they are protected until a stronger source-backed alternative proves otherwise:

- loopback MCP listener + runtime local auth;
- OpenAI Secure MCP Tunnel integration instead of public bearer-token MCP URLs;
- SafePathResolver/shared-root containment and reparse/junction defenses;
- Git safe mode: worktree/metadata containment, hook/signing/config/content-filter restrictions and non-interactive behavior;
- native Windows C# + macOS Swift implementation rather than a cross-language rewrite;
- bounded ProcessRunner implementations with process-tree/process-group cleanup;
- metadata/counter-only observability and secret redaction;
- cross-platform contract verification and native CI.

## Preliminary target layers — subject to audit

```text
MCP CLIENT / CHATGPT
        ↓
SECURE TUNNEL + LOOPBACK AUTH
        ↓
CANONICAL CATALOG + CAPABILITY CLASSIFICATION
        ↓
SERVER-OWNED POLICY / AUTHORITY
        ↓
OPERATION CONTEXT
workspace + project-context digest + cancellation + resource budget
        ↓
┌──────────────────────┬──────────────────────┬─────────────────────┐
│ FILESYSTEM           │ GIT                  │ PROCESS             │
│ versioned read/stat  │ existing safe mode   │ exec_process        │
│ expected-version     │ structured results   │ explicit run_command│
│ atomic apply_edits   │ source fingerprint   │ optional later PTY  │
└──────────────────────┴──────────────────────┴─────────────────────┘
        ↓
STRUCTURED RESULT / METADATA-ONLY EVIDENCE
        ↓
OBSERVABILITY / HEALTH / OPTIONAL EPHEMERAL ARTIFACTS
```

## Unresolved architecture decisions

These remain OPEN until cross-repo evidence is complete:

- host execution only vs host + policy vs optional sandbox vs mandatory sandbox;
- whether exec_process needs only the existing ProcessRunner or a durable execution registry/journal;
- exact file version-token strength and mutation semantics;
- whether patch/search-replace/model-specific editing belongs above apply_edits;
- whether project-context digest alone is enough for large repositories or a symbol/repository map is required;
- whether checkpoints should exist independently of Git and evidence;
- whether persistent PTY belongs in Phase B or must move earlier;
- whether FileMCP should compose external MCP servers or simply coexist with them;
- whether any local task/sub-agent runtime is justified at all.

## Preliminary sequencing hypothesis — NOT FINAL TASK GRAPH

```text
catalog authority
  ↓
structured result contract
  ↓
structured exec_process       file version identity
        ↓                           ↓
execution evidence             versioned mutation/apply_edits
        \                           /
         \                         /
          shared budget/cursor/freshness
                    ↓
          project-context decision
                    ↓
            policy/autonomy model
                    ↓
       recovery/checkpoint decision
                    ↓
          optional sandbox decision
                    ↓
            independent red-team
```

This sequence may change after Codex/OpenHands/Aider/Cline/Goose comparison.

## Design update rule

After every deep-dive subsystem audit:

1. record the source evidence separately;
2. change this living design only when evidence materially changes a decision;
3. record why the decision changed;
4. do not silently convert an OPEN question into a frozen decision;
5. do not create implementation tasks until dependency contradictions are resolved.

## Current design status

- 14 source documents ingested: COMPLETE.
- current FileMCP source baseline mapped: IN PROGRESS.
- ChatCMD deep audit: COMPLETE baseline, must be revalidated against final comparisons.
- Codex audit: COMPLETE - source audit at docs/audit/CODEX_SOURCE_AUDIT_2026-09-23.md.
- OpenHands audit: PENDING.
- Aider audit: PENDING.
- Cline audit: PENDING.
- Goose audit: PENDING.
- independent contradiction/red-team rounds: PENDING.
- ADR-0005: NOT CREATED.
- final task graph: NOT CREATED.
- feature coding: FORBIDDEN.

## Codex R2 architecture update

Pinned source: openai/codex@cb1eea3e98ebc433ab5f9c12ce043e979d1902df

1. Policy authority is a stronger invariant: future risk/capability catalog metadata never grants authority; active authority is server-owned. Filesystem and network dimensions remain separable and deny rules survive escalation.

2. Optional OS sandbox remains OPEN but serious. Codex ships/test platform sandbox machinery deeply. OpenHands must decide host-native sandbox vs optional container/remote isolation vs host-first only.

3. Structured exec_process remains the preferred new MCP primitive. Codex internal command lifecycle confirms executable/argv-style structure plus bounded cancellation, while FileMCP should expose that safer boundary directly.

4. Atomic versioned editing remains stronger than Codex apply_patch for Phase A. Codex patch tests prove partial side effects can remain after later failure, so expected-version atomic edits stay foundational.

5. Project context is strengthened: hierarchical instruction discovery, source provenance, bounded bytes and untrusted-project behavior become target requirements. Repository instructions are context, never authorization.

6. Broad local thread/rollout persistence is rejected. A much smaller metadata-only checkpoint layer stays OPEN pending Cline/OpenHands.

Open after Codex: optional isolation model; repository symbol map; minimal checkpoint/recovery; PTY timing; external MCP composition; local task/sub-agent runtime.
