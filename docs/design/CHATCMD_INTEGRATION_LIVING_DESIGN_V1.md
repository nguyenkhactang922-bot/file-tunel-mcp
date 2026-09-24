# ChatCMD-Inspired FileMCP Integration Living Design V1

Status: DESIGN COMPLETE - FROZEN BY ADR-0004 FOR PHASE A
Date: 2026-09-23

## Objective

Strengthen FileMCP as a reliable coding-agent execution gateway without turning it into a clone of ChatCMD.

## Target architecture

ChatGPT / MCP client
        |
        v
OpenAI Secure MCP Tunnel
        |
        v
FileMCP loopback + runtime local auth
        |
        v
Canonical Tool Catalog
(schema + catalog hash + capability class)
        |
        v
Server-owned Policy Profile
(restricted / workspace-auto / custom)
        |
        v
Operation Context
(workspace + project context hash + cancellation + budget)
        |
        +---------------------------+
        |                           |
        v                           v
Filesystem / Git              Process execution
versioned reads               exec_process
apply_edits                   run_command explicit shell path
        |                           |
        +-------------+-------------+
                      v
Structured Result + Metadata-only Evidence
                      |
                      v
Existing observability / OTLP / SQLite counters

Later, separate architecture waves may add PTY, richer task state, and sub-agents.

## Design principles

### Keep transport stable

Do not modify the OpenAI Secure MCP Tunnel architecture merely to imitate ChatCMD. The current FileMCP transport has a smaller public attack surface.

### Structured safe primitive before shell

exec_process becomes the preferred machine-execution primitive for deterministic build/test/tool invocation. run_command remains available for shell workflows.

### Version before edit

No first-class range-edit tool should ship before version tokens and expected-version validation exist.

### Budget inside loops

Search/list/read implementations must check budget/cancellation while traversing/reading, not only at the request boundary.

### Evidence is not chat history

Evidence records describe the state of an operation, not the user's content. No prompt, raw command, raw file data or Git message enters observability storage.

### Policy cannot be self-elevated

Repository instructions, tool input or model output never grant authority. Only local/user-controlled configuration may increase capability.

### Cross-platform contract first

Every common tool added to Windows must have a macOS contract and parity test in the same task or be explicitly platform-scoped before implementation.

## Phase A foundation

Phase A contains only the following foundations:

A1 canonical tool catalog/version/hash;
A2 structured result envelope;
A3 structured exec_process;
A4 file version tokens;
A5 versioned apply_edits;
A6 shared budget/cursor contract;
A7 metadata-only execution evidence;
A8 project-context digest/provenance;
A9 server-owned policy profiles;
A10 adversarial/cross-platform regression.

Persistent PTY is Phase B.

Task engine/sub-agents are Phase C and require a new ADR.

## Explicit non-goals

- browser extension;
- ChatGPT DOM control;
- public bearer-token URL transport;
- Rust migration;
- ChatCMD React UI port;
- broad local chat/task history;
- cookie/session handling;
- automatic authority escalation;
- weakening Git safe mode.
