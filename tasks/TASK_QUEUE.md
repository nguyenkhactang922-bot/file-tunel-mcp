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

## Single-root consolidation - 2026-09-29

Canonical PROJECT_ROOT is now locked to `D:\Tools\FileMCP` only.
All sibling FileMCP Git worktrees were audited and removed. `git worktree list` contains only the canonical root and `D:\Tools` contains only one `FileMCP*` directory: `D:\Tools\FileMCP`.
Active branch: `chatgpt/FMG-020-persistent-pty`.
Active head after preserving the useful FMG-013 Git-fixture hardening: `92e4496cb8c4127716d3478645da03a045b41dbe`.
Stale PR #29 (`FMUX-007-settings-policy-v2`) was closed because it is superseded by merged FMUX work and would regress current UI/state.
FMG-017 dirty worktree was discarded only after audit confirmed PR #36/main contains the larger verified adapter implementation.
FMG-018 alternate worktree was not merged wholesale because main already contains the accepted PR #37 implementation and FMG-019 depends on that canonical model; its relevant negative/cache hardening is already covered on current main.
FMG-013 dirty Git-fixture hardening was merged into FMG-020 and verified with `repo-query-only`: 18 assertions PASS, build 0 warnings / 0 errors.
Evidence: `docs/evidence/SINGLE_ROOT_WORKTREE_CONSOLIDATION_2026-09-29.md`.

Historical note: active FMG-020 continuation is tracked only in `CURRENT_HANDOFF.md` and `tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`. Do not create another worktree.
