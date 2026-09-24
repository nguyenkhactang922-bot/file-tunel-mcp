# AGENTS.md

## Repository-specific rules

- Repository: FileMCP.
- Follow docs/process/IDEA_CAPTURE_AND_DESIGN_LAW.md for every new feature or architectural change.
- Keep MCP listeners loopback-only.
- Never weaken shared-root containment, reparse/junction defenses, Git safe mode, secret redaction, or tunnel environment allowlisting.
- Runtime API keys/local-auth tokens stay in Credential Manager or transient process environment, never telemetry/state files.
- Observability stores metadata/counters only. Never persist request/response bodies, tool arguments, commands, file contents, Git messages, prompt/chat text, cookies, or bearer credentials.
- Token metrics must be labeled as MCP payload estimates unless an upstream source provides authoritative usage.
- Multi-drive workspaces remain independent security/runtime boundaries; aggregation is read-only.
- TCP connections must never be presented as distinct chats.
- Build/test evidence is mandatory before PASS.
- Lifecycle after architecture freeze: CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> REVIEW -> MERGE -> DONE.

## Complete-current-scope pre-code law

- FileMCP follows complete-scope-first design. Before the first feature implementation task is claimed, every capability/phase in the currently approved upgrade scope must be captured, deep-dived, compared, independently reviewed/red-teamed, repaired, architecture-frozen, dependency-checked, and task-split.
- Do not deliberately stop at an intermediate implementation milestone to reopen a known later architecture phase. Known later-scope items must be resolved before coding as BUILD, REJECT, or explicitly OUT-OF-SCOPE by product authority.
- Ambiguous `DEFER` is not an acceptable final pre-code state for a capability already inside the currently desired product scope.
- For the current FileMCP complete upgrade, ADR-0006 and `tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md` are the ordering authorities. FMG-001 is the only initial READY task; FMG-013 is a foundation milestone; FMG-026 is the complete-upgrade final gate.
- Any later change to product boundary, trust boundary, persistence class, or dependency architecture requires a new ADR/review round; task-level implementation detail may evolve inside the frozen contracts.
