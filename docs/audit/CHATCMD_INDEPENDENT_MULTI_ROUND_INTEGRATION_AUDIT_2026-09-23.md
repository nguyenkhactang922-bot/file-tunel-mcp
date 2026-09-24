# ChatCMD Independent Multi-Round Integration Audit

Status: FINAL DESIGN AUDIT
Date: 2026-09-23
Audited ChatCMD commit: c20e134ad6b60ef12eee7231bcbca56f5252be45
Audited FileMCP baseline: 7b24d1124e59103f7acad8f8c9a81271efb4fb0e
ChatCMD license at audited commit: MIT

## Method

This audit intentionally separates product fit from implementation admiration. Each round asks a different question so that the same appealing feature is not allowed to justify itself from only one perspective.

Evidence was taken from ChatCMD source, MCP schemas, runtime code, tests and documentation at the pinned commit, then mapped against the current FileMCP Windows and macOS implementations. Plan documents were treated as proposals unless corresponding runtime/schema/test evidence was found.

A local ChatCMD runtime test attempt was also made. Rust compilation did not reach repository tests because the audit machine lacked dlltool.exe; Cargo exited 101 while compiling dependencies. This is classified as AUDIT-ENVIRONMENT-BLOCKED, not a ChatCMD test failure. No PASS claim is made from that attempt.

## Round 1 - Product overlap and architectural fit

ChatCMD and FileMCP overlap in the local-worker/MCP problem space but solve it at different layers.

ChatCMD is a broader supervised-agent platform: Rust server, permission/access profiles, structured process execution, persistent PTY, large-repository filesystem tools, task/turn lifecycle, approvals, SQLite task/event persistence, sub-agent orchestration, React management console, and an optional ChatGPT browser extension.

FileMCP is a narrower hardened execution bridge: native Windows/macOS runtimes, loopback MCP, OpenAI Secure MCP Tunnel, runtime local auth, strict shared-root containment, hardened Git safe mode, file/Git/shell tools, Codex skill discovery, logical-chat observability and bounded process execution.

Independent conclusion: do not merge ChatCMD as a platform. FileMCP should remain a focused execution gateway. Adopt selected contracts that improve correctness, evidence and scalability without importing ChatCMD's entire task/UI/browser product.

## Round 2 - Is the interesting ChatCMD work actually shipped?

Confirmed implemented source paths include:

