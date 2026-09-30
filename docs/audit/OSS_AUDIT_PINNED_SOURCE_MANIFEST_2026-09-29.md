# OSS Audit Pinned Source Manifest - 2026-09-29

Canonical project root: `D:\Tools\FileMCP`

This file preserves the exact source identities from the former local audit cache
`D:\FileMCP-OSS-Audit` before that cache was deleted.

The source trees are **reference inputs only**. FileMCP's accepted decisions remain
the canonical audit/design documents, especially:

- `docs/design/OBSERVABILITY_V1_1_OSS_SOURCE_DEEP_DIVE.md`
- `docs/design/INDEPENDENT_OSS_AUDIT_V1_1.md`
- `docs/design/OBSERVABILITY_V1_1_DECISION_MATRIX.md`
- `docs/audit/FINAL_PRODUCT_INDEPENDENT_REPOSITORY_AUDIT_2026-09-22.md`

No OSS repository is transplanted wholesale into FileMCP. The frozen audit explicitly
prefers selective native adaptation of patterns/interfaces and records licensing and
privacy constraints.

| Local audit name | Origin | Branch | Pinned full SHA | Canonical disposition |
|---|---|---|---|---|
| contextforge | https://github.com/IBM/mcp-context-forge.git | main | `1950bcb8b6f6566d0283b07c455a3f084e67d678` | selective observability/redaction patterns |
| LiveCharts2 | https://github.com/Live-Charts/LiveCharts2.git | master | `8537b90ffb100a947cd0b1f6be49f896ae6050eb` | reference only; chart migration rejected for current scope |
| lunar | https://github.com/TheLunarCompany/lunar.git | main | `d22d2b85f110b9db6c3ca4d50b696391c3c6e30a` | resilience/traffic-policy reference only; full gateway rejected |
| mcp-gateway | https://github.com/microsoft/mcp-gateway.git | main | `3594c4eee36308ac131aad1c946ea14140b4353d` | session/cache/scoping reference only |
| mcp-inspector | https://github.com/modelcontextprotocol/inspector.git | main | `2e90a628e6296c62e4bef942afbb43d3faa4baf4` | diagnostics/legacy-vs-sessionless semantics only; UI/client transplant rejected |
| mcp-proxy | https://github.com/joshrotenberg/mcp-proxy.git | main | `965ca258650262be57632b6d6a6f4f922d5ac131` | retry/circuit-breaker/failover reference; generic proxy transplant rejected |
| opentelemetry-dotnet | https://github.com/open-telemetry/opentelemetry-dotnet.git | main | `44d841f9e0a3d29be7adb2abf536b70db6720561` | ActivitySource/Meter/exporter reference |
| prometheus-net | https://github.com/prometheus-net/prometheus-net.git | master | `60e9106a83ff1274fec0022c37366f04822b1d1b` | reference only; public Prometheus listener not selected for desktop core |
| ScottPlot | https://github.com/ScottPlot/ScottPlot.git | main | `fb3f5aae90db568a51a0d2c90f3c570659b517a2` | reference only; chart migration rejected for current scope |
| soth-mcp-proxy | https://github.com/soth-ai/mcp-proxy.git | main | `b198e9d038bd1e9ca6d1a6fe9bfcd348d3511a37` | bounded-session/TTL/health reference only |
| toolhive | https://github.com/stacklok/toolhive.git | main | `3c2a23500430c3fd2682fa8548f97d55fbb6da8e` | selective OTel/trace/lifecycle/cardinality patterns |

Deletion-time cleanliness:
- every nested repository had a clean worktree;
- `lunar` reported `behind 2` relative to its configured origin, matching the historical audit note;
- no local-only dirty source was discarded.

The former clone cache is not a project root and is not required for normal FileMCP
execution. Historical branches/commits and this manifest are sufficient provenance for
the frozen audit decisions.
