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

AUTHORITATIVE NEXT_EXACT_ACTION: FMG-026, FMUX-011 and FMUX-012 are DONE / MAIN VERIFIED. FMUX-012 PR #50 merged as `38b20e633957ea6c279b110dac54072b29df14a6`; merged-main Verify `37177832479` SUCCESS on macOS / Windows x64 / native Windows ARM64. Current governance work is state-only closure on `state/FMUX-012-main-verified`: commit -> push -> exact-head Verify -> reviewed PR -> merge -> merged-main Verify. After that state-sync is MAIN VERIFIED, claim dependency-ready FMUX-013 Recovery from the resulting verified `main`. Do not rerun FMUX-012 implementation proof or restart correct runtime PID `17860`.
