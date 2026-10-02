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
- FMG-022: DONE / MAIN VERIFIED. PR #41 merged as `f3e4254c5a32d48d95b28372d0eff56880aeb5f5`; merged-main Verify `36986797605` SUCCESS.
- Drive-root project_context hotfix: MAIN VERIFIED. PR #42 merged as `9b6162fd9c79e755922f2865efef6b1eefc6402e`; merged-main Verify `36991621549` SUCCESS.
- FMG-023: DONE / MAIN VERIFIED. PR #43 merged as `d71fbc08e9e08f65c59ce5e05649e0dc629f7935`; PR Verify `36998198466` SUCCESS; merged-main Verify `36998939456` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- FMG-024: CLAIMED / ACTIVE on `chatgpt/FMG-024-docker-backend`, based directly on merged main `d71fbc08e9e08f65c59ce5e05649e0dc629f7935`.
- NEXT_EXACT_ACTION: deep-read the FMG-023 backend contract + local policy/config/Artifact/Evidence primitives, probe Docker availability without changing state, then implement the frozen optional Docker isolated backend with local-only authority, digest pinning, mount revalidation, mandatory resource/security flags, network-none default, owned-label lifecycle/cleanup, exec+PTY mapping and explicit evidence identity.
