# TASK QUEUE - FileMCP Observability V1 (historical completed queue)

This queue is retained as implementation history. All tasks listed here are complete.
Current final-product work is tracked in `tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`.

| ID | State | Depends | Acceptance |
|---|---|---|---|
| FMR-001 | PASS | - | Drive-root descendants resolve; root list/read/write/search work; traversal/junction/root-delete protections pass |
| OBS-001 | PASS | FMR-001 | Usage contracts, bytes_div_4_v1 estimator, classifier, semantics tests |
| OBS-002 | PASS | OBS-001 | Interlocked hot counters, exact concurrent increments, snapshot/delta tests |
| OBS-003 | PASS | OBS-002 | SQLite WAL schema/versioning, pending-delta retry tests |
| OBS-004 | PASS | OBS-003 | minute/hour/day period queries and retention tests |
| OBS-005 | PASS | OBS-003 | LocalMcpServer telemetry hooks preserve protocol/security behavior |
| OBS-006 | PASS | OBS-005 | process-wide C/D/E/F hub and uptime |
| OBS-007 | PASS | OBS-005 | `filemcp_observability_connect`, optional `_filemcp_chat`, no-authority semantics |
| OBS-008 | PASS | OBS-007 | logical/unbound session registry, active/idle/stale, hashed durable id |
| OBS-009 | PASS | OBS-004,OBS-006 | Overview dashboard sourced from Core snapshots |
| OBS-010 | PASS | OBS-008,OBS-009 | period controls/session detail/exact-chat feature gate |
| OBS-011 | PASS | OBS-010 | bounded realtime graph + measurable health |
| OBS-012 | PASS | OBS-011 | privacy/concurrency/corruption/migration/security regression |
| OBS-013 | PASS | OBS-012,V11-008 | live ChatGPT connector correlation proof |

## Canonical PROJECT_ROOT historical note

FileMCP is locked to `D:\Tools\FileMCP`. Sibling FileMCP worktrees were audited and removed on 2026-09-29. Active continuation is tracked only in `CURRENT_HANDOFF.md` and `tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`.

## Current complete-upgrade pointer

- FMG-020: DONE / MAIN VERIFIED at 4f99a60ba91abc0040364f70c9df86478fc4dab2 (Verify 36675201004 SUCCESS).
- FMG-021: DONE / MAIN VERIFIED at `12874be49a3bc8eaacdeb0dfb2aea33eb9ac087e` (merged-main Verify `36698092398` SUCCESS).
- FMG-022: ACTIVE on `chatgpt/FMG-022-checkpoint-restore`.
- NEXT_EXACT_ACTION: deep-read checkpoint manifest/capture + Mutation Guard/apply_edits/quarantine/SourceStateRef primitives, then implement transactional checkpoint restore with divergence guard, mandatory rollback checkpoint, index restoration, post-restore verification and rollback/partial_recovery_required handling. FMG-023 remains blocked until FMG-022 MAIN VERIFIED.
