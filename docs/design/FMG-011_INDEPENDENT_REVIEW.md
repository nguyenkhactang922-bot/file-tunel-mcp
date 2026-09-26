# FMG-011 Independent Review

1. False PASS: reject stdout parsing; server-known structured result only.
2. Caller authority: criterionId selects a known criterion, never a caller-authored state.
3. Source race: process.exit_zero requires stable pre/post source and context.
4. Mutation evidence: tool.success binds post-operation state rather than becoming instantly stale.
5. Policy/catalog drift: persisted generation/hash participates in freshness.
6. Storage failure: no durable terminal write means no durable passed/failed claim.
7. Crash recovery: running evidence reopens unknown, never passed.
8. Persistence: separate store from telemetry is mandatory.
9. Windows store: separate SQLite reuses an existing dependency and supports bounded quota/recovery.
10. macOS store: atomic bounded metadata snapshot avoids introducing a new native DB dependency.
11. Privacy: raw command/args/output/content remain forbidden.
12. Scope: no task manager, transcript, checkpoint or artifact bytes.

Verdict: proceed with cross-platform semantic parity and platform-private storage engines.