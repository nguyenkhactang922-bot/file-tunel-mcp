# ChatCMD to FileMCP Source Mapping

Status: SOURCE-MAPPED
Date: 2026-09-23
ChatCMD source commit: c20e134ad6b60ef12eee7231bcbca56f5252be45
FileMCP source baseline: 7b24d1124e59103f7acad8f8c9a81271efb4fb0e

This document maps concrete ChatCMD implementation concepts to exact FileMCP integration surfaces. It is intended to prevent vague "copy ChatCMD" implementation work.

## M01 - Canonical tool catalog metadata

ChatCMD evidence:
- crates/chatcmd-mcp/src/tool_catalog.rs
- crates/chatcmd-mcp/src/tool_methods.rs
- crates/chatcmd-mcp/tests/release_catalog_smoke.rs

ChatCMD capability:
- router-derived tool list;
- canonical schema manifest;
- catalog version/hash;
- instructions version/hash;
- build identity;
- per-tool capability/risk flags.

FileMCP current surfaces:
- windows/src/FileMCP.Core/LocalTools.cs
- windows/src/FileMCP.Core/CodexSkillRegistry.cs
- windows/src/FileMCP.Core/LocalMcpServer.cs
- macos/LocalMCPServer.swift
- tests/test_tool_surface_parity.ps1

Current FileMCP gap:
- schemas are defined separately in C# and Swift;
- parity proves a required tool surface but not exact schema/capability identity;
- live connector does not publish a catalog hash/build identity that CI can compare.

Recommended integration:
- introduce a language-neutral canonical catalog contract;
- derive or validate both Windows and macOS runtime-advertised tool manifests against it;
- include protocol version, catalog version/hash, instruction version/hash and build identifier;
- keep runtime authorization separate from schema descriptions.

Do not:
- make descriptions authoritative for security;
- allow a runtime to silently advertise a schema not represented in the canonical contract.

## M02 - Structured process execution

ChatCMD evidence:
- crates/chatcmd-runtime/src/command_runner.rs
- crates/chatcmd-runtime/src/command_execution_journal.rs
- crates/chatcmd-runtime/src/command_execution_registry.rs
- src/runtime_host/dispatch/command_tools.rs
- src/runtime_host/command_tests.rs

FileMCP current surfaces:
- windows/src/FileMCP.Core/ProcessRunner.cs
- macos/ProcessRunner.swift
- windows/src/FileMCP.Core/LocalTools.cs RunCommandAsync
- macos/LocalMCPServer.swift runCommand

Current FileMCP strength:
- both platforms already execute executable + argv internally;
- bounded stdout/stderr already exists;
- timeout and process-tree/process-group termination already exists.

Current FileMCP gap:
- MCP only exposes a shell-string run_command path.

Recommended integration:
- add exec_process:
  - executable;
  - arguments array;
  - cwd;
  - bounded environment overrides;
  - timeout;
  - output budget;
  - optional idempotency key later.
- return a structured process result, not only formatted text.
- preserve run_command as explicit shell compatibility/advanced mode.

Do not:
- remove run_command before compatibility data exists;
- silently shell-interpret arguments submitted to exec_process.

## M03 - Unified result/evidence envelope

ChatCMD evidence:
- crates/chatcmd-runtime/src/tool_result.rs
- crates/chatcmd-runtime/src/command_execution_journal.rs
- src/runtime_host/completion_report.rs
- docs/coding-agent-contract.md

FileMCP current surfaces:
- ToolCallOutput in windows LocalTools.cs
- MCP result construction in windows LocalMcpServer.cs
- equivalent macOS result paths
- observability and telemetry contracts

Current gap:
- generic success/result content is not the same thing as server-owned execution evidence;
- no stable execution ID/freshness contract exists for command evidence.

Recommended integration:
- common metadata envelope:
  - operationId/executionId;
  - status;
  - truncated;
  - usage;
  - warnings;
  - timestamps where useful;
  - command terminal state/exit/timedOut/cancelled for exec_process;
  - source-state fingerprint where verification depends on repository state.
- raw command text must not be persisted.

## M04 - File version tokens and optimistic concurrency

ChatCMD evidence:
- crates/chatcmd-runtime/src/filesystem/file_version.rs
- crates/chatcmd-runtime/src/filesystem_read.rs
- docs/fs-stat-versioning.md

FileMCP current surfaces:
- windows LocalTools ReadFile / ReadFileRange / WriteFile
- macos LocalMCPServer read/write equivalents
- SafePathResolver on both platforms

Current gap:
- read results do not carry version identity;
- write_file has no expected-version precondition;
- concurrent human/tool edits can be overwritten after a stale read.

Recommended integration:
- file_stat or read operations return an opaque version token;
- overwrite-capable mutation accepts expected_version;
- mismatch fails before mutation;
- version token construction must be cross-platform deterministic in semantics, not necessarily byte-identical implementation.

## M05 - Versioned range edits

ChatCMD evidence:
- crates/chatcmd-runtime/src/filesystem_apply_edits.rs
- crates/chatcmd-runtime/src/filesystem_atomic_writer.rs
- docs/fs-apply-edits.md
- adversarial filesystem tests

FileMCP current strength:
- Windows overwrite uses sibling-temp then replacement;
- macOS uses atomic data write.

Current gap:
- no first-class range edits;
- full-file rewrites are inefficient for large files;
- no expected-version protection.

Recommended integration:
- add apply_edits after M04;
- require expected_version for existing targets by default;
- reject overlapping edits;
- support dry-run;
- commit atomically;
- preserve UTF-8/newline/BOM semantics explicitly.

