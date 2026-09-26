# FMG-011 Decision Matrix

| Question | Selected | Rejected |
|---|---|---|
| Evidence producer | reserved metadata + server-known criteria | parse stdout/PASS |
| Process criterion | structured exit zero | caller text |
| Generic criterion | tool.success | arbitrary caller state |
| Freshness | server recompute SourceStateRef + project context | caller digest |
| Windows persistence | separate SQLite DB | telemetry tables |
| macOS persistence | bounded atomic metadata snapshot | new DB dependency |
| Store failure | unknown/unavailable | preserve PASS |
| Required mode | explicit required flag | always block all tools |
| Durable content | metadata/digests only | command/args/output/content |