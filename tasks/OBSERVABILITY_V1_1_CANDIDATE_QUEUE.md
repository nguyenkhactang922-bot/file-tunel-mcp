# OBSERVABILITY V1.1 — CANDIDATE TASK QUEUE

Status: USER-APPROVED + ARCHITECTURE FROZEN FOR POST-OBS-013 IMPLEMENTATION
Rule: USER APPROVED IMPLEMENTATION. DO NOT START FEATURE CODE UNTIL OBS-013 LIVE ACCEPTANCE IS COMPLETE; then CLAIM V11-001 immediately without repeating discovery/audit.

| ID | State | Depends | Purpose / acceptance |
|---|---|---|---|
| V11-001 | BLOCKED | OBS-013 | Bounded logical session/correlation lifecycle: TTL, cap, cleanup, never evict in-flight, pressure metrics, concurrency tests |
| V11-002 | BLOCKED | V11-001 | Process-wide maintenance worker: invoke SQLite retention, durable session cleanup, in-memory cleanup; cancellation/failure-isolation tests |
| V11-003 | BLOCKED | OBS-013 | Tunnel supervisor: exponential backoff+jitter, restart budget, stable reset, cooldown, user-stop cancellation; no tool replay |
| V11-004 | BLOCKED | V11-003 | Component health model: server/tunnel/persistence/restart/backoff/tunnel-health signals; dashboard integration |
| V11-005 | BLOCKED | OBS-013 | Native .NET telemetry contracts: ActivitySource + Meter, versioned MCP attribute adapter, privacy/cardinality policy |
| V11-006 | BLOCKED | V11-005 | W3C trace-context extraction from MCP `_meta` with HTTP fallback; authority/chat-identity separation tests |
| V11-007 | BLOCKED | V11-005,V11-006 | Optional OTLP exporter/settings; disabled-by-default zero-network mode, exporter-down isolation, single-file packaging proof |
| V11-008 | BLOCKED | V11-002,V11-004,V11-007 | Independent hardening audit: 24h-style churn simulation, memory/disk bounds, restart storms, exporter failure, privacy scan |
| V11-009 | BLOCKED | V11-008 | Final package/live E2E/MAIN VERIFIED gate |

## Dependency graph

OBS-013
  +--> V11-001 --> V11-002 -----------+
  +--> V11-003 --> V11-004 -----------+--> V11-008 --> V11-009
  +--> V11-005 --> V11-006 --> V11-007+

## Deliberately excluded tasks

No LiveCharts2/ScottPlot migration, no Prometheus server, no full proxy circuit-breaker/hedging, no distributed session store, no payload trace persistence.

NEXT_EXACT_ACTION after OBS-013 PASS: claim V11-001.