## M06 - Shared resource budget and cursor contract

ChatCMD evidence:
- crates/chatcmd-runtime/src/budget.rs
- filesystem_list/find/search/read implementations
- docs/tool-resource-budgets.md
- docs/tool_result_envelope.md

FileMCP current surfaces:
- FileMcpConstants caps;
- list/search/read fixed limits;
- ProcessRunner timeout/output limits;
- connection concurrency/timeouts.

Current gap:
- limits are mostly independent constants;
- no common usage report;
- no resumable cursors for large list/search/read operations.

Recommended integration:
- ToolBudget abstraction with hard server cap + caller-lowerable cap;
- common page/cursor semantics;
- usage counters and explicit truncation reason;
- cancellation checks inside long loops, not only around the wrapper.

## M07 - Large-output artifact/content references

ChatCMD evidence:
- crates/chatcmd-runtime/src/blob_store.rs
- crates/chatcmd-runtime/src/artifact_quota.rs
- blob_* MCP methods
- task artifact methods

FileMCP privacy constraint:
- observability must never persist file content, prompt/chat text, commands or tool arguments.

Recommended integration:
- not first wave;
- if introduced, large-output artifacts must be explicitly scoped, short-lived and separate from observability;
- prefer ephemeral file-backed results under controlled temp storage;
- store metadata/hashes in telemetry, not content.

## M08 - Project context digest/provenance

ChatCMD evidence:
- crates/chatcmd-runtime/src/project_context.rs
- crates/chatcmd-runtime/src/project_context/*
- docs/coding-agent-contract.md

FileMCP current surfaces:
- CodexSkillRegistry.cs
- macOS Codex skill support
- AGENTS.md and project law/state files read by ChatGPT via tools

Current gap:
- no server-owned project-context digest/freshness contract;
- rules are retrieved independently from execution evidence.

Recommended integration:
- bounded project_context tool returning:
  - discovered instruction files;
  - provenance;
  - effective hash;
  - bounded excerpts/ranges;
  - explicit statement that rules do not grant authority.
- never treat repository instructions as authorization.

## M09 - Execution policy profiles

ChatCMD evidence:
- crates/chatcmd-runtime/src/policy.rs
- src/runtime_host/approval/*
- task execution mode API
- tool capability classification

FileMCP current surfaces:
- EnableCommands boolean;
- tool availability/annotations;
- hard path/Git/runtime checks.

Current gap:
- coarse command enable/disable rather than per-risk server-owned policy.

Recommended integration:
- introduce server-owned policy profile:
  - restricted;
  - workspace-auto;
  - custom.
- classify operations by risk and effect.
- model/tool calls cannot elevate the active profile.
- normal autonomous workspace operations may be pre-authorized by the user's profile without per-call clicks.

## M10 - Persistent PTY

ChatCMD evidence:
- crates/chatcmd-runtime/src/shell.rs
- crates/chatcmd-runtime/src/shell/live.rs
- crates/chatcmd-runtime/src/shell/operations.rs
- shell_* MCP methods

FileMCP current surfaces:
- ProcessRunner one-shot execution;
- ManagedProcess internal process lifecycle.

Recommendation:
- defer;
- implement only after structured exec + budgets + policy + evidence;
- use for genuinely interactive workflows, not as the default coding command primitive.

## M11 - Task lifecycle and verification model

ChatCMD evidence:
- src/runtime_host/agent_lifecycle.rs
- src/runtime_host/completion_report.rs
- task/subagent persistence
- docs/coding-agent-contract.md

FileMCP current architecture:
- ChatGPT owns task orchestration;
- repository state files record lifecycle;
- local FileMCP observability is intentionally metadata-only.

Recommendation:
- adopt the concept of lifecycle vs workOutcome vs verification;
- do not import broad task-history persistence;
- any local evidence journal must comply with FileMCP privacy law.

## M12 - Sub-agent orchestration

ChatCMD evidence:
- src/runtime_host/subagents/*
- crates/chatcmd-mcp/src/subagent_worker.rs
- docs/subagent-reports.md
- docs/subagent-approval-grants.md

Recommendation:
- separate future ADR;
- prerequisites: M01, M03, M06, M08, M09, M11;
- no implementation in current architecture wave.

## M13 - Browser bridge

ChatCMD evidence:
- chatgpt-extension/
- browser bridge docs

FileMCP mapping:
- no corresponding subsystem required.

Decision:
- REJECT.
- FileMCP already has direct MCP connectivity and should not add ChatGPT DOM automation.

## M14 - Public tokenized MCP endpoints

ChatCMD evidence:
- /mcp/<token> transport;
- access profiles;
- user-managed public domains/tunnels.

FileMCP mapping:
- LocalMcpServer loopback;
- FILEMCP_LOCAL_AUTH_TOKEN;
- OpenAI Secure MCP Tunnel.

Decision:
- REJECT AS PRIMARY FILEMCP MODEL.
- retain FileMCP loopback + tunnel authentication architecture.

## M15 - React management console

ChatCMD evidence:
- web/

Decision:
- NOT PART OF THIS TRACK.
- underlying contracts may be useful without porting the UI.
- a UI should be justified independently after runtime functionality exists.

## M16 - Language/runtime rewrite

ChatCMD is Rust. FileMCP is C# on Windows and Swift on macOS.

Decision:
- REJECT rewrite.
- reimplement selected contracts natively in existing FileMCP codebases.
- copying MIT-licensed source is legally possible with notice preservation, but architecture and language mismatch make concept-level reimplementation preferable.
