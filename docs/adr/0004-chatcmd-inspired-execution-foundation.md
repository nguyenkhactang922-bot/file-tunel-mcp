# ADR-0004 - ChatCMD-Inspired Coding-Agent Execution Foundation

Status: ACCEPTED
Date: 2026-09-23
Scope: FileMCP future architecture Phase A
Reference implementation audited: int04/ChatCmd at c20e134ad6b60ef12eee7231bcbca56f5252be45

## Context

FileMCP's current architecture is a hardened local execution bridge with strong workspace, Git, process and tunnel boundaries. ChatCMD demonstrates several mature contracts that can improve coding-agent reliability, especially around structured execution, optimistic concurrency, tool-catalog consistency, resource budgets and evidence.

A wholesale ChatCMD integration would also bring product surfaces that FileMCP does not need: public bearer-token endpoints, a browser DOM bridge, broad task-history persistence, a React management console, and a significantly larger task/sub-agent runtime.

The architecture therefore needs a selective decision.

## Decision

FileMCP will adopt selected ChatCMD-inspired contracts by reimplementing them natively in the existing Windows C# and macOS Swift runtimes.

The existing FileMCP transport, authentication, workspace containment and Git-safe architecture remain authoritative.

### Phase A accepted foundations

1. Canonical tool catalog metadata
   - protocol version;
   - catalog version;
   - catalog hash;
   - instruction version/hash;
   - build identity;
   - risk/effect/capability classification.

2. Structured result envelope
   - status;
   - truncation reason;
   - usage;
   - warnings;
   - operation/execution identity where needed.

3. Structured exec_process
   - executable + arguments array;
   - cwd;
   - bounded environment override;
   - timeout/output budget;
   - structured terminal result;
   - run_command remains as explicit shell compatibility.

4. Optimistic filesystem concurrency
   - opaque version tokens;
   - expected-version preconditions;
   - versioned reads/stats.

5. Atomic range editing
   - non-overlapping range edits;
   - expected version;
   - dry-run;
   - atomic commit;
   - explicit text metadata behavior.

6. Common resource budgets and resumable cursors
   - server hard caps;
   - caller may only lower caps;
   - cooperative cancellation in long loops;
   - explicit usage/truncation/page metadata.

7. Metadata-only evidence
   - operation ID;
   - tool class/name;
   - timestamps/state;
   - process exit/timeout/cancel state;
   - source fingerprints when required for freshness;
   - no raw prompt, command, tool args, file content or Git message persistence.

8. Bounded project-context digest/provenance
   - project instruction discovery;
   - source/provenance;
   - effective hash;
   - repository rules never grant authority.

9. Server-owned policy profiles
   - restricted;
   - workspace-auto;
   - custom;
   - model/tool input cannot increase authority;
   - autonomous normal workspace operations need not require per-call confirmation when pre-authorized locally.

## Deferred

Phase B candidates:
- persistent PTY;
- batch read/stat;
- ephemeral large-output artifacts;
- quarantine delete/restore;
- optional repository index.

These require their Phase A dependencies first.

## Separate future ADR required

Phase C:
- local task engine beyond current observability;
- sub-agent orchestration;
- nested delegation;
- approval-grant inheritance;
- lease/heartbeat/watchdog;
- durable child reports.

Sub-agent work may not begin merely because ChatCMD already implements it.

## Rejected

The following are explicitly outside this architecture:

- replacing OpenAI Secure MCP Tunnel;
- public tokenized MCP URLs as the FileMCP primary transport;
- recoverable public bearer tokens in FileMCP SQLite;
- ChatGPT DOM/browser extension automation;
- cookie/session extraction or browser-session control;
- broad prompt/tool/command/file-content persistence;
- Rust rewrite;
- ChatCMD React UI port as part of runtime foundation;
- custom application-layer crypto as an obfuscation layer;
- any weakening of path containment or Git safe mode.

## Cross-platform source-of-truth strategy

FileMCP has two native runtime implementations, so it cannot copy ChatCMD's single Rust-router derivation literally.

Phase A must introduce a language-neutral canonical catalog manifest/contract and verify both runtime-advertised catalogs against that source. Runtime handlers remain native, but CI must fail on schema/capability drift.

No new common tool is PASS until:
- Windows implementation passes;
- macOS implementation passes;
- exact catalog parity passes;
- packaged/native CI evidence passes when applicable.

## Privacy decision

ChatCMD's broad task timeline is not imported.

Any new durable evidence must remain compatible with AGENTS.md:
- no raw prompt/chat text;
- no raw tool arguments;
- no raw commands;
- no file contents;
- no Git commit messages;
- no cookies or bearer credentials.

If a future feature requires content persistence, it needs a new privacy/security ADR before implementation.

## Compatibility

run_command is retained.

New safer primitives are additive. Existing clients may continue using old tools during migration. Deprecation requires usage evidence and a separate compatibility decision.

## Rollback rule

Phase A should be implemented additively behind stable contracts. If a new subsystem proves unreliable, old FileMCP tool behavior remains available while the new tool is disabled or removed. Database schema must not be used to make core file/Git execution dependent on the new evidence layer.

## Acceptance for architecture freeze

This ADR is frozen when:
- independent audit exists;
- source mapping exists;
- solution matrix exists;
- task dependency graph exists;
- rejected subsystems are explicit;
- no feature code has been introduced by this design task.

All conditions are satisfied by the accompanying ChatCMD integration design documents.
