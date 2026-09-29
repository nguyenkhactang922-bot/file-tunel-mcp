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

## FMUX product-experience law

- FMG-001..FMG-026 remains the engine/gateway scope and MUST NOT be diluted by FMUX work.
- FMUX authority is ADR-0007 plus tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md.
- FMUX consumes core/runtime truth; presentation code must never grant authority, bypass policy, invent evidence, or expose unavailable FMG capability.
- Preserve native stacks: Windows WPF and macOS AppKit unless a future product-authority ADR explicitly changes that boundary.
- Do not start FMUX-002 before FMUX-001 MAIN VERIFIED; follow the frozen FMUX dependency graph thereafter.

## Single-project-root lock

- Canonical PROJECT_ROOT for FileMCP is **D:\Tools\FileMCP**.
- Do not create Git worktrees, sibling FileMCP clones, temporary project roots, or directories such as `D:\Tools\FileMCP-*-worktree` for normal task execution.
- Every coding chat must first verify `git rev-parse --show-toplevel` resolves to `D:/Tools/FileMCP`. If it does not, stop the coding action and return to the canonical root before reading/writing/building/committing.
- Only one coding branch may be active in the canonical working tree at a time. Other chats may inspect/monitor state, but must not create alternate worktrees to work in parallel.
- Branch changes happen in-place inside the canonical root after verifying a clean worktree and checking process/side-effect state. Preserve unfinished work with commits/remote branches; do not clone or worktree it into a sibling directory.
- Historical branch refs may remain in Git for audit/recovery. They are not separate project roots and must not be materialized as sibling worktrees without explicit user authorization that supersedes this rule.
- If a stale sibling FileMCP directory is ever discovered, audit it for unique unmerged changes first, salvage only compatible/stronger parts into the canonical branch, verify them, then delete the sibling directory.
- Generated build/test/evidence artifacts must stay under the canonical repository's managed directories unless an external platform mandates another temporary location.
- `Repo + Git + evidence + runtime state` remain source of truth; chat-stream continuity is not authority.
