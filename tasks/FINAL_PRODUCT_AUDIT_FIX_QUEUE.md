# FINAL PRODUCT AUDIT FIX QUEUE

Source audit: `docs/audit/FINAL_PRODUCT_INDEPENDENT_REPOSITORY_AUDIT_2026-09-22.md`

Status: TECHNICAL REMEDIATION COMPLETE; V11-009 UPSTREAM MERGE REMAINS EXTERNAL/NON-BLOCKING; FMG COMPLETE-UPGRADE PROGRAM ACTIVE

| ID | Severity | State | Depends | Acceptance |
|---|---|---|---|---|
| FPA-001 | P1 | PASS | - | GitHub Windows workflow verifies the actual `FileMCP-release` staging path for x64/ARM64; clean workflow path gate passes |
| FPA-002 | P1 | PASS | - | macOS logical-chat/tool surface matches Windows, or product scope/docs explicitly freeze a Windows-only observability delta |
| FPA-003 | P1 | PASS | FPA-002 | macOS has bounded tunnel crash restart/backoff/jitter/budget/cooldown parity, or cross-platform tunnel-parity claim is explicitly removed |
| FPA-004 | P1 market | OUT-OF-SCOPE | public-market signed distribution | Current scope explicitly accepts unsigned developer/internal/direct-use distribution; signing/notarization plumbing remains optional future capability |
| FPA-005 | P2 | PASS | FPA-001 | Windows ARM64 gets native runtime smoke where available, or an explicit architecture-assurance gate and documented limitation |
| FPA-006 | P2 | PASS | - | handoff/project/task state match real Git HEAD/status and expose exactly one current NEXT_EXACT_ACTION |
| FPA-007 | P2 | PASS | - | duplicate desktop-process behavior is intentionally supported/documented or app-wide single-instance behavior is implemented/tested |
| FPA-008 | P2 | PASS | - | local MCP server has bounded concurrent connections and bounded idle/header read time with regression tests |
| FPA-009 | P3 optional | PASS | FPA-003/health scope | dynamic `:0` health endpoint is discoverable/probed or limitation remains explicitly documented |

## Dependency graph

```text
FPA-001 -------------------------> FPA-005
FPA-002 ---> scope decision -----> FPA-003
                  |
                  +--------------> FPA-004 market-release scope

FPA-006 independent state repair
FPA-007 independent operability hardening
FPA-008 independent HTTP resource hardening
FPA-009 optional after health-scope decision
```

## Next exact action

AUTHORITATIVE NEXT_EXACT_ACTION: FMG-026 native full regression/package Verify `37109212534` remains frozen PASS and MUST NOT be rerun. Runtime swap is PASS on PID `17860` using FMG026-ready SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`; canonical catalog is 46 while the active custom policy intentionally exposes 45 because only `run_command` is hidden by `CustomPolicyAllowShell=false`. LIVE ADVANCED PROOF is now PASS for batch + ContentRef, quarantine transaction, edit adapters, repository-intelligence facade on a bounded Git fixture, checkpoint transaction, and native Windows ConPTY, in addition to the preserved prior basic live file/Git/direct-exec/project-context/evidence proof. Optional Docker live engine remains ENVIRONMENT BLOCKED by the unavailable daemon under the frozen availability rule. Next: run project-state contract + `git diff --check` + exact closure review; commit only closure evidence/state; inspect real remote branch/PR state; push exact closure head; require exact-head GitHub Verify/checks; review/create exactly one PR to `main`; merge the exact reviewed head; require merged-main Verify; only then record `COMPLETE_UPGRADE_MAIN_VERIFIED` / FMG-026 DONE and continue to the next eligible task/program state.