- structured process execution: crates/chatcmd-runtime/src/command_runner.rs; src/runtime_host/dispatch/command_tools.rs; src/runtime_host/command_tests.rs
- versioned range editing: crates/chatcmd-runtime/src/filesystem_apply_edits.rs; crates/chatcmd-runtime/src/filesystem/file_version.rs; docs/fs-apply-edits.md
- atomic filesystem publishing: crates/chatcmd-runtime/src/filesystem_atomic_writer.rs
- bounded operation budgets: crates/chatcmd-runtime/src/budget.rs; docs/tool-resource-budgets.md
- canonical catalog metadata/hash: crates/chatcmd-mcp/src/tool_catalog.rs; crates/chatcmd-mcp/tests/release_catalog_smoke.rs
- task-quality/evidence model: src/runtime_host/completion_report.rs; crates/chatcmd-runtime/src/command_execution_journal.rs; crates/chatcmd-runtime/src/command_execution_registry.rs
- approvals/grants: src/runtime_host/approval/*; docs/approval-grants.md
- sub-agent start/wait/reporting: src/runtime_host/subagents/*; docs/subagent-reports.md; docs/subagent-approval-grants.md
- project context: crates/chatcmd-runtime/src/project_context.rs and crates/chatcmd-runtime/src/project_context/*
- persistent PTY: crates/chatcmd-runtime/src/shell.rs and crates/chatcmd-runtime/src/shell/*

Independent conclusion: the strongest candidate ideas are grounded in real source. However, plan/ still contains proposals and partial future directions; no feature is accepted solely because a plan file exists.

## Round 3 - Security and trust-boundary comparison

ChatCMD strengths include server-derived task/session identity, tool allowlists, execution modes separated from tool presence, structured executable/argv process boundaries, canonical workspace/path checks, approval digests, stale-approval invalidation, child-agent authority narrowing and bounded resource budgets.

FileMCP strengths that must not be replaced include loopback-only MCP, fresh runtime local-auth token, OpenAI Secure MCP Tunnel header injection, no need to publish a bearer-token MCP URL, strong Git metadata/worktree/common-dir/object-dir containment, safe-mode hook/signing/content-filter/config hardening and explicit non-interactive Git behavior.

ChatCMD supports tokenized MCP endpoints such as /mcp/<token> and optional user-managed public tunnels/reverse proxies. Public plugin-link tokens can be stored recoverably so the UI can reproduce a link. That solves a ChatCMD product requirement FileMCP does not have and would enlarge FileMCP's credential/exposure surface.

Independent conclusion: keep FileMCP transport/auth architecture. Import authority classification ideas, not ChatCMD's URL-token/public-endpoint model.

## Round 4 - Canonical tool catalog and cross-platform drift

ChatCMD tool_catalog.rs derives tool names from the same router that advertises schemas and computes protocol version, catalog version/hash, instruction version/hash, build ID and capability flags such as operation class, risk class, mutation, cursor, budget, dry-run and expected-version support.

FileMCP today hand-authors tool schemas in Windows LocalTools.cs, CodexSkillRegistry.cs, LocalMcpServer.cs and macOS LocalMCPServer.swift. There is a parity test, but no canonical catalog hash/version contract exported by the runtime.

Independent conclusion: strong adoption candidate. This directly reduces future Windows/macOS schema drift and makes live connector/release verification stronger.

## Round 5 - Structured process execution and evidence

ChatCMD command_run accepts executable + argv + cwd rather than an implicit shell string. Results expose execution identity/state, bounded output, timeout/cancel data and evidence semantics. Tool-call success is explicitly not equivalent to process success.

FileMCP's underlying runners are already structured.

Windows: ProcessRunner.RunAsync(executable, arguments, cwd, environment, timeoutSeconds, outputLimitBytes, cancellationToken).

macOS: ProcessRunner.run(executable:arguments:cwd:environment:timeoutSeconds:outputLimitBytes:shouldCancel:).

Both already enforce bounded output and process-tree/group cleanup. However, MCP-facing run_command converts an arbitrary command string into PowerShell -Command on Windows or shell -lc on macOS.

Independent conclusion: highest-value low-risk candidate. Add a new structured exec_process tool over the runners that already exist. Keep run_command as an explicit advanced-shell compatibility path. Do not replace the current runners.

## Round 6 - Filesystem correctness and optimistic concurrency

ChatCMD implements versionToken, expectedVersion, fs_apply_edits, non-overlapping range validation, dry-run, atomic writer, content/BOM/newline handling and version revalidation before commit.

FileMCP Windows write_file stages to a sibling temp file and then uses atomic replacement semantics; macOS uses atomic Data.write. This is already better than direct truncate/write, but there is no optimistic concurrency token. A model can read version A and later overwrite version B if another actor changes the file between read and write. There is also no range-edit primitive.

Independent conclusion: strong adoption candidate, but reimplement to FileMCP's simpler needs. Start with opaque version tokens + expected_version, then add atomic range edits. Do not import ChatCMD's entire blob/file subsystem initially.

## Round 7 - Large-repository scalability and resource budgets

ChatCMD contains shared budget abstractions and v2 tools for cursor/paginated list, bounded search, streaming text reads, batch reads/stats, repository path index and bounded mutation operations.

FileMCP already has useful fixed caps: file-size limits, response limits, search result caps, tool/process concurrency, command timeout/output limits and HTTP connection/read bounds. But the limits are mostly tool-specific constants. Search/list/read do not expose a common usage/truncation envelope or resumable cursor contract.

Independent conclusion: adopt a shared budget/result envelope and cursor semantics, not every ChatCMD indexing feature at once. A repository index should remain optional until profiling proves it necessary.

## Round 8 - Approval, authority and autonomous operation

ChatCMD separates tool allowlist, execution mode allow|approval|deny, server-derived authority, one-shot consent, reusable approval grants and child-agent grant narrowing. The model cannot grant itself authority.

FileMCP's primary command boundary is EnableCommands, plus tool presence/annotations and hard runtime safety checks. FileMCP intentionally avoids storing sensitive task content.

FileMCP's intended workflow is highly autonomous. Requiring a click for every normal edit/build/test/Git operation would make it worse for its target workflow.

Independent conclusion: adopt server-owned execution profiles and fail-closed classification, but not ChatCMD's approval-heavy UX by default. A future FileMCP policy should support restricted, workspace-auto and custom profiles. The model must never be able to switch to a more permissive profile.

## Round 9 - Task lifecycle, completion quality and evidence

ChatCMD distinguishes lifecycle completion, claimed work outcome and verification state. A child/tool saying PASS is not evidence. Verification can be passed, failed, notRun, stale or unknown depending on server-owned evidence.

FileMCP has logical chat correlation and observability, but intentionally does not persist prompt/chat/tool-argument/command/file-content data. Its project execution law currently lives in repository state files and ChatGPT orchestration rather than a durable local task engine.

Independent conclusion: the evidence model is valuable; the full ChatCMD task-history database is not automatically compatible with FileMCP privacy law.

Any FileMCP evidence journal must be metadata-only by default: execution ID, tool class/name, timestamps, exit/timeout/cancel state, bounded hashes/fingerprints where appropriate, artifact metadata and source-state fingerprint. It must not persist raw command, prompt, file contents or Git messages.

## Round 10 - Persistent PTY

ChatCMD supports create/write/wait/read/signal/resize/list/inspect/close PTY operations with replay cursors. FileMCP has robust one-shot process runners and managed processes for internal runtime/tunnel needs, but no MCP-facing persistent interactive terminal.

Independent conclusion: useful for REPLs, interactive CLIs, debuggers and long-lived dev processes, but not foundational for safe coding automation. Defer until structured exec_process, evidence and budgets are stable.

## Round 11 - Sub-agents

ChatCMD sub-agent orchestration includes child tasks, global concurrency, nested delegation, lease/heartbeat/watchdog behavior, narrowed approval grants and durable reports.

FileMCP has no local sub-agent task engine. ChatGPT is currently the orchestrator and FileMCP is intentionally the execution bridge.

Independent conclusion: sub-agents could eventually make FileMCP a broader agent-runtime product, but they introduce authority inheritance, scheduling, durable task state, concurrency, report/evidence ownership, restart recovery and privacy complexity. Do not implement sub-agents in the first integration wave. Require a separate future ADR.

## Round 12 - Browser extension, public endpoints, UI and persistence

ChatCMD's optional browser extension drives an already signed-in ChatGPT tab through DOM selectors. It creates browser trust boundaries, selector maintenance, tab/conversation identity complexity and a second orchestration path. FileMCP already has direct MCP connectivity. Reject this integration.

The React management console is useful for ChatCMD's persisted task/approval/terminal product. FileMCP does not need to import the UI to gain the underlying contracts. Do not port the React console as part of this track.

ChatCMD persists task/timeline/artifact information much more broadly than FileMCP's current privacy rule permits. FileMCP must not import persistence behavior that stores prompts, commands, tool args or file content.

At the audited ChatCMD commit, docs/ENCRYPTION_PROTOCOL.md says the old custom ECDH/HKDF/AES-GCM management-API encryption was removed, while docs/ARCHITECTURE.md still contains one sentence describing that removed handshake immediately before describing ordinary JSON. This is a documentation inconsistency, not proof of a runtime vulnerability, but it reinforces a key audit rule: source + tests, not prose alone, determine integration truth.

# Consolidated independent findings

First architecture wave:
- canonical catalog metadata/hash and capability classification;
- structured exec_process over existing process runners;
- unified structured tool/execution result envelope;
- file version tokens + expected-version preconditions;
- atomic versioned range edits;
- common budget/cursor/truncation contract;
- metadata-only execution evidence/freshness;
- bounded project-context digest/provenance;
- server-owned execution policy profiles with no model self-elevation.

After foundation:
- large-output artifact references;
- batch read/stat;
- quarantine delete/restore;
- persistent PTY;
- richer task lifecycle;
- optional repository index.

Separate future ADR:
- sub-agent orchestration;
- nested delegation;
- lease/heartbeat/watchdog;
- durable child reports.

Explicitly rejected for FileMCP:
- ChatGPT DOM/browser-extension automation;
- tokenized public MCP URL as FileMCP's primary access model;
- recoverable public bearer tokens in FileMCP SQLite;
- replacement of OpenAI Secure MCP Tunnel;
- Rust rewrite;
- copying ChatCMD's broad task-history persistence;
- reintroducing custom application-layer encryption;
- weakening Git safe mode or root containment.

# Final audit position

ChatCMD is a useful architectural reference, not a replacement codebase.

The correct direction is FileMCP security/runtime foundation plus selected ChatCMD-inspired correctness/evidence contracts. This creates a stronger coding-agent execution gateway without inheriting ChatCMD's broader browser/UI/public-endpoint trust surface.

No feature implementation should begin until the source mapping, decision matrix, ADR and task graph in this design track are frozen.
