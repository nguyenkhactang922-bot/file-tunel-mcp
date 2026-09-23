# FileMCP Function Upgrade Matrix — Living V0

Status: LIVING INVENTORY — NOT FINAL DECISION MATRIX
Date: 2026-09-23
Baseline HEAD: 38026d8a23136b9371369855354acabe4bb8b3e2

This matrix is deliberately preliminary. Actions can change after cross-repo audit. Exact current FileMCP source is the baseline; reference-repo features do not automatically win.

| Current capability | Exact current source | Current strength | Current gap / question | Preliminary action | Evidence still required |
|---|---|---|---|---|---|
| MCP loopback/local auth | Windows LocalMcpServer.cs / macOS LocalMCPServer.swift / credential store/runtime | narrow local boundary; runtime token | compare policy/sandbox interaction | KEEP candidate | Codex/OpenHands security comparison |
| Secure MCP Tunnel | LocalMcpRuntime/TunnelSupervisor + macOS equivalent | avoids public token URL | none established | KEEP candidate | cross-repo transport comparison |
| SafePathResolver / path safety | Windows SafePathResolver.cs + macOS path logic | strong root/reparse containment | mutation-time concurrency not represented | KEEP + HARDEN candidate | adversarial path/version audit |
| Tool definitions/catalog | LocalTools.cs + CodexSkillRegistry.cs + LocalMcpServer.cs + macOS LocalMCPServer.swift | working parity test | no single canonical schema/hash/capability authority | ADAPT candidate | ChatCMD/Codex/Goose catalog audit |
| read_file | LocalTools.cs + macOS equivalent | bounded | no version identity | KEEP + HARDEN candidate | version-token design |
| read_file_range | LocalTools.cs + macOS equivalent | bounded targeted reads | no resumable cursor/version token | KEEP + HARDEN candidate | large-file audit |
| list/search tools | LocalTools.cs + macOS equivalent | hard caps and counters | no shared budget/cursor contract; no symbol map | ADAPT candidate | Aider/ChatCMD large-repo audit |
| write_file | LocalTools.cs + macOS equivalent | atomic replace behavior | stale-read overwrite possible; no expected version | KEEP + HARDEN candidate | ChatCMD/Codex edit audit |
| delete_file/delete_directory | LocalTools.cs + macOS equivalent | root/path safety | no version precondition/quarantine | KEEP + HARDEN or DEFER quarantine | mutation/recovery audit |
| ProcessRunner | ProcessRunner.cs + macOS ProcessRunner.swift | executable+argv internally, bounded output, timeout, process cleanup | no first-class MCP execution identity; no general OS sandbox | KEEP + HARDEN candidate | Codex S1 confirms bounded lifecycle; OpenHands decides isolation layer |
| run_command | LocalTools.cs / macOS LocalMCPServer.swift | flexible compatibility shell | MCP boundary is shell-string-facing | KEEP compatibility + ADD exec_process candidate | Codex internal Vec<String> lifecycle + ChatCMD structured boundary support this split |
| Git safe mode | GitTools.cs + macOS equivalent | strong metadata/config/hook/filter containment | checkpoint semantics separate question | KEEP candidate | Aider/Codex/Cline Git audit |
| Codex skill registry | CodexSkillRegistry.cs + macOS equivalent | bounded skill discovery/load | no unified project-rule digest/provenance | ADAPT candidate | Codex S1 AGENTS hierarchy/provenance/budget; Aider decides symbol-map need |
| Observability correlation | LogicalChatCorrelation/Session/Hub + macOS equivalent | privacy-minimal metadata model | not a verification/evidence authority | KEEP + HARDEN candidate | evidence/freshness audit |
| Telemetry persistence | TelemetryPersistence.cs + macOS equivalent | counters/metadata persistence | evidence retention/quotas must remain separate | KEEP candidate | persistence/privacy audit |
| Tunnel supervision | TunnelSupervisor.cs + macOS equivalent | bounded recovery already verified | no architectural gap established | KEEP candidate | OpenHands/Cline recovery comparison |
| Canonical catalog hash/version | absent | — | cross-platform drift authority | ADD candidate | final catalog decision |
| exec_process | absent as MCP tool; runners already support argv | low implementation delta | schema, env policy, result contract unresolved | ADD candidate | Codex S1 lifecycle confirms bounds/cancel; preserve explicit executable+argv rather than shell-string schema |
| structured evidence envelope | absent as first-class authority | — | PASS/freshness/ownership unresolved | ADD candidate | ChatCMD/Cline/OpenHands evidence audit |
| file version token | absent | — | optimistic concurrency missing | ADD candidate | exact token semantics audit |
| apply_edits | absent | - | range edits/expected version missing | ADD candidate | Codex apply_patch S1 is rich but explicitly permits partial side effects; do not use it as atomic/versioned replacement |
| shared budget/cursor | partial fixed caps only | current caps protect runtime | no common resumable contract | ADAPT/ADD candidate | ChatCMD large-repo audit |
| repository symbol map/index | absent | no persistence complexity today | large-repo context may be weak | OPEN | Aider deep audit + profiling |
| checkpoint/recovery layer | no dedicated subsystem | Git + state files remain simple | crash/resume semantics not formalized | OPEN, broad rollout persistence REJECTED | Codex S1 thread/rollout persistence is too broad for FileMCP privacy; Cline/OpenHands decide minimal layer |
| policy profiles | coarse EnableCommands + hard safety checks | simple and fail-closed in safe mode | no risk-class profile model | ADAPT candidate - strengthened by Codex | Codex S1 approval/sandbox tests require no self-elevation and separate FS/network authority |
| persistent PTY | absent MCP-facing | avoids state complexity today | interactive workflows unsupported | DEFER candidate | Codex unified exec proves value but not foundation priority; Cline/OpenHands still required |
| local task/sub-agent runtime | absent | ChatGPT remains orchestrator; privacy simple | may limit local orchestration | REJECT/DEFER pending audit | Goose/ChatCMD/OpenHands comparison |

No row in this file is authorization to code.

## Codex R2 update - 2026-09-23

Source audit: docs/audit/CODEX_SOURCE_AUDIT_2026-09-23.md

Material decision changes:

- policy profiles are now a source-backed multi-reference requirement: server-owned authority, separate filesystem/network dimensions, no model self-elevation;
- optional OS sandbox remains OPEN until OpenHands, but Codex proves it is a mature serious candidate;
- exec_process(executable,args[]) remains preferred because Codex internal execution is structured even when model-facing exec may remain shell-oriented;
- Codex apply_patch is not accepted as the Phase A atomic edit foundation because its own tests explicitly preserve partial changes after later failure;
- project_context must include hierarchical provenance, digest/budget and a no-authority rule; untrusted/restricted mode must suppress or demote repository-owned instructions;
- broad Codex rollout/thread persistence is REJECTED for current FileMCP privacy/product scope;
- future catalog risk/effect metadata is descriptive only; server-owned policy is authorization.
