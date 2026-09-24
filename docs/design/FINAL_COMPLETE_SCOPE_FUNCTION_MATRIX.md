# FINAL Complete-Scope Function / Capability Matrix

Status: FINAL PRE-ADR-0006
Date: 2026-09-24

This matrix extends FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md so no approved advanced capability remains merely DEFERRED before coding begins.

| Capability | Prior state | Complete-scope decision | Build phase | Frozen implementation direction |
|---|---|---|---|---|
| Canonical catalog / result / policy / budgets / exec / versions / Mutation Guard / apply_edits / project context / evidence | Phase A | BUILD | Foundation FMG-001..013 | unchanged under ADR-0005 contracts |
| Ephemeral artifact/content-ref store | DEFER | BUILD | Advanced | content-addressed local store, scoped authenticated refs, TTL/quota/current-user permissions |
| Batch read/stat | deferred candidate | BUILD | Advanced | per-path authorization + aggregate budget + versions + ContentRef spillover |
| Quarantine delete/restore | DEFER | BUILD | Advanced | expected-version + Mutation Guard + artifact-backed package + checkpoint-backed tree restore transaction |
| Model-friendly search/replace adapter | DEFER | BUILD | Advanced | compile to canonical apply_edits only |
| Unified-diff adapter | DEFER | BUILD | Advanced | parse/validate/compile to canonical apply_edits only |
| Repository intelligence | DEFER | BUILD | Advanced | provider architecture; built-in dependency-free LexicalSymbolProvider; heuristic/non-authoritative metadata cache |
| Persistent PTY | DEFER | BUILD | Advanced | Windows ConPTY + macOS POSIX PTY; bounded RAM ring buffer, TTL/quota, optional ContentRef spillover |
| Workspace checkpoint capture | DEFER | BUILD | Advanced | explicit policy capability; artifact-backed changed/untracked content + Git/source metadata |
| Workspace checkpoint restore | DEFER | BUILD | Advanced | rollback checkpoint + divergence refusal + transactional restore + partial_recovery_required state |
| Execution backend abstraction | DEFER | BUILD | Advanced | process + PTY only; HostExecutionBackend default |
| Optional isolated backend | DEFER | BUILD | Advanced | optional Docker backend, locally configured digest-pinned image, network-none default, strict mounts/resources |
| Durable arbitrary-command idempotency registry | DEFER | REJECT | none | crash uncertainty -> UNKNOWN + verification; no auto replay |
| Full-source persistent repository index | REJECT | REJECT | none | metadata-only cache only |
| Mandatory Docker/VM | REJECT | REJECT | none | host execution remains default |
| Local task manager | REJECT | REJECT | none | ChatGPT/repo state remains orchestrator/task authority |
| Local sub-agent/model runtime | REJECT | REJECT | none | outside FileMCP product boundary |
| MCP-of-MCP provider host | REJECT | REJECT | none | external composition remains outside FileMCP core |
| Browser DOM/session automation | REJECT | REJECT | none | direct MCP only |

## Complete-scope freeze rule

After ADR-0006 and MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md are frozen, there is no planned architecture phase between FMG-001 and final complete-product verification.

Implementation may discover task-level defects and may refine code/tests inside these contracts. Any change that alters product boundary, trust model, persistence class or dependency ordering requires an explicit new ADR rather than silent redesign.