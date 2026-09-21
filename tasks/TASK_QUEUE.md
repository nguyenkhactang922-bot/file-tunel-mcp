# TASK QUEUE — FileMCP Observability V1

| ID | State | Depends | Acceptance |
|---|---|---|---|
| FMR-001 | PASS | - | Drive root D:\ resolves descendants; root listing/read/write/search work; traversal/junction/root-delete protections remain passing |
| OBS-001 | PASS | FMR-001 | Usage contracts, bytes_div_4_v1 estimator, tool classifier, semantics tests |
| OBS-002 | READY | OBS-001 | Interlocked hot counters, exact concurrent increments, immutable snapshot + atomic delta drain tests |
| OBS-003 | BLOCKED | OBS-002 | Microsoft.Data.Sqlite integration, WAL schema/versioning, pending-delta writer, failed-flush retry tests |
| OBS-004 | BLOCKED | OBS-003 | minute/hour/day period queries, Today/Yesterday/7d/30d local-boundary and retention tests |
| OBS-005 | BLOCKED | OBS-003 | LocalMcpServer request/response/tool/error/latency hooks with unchanged protocol/security behavior |
| OBS-006 | BLOCKED | OBS-005 | process-wide hub, C/D/E/F aggregation, app/runtime uptime tests |
| OBS-007 | BLOCKED | OBS-005 | filemcp_observability_connect, optional _filemcp_chat facade metadata, no authority semantics |
| OBS-008 | BLOCKED | OBS-007 | live logical/unbound session registry, active/idle/stale state machine, hashed durable id |
| OBS-009 | BLOCKED | OBS-004,OBS-006 | Overview tab + truthful usage/activity/per-drive cards sourced only from Core snapshots |
| OBS-010 | BLOCKED | OBS-008,OBS-009 | period controls, live session table/detail, exact-chat label feature gate |
| OBS-011 | BLOCKED | OBS-010 | bounded realtime graph + exact measurable health surfaces |
| OBS-012 | BLOCKED | OBS-011 | privacy DB inspection, load/concurrency, DB failure/corruption/migration/security regression suite |
| OBS-013 | BLOCKED | OBS-012 | self-contained win-x64 publish, native SQLite smoke, one live ChatGPT correlation proof, final acceptance |

NEXT_EXACT_ACTION: CLAIM OBS-002.
