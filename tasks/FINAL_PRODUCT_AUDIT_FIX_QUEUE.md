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

AUTHORITATIVE NEXT_EXACT_ACTION: FMUX-020 implementation is DONE / MAIN VERIFIED and `PRODUCT_UI_UX_MAIN_VERIFIED` is recorded for exact verified main `821015002ca92f339df3434aa73e4887fd905670`. Closure head `788b82bd8e248d67c18ad2279d00eec2ede5fcd8` passed push Verify `37339216002`; PR #64 Verify `37340337547` SUCCESS; PR #64 merged as main `821015002ca92f339df3434aa73e4887fd905670`; exact merged-main Verify `37341640268` SUCCESS on macOS / Windows x64 / native Windows ARM64. Evidence: `docs/evidence/PRODUCT_UI_UX_MAIN_VERIFIED.md` and `docs/evidence/FMUX-020_PRODUCT_UI_UX_MAIN_VERIFICATION_EVIDENCE.md`. Runtime PID `14804` remains correct; do not restart it. Final governance state-sync is ACTIVE on `state/FMUX-020-main-verified` from exact verified main `821015002ca92f339df3434aa73e4887fd905670`. Next: project-state contract + diff hygiene + state-only review -> commit -> guard remote state branch/PR/main -> push exact governance head -> exact-head three-lane Verify -> exactly one reviewed PR -> PR Verify -> guarded merge -> exact resulting-main Verify -> FMUX program fully closed; do not rerun implementation stages.
