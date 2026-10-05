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

AUTHORITATIVE NEXT_EXACT_ACTION: FMUX-019 Cross-Platform UX Adversarial Gate is ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-019-cross-platform-adversarial` from exact verified main `253901ff2fc5eb4996c2842d3a4a2d05d87fcebf`. Evidence: `docs/evidence/FMUX-019_CROSS_PLATFORM_UX_ADVERSARIAL_GATE_EVIDENCE.md`. Baseline 18/18 FMUX contracts passed before repair. Proven gaps only: eleven foundation FMUX contracts were not retained by Verify, and raw caught exceptions could be the entire modal UX. Added one aggregate FMUX-019 gate per Windows-native job and structured operational errors on Windows/macOS; no core/tool/runtime authority changed. FMUX-019 gate + affected contracts + project-state + `git diff --check` PASS; Windows Release win-x64 build PASS with 0 warnings / 0 errors. Runtime PID `14804` remains correct; do not restart it. Next: scoped diff/security review -> commit exact candidate -> side-effect guard remote branch/PR/main -> push -> exact-head three-lane Verify -> reviewed PR -> guarded merge -> exact merged-main Verify -> governance state-sync. FMUX-020 remains BLOCKED until FMUX-019 MAIN VERIFIED.
