# ChatCMD Integration Decision Matrix

Status: FROZEN FOR PHASE A
Date: 2026-09-23

Scoring is relative to FileMCP's current architecture. A high value score alone does not permit implementation if security/privacy fit is poor.

| Capability | User value | Security fit | Implementation fit | Cross-platform cost | Decision | Phase |
|---|---:|---:|---:|---:|---|---|
| Canonical tool catalog + hash | 5 | 5 | 5 | 2 | ADOPT | A |
| Tool capability/risk classification | 5 | 5 | 5 | 2 | ADOPT | A |
| Structured exec_process | 5 | 5 | 5 | 2 | ADOPT | A |
| Structured execution result/evidence | 5 | 5 | 4 | 3 | ADOPT | A |
| File version token | 5 | 5 | 4 | 3 | ADOPT | A |
| Versioned range apply_edits | 5 | 5 | 4 | 3 | ADOPT | A |
| Shared budget contract | 5 | 5 | 4 | 3 | ADOPT | A |
| Cursor/pagination for large repo tools | 4 | 5 | 4 | 3 | ADOPT | A |
| Project-context digest | 4 | 5 | 4 | 3 | ADOPT | A |
| Policy profiles allow/deny by risk | 5 | 5 | 4 | 3 | ADOPT, NO PER-CALL CLICK DEFAULT | A |
| Metadata-only evidence journal | 5 | 5 | 3 | 3 | ADOPT | A |
| Batch read/stat | 4 | 5 | 4 | 3 | DEFER | B |
| Ephemeral large-output artifacts | 4 | 4 | 3 | 3 | DEFER | B |
| Quarantine delete/restore | 3 | 5 | 3 | 3 | DEFER | B |
| Persistent PTY | 4 | 4 | 3 | 4 | DEFER | B |
| Repository path index | 3 | 4 | 2 | 4 | PROFILE FIRST | B |
| Rich local task timeline | 3 | 2 | 2 | 4 | DEFER/REDESIGN | C |
| Sub-agent orchestration | 5 | 3 | 2 | 5 | SEPARATE ADR | C |
| Lease/heartbeat/watchdog | 5 if subagents | 4 | 2 | 5 | SEPARATE ADR | C |
| Durable child reports | 5 if subagents | 3 | 2 | 4 | SEPARATE ADR | C |
| ChatGPT browser extension | 2 | 1 | 1 | 4 | REJECT | - |
| DOM conversation automation | 2 | 1 | 1 | 4 | REJECT | - |
| Public /mcp/<token> primary transport | 2 | 1 | 2 | 3 | REJECT | - |
| Recoverable public bearer tokens in SQLite | 1 | 1 | 2 | 2 | REJECT | - |
| Replace Secure MCP Tunnel | 1 | 1 | 1 | 4 | REJECT | - |
| Rust rewrite | 1 | 3 | 1 | 5 | REJECT | - |
| Broad prompt/command/file-content persistence | 2 | 1 | 2 | 3 | REJECT | - |
| Custom app-layer crypto resurrection | 1 | 2 | 1 | 4 | REJECT | - |

## Phase A ordering

1. catalog contract;
2. result envelope;
3. exec_process;
4. version token;
5. apply_edits;
6. budget/cursor contract;
7. metadata-only evidence;
8. project-context digest;
9. policy profile;
10. adversarial parity regression.

## Decision rule

No ChatCMD code is copied merely because the license permits it. Prefer concept-level reimplementation in the existing C#/Swift architecture unless exact source reuse has a demonstrated correctness or security advantage and its license notice obligations are explicitly handled.
