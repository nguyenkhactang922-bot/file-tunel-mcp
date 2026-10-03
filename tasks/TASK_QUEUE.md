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
- FMG-024: DONE / MAIN VERIFIED. PR #44 head `d0495da7f0d70e1fc14e93e928ba52a2d9ffee89` merged as `2bd859a966f9f49075ffc7d0a544154cb5d76498`; PR Verify `37094506166` final SUCCESS; merged-main Verify `37095113136` SUCCESS on macOS / Windows x64 / native Windows ARM64. Live Docker engine proof remains environment-blocked because the local daemon is unavailable.
- Evidence: `docs/evidence/FMG-024_OPTIONAL_DOCKER_ISOLATED_BACKEND_EVIDENCE.md`.
- FMG-025: CLAIMED / ACTIVE on `chatgpt/FMG-025-adversarial-gate`, based directly on verified main `2bd859a966f9f49075ffc7d0a544154cb5d76498`.
- NEXT_EXACT_ACTION: inventory FMG-014..024 advanced surfaces and existing negative/contract suites; execute the cross-platform adversarial/privacy/security/parity matrix, repair only real gaps, then evidence/review/commit/PR/merge/main-verify before FMG-026.


## FMG-025 active checkpoint - 2026-10-03

- State: ACTIVE / LOCAL ADVERSARIAL GATE PASS.
- Branch: `chatgpt/FMG-025-adversarial-gate`.
- New gate: `tests/test_advanced_adversarial_gate.ps1` PASS locally; CI wiring added to Windows x64 + native Windows ARM64; macOS native Swift runtime/build remains authoritative.
- Evidence: `docs/evidence/FMG-025_ADVANCED_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.
- NEXT_EXACT_ACTION: commit/push exact candidate -> native Verify macOS/Windows x64/Windows ARM64 -> exact-head review -> PR/merge -> merged-main Verify -> FMG-025 MAIN VERIFIED -> claim FMG-026.


## FMG-025 exact-head verification checkpoint - 2026-10-03

- State: ACTIVE / EXACT-HEAD NATIVE VERIFIED / REVIEW PASS.
- Candidate head: `a4098e2c72fa3ba92f1fcff4898d726ed42aa614`.
- Push Verify `37096296869`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Exact-head review: PASS; no production/runtime implementation change for FMG-025.
- Evidence: `docs/evidence/FMG-025_ADVANCED_CROSS_PLATFORM_ADVERSARIAL_GATE_EVIDENCE.md`.
- NEXT_EXACT_ACTION: commit/push evidence/state-only closure head -> exact-head native Verify -> single PR -> merge after green verification -> merged-main Verify -> FMG-025 MAIN VERIFIED -> claim FMG-026.


## FMG-025 closure / FMG-026 claim - 2026-10-03

- FMG-025: DONE / MAIN VERIFIED. PR #45 merged as `59ee366f504160b2132355e3d2dae9ce3b524646`; merged-main Verify `37107116084` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR Verify `37106541799`: final SUCCESS on all three lanes after rerunning only the transient Windows x64 health-url file-sharing failure; no source change was required.
- FMG-026: CLAIMED / ACTIVE on `chatgpt/FMG-026-complete-regression`, based directly on verified main `59ee366f504160b2132355e3d2dae9ce3b524646`.
- NEXT_EXACT_ACTION: inventory existing complete-regression/live-proof assets; map the frozen FMG-026 scope to executable proof, identify only real gaps, then run the required final full regression and live advanced proof, produce COMPLETE_UPGRADE_MAIN_VERIFIED candidate evidence, exact-head verify/review/PR/merge/main-verify.


## FMG-026 pre-restart checkpoint - 2026-10-03

- State: ACTIVE / PRE-RESTART CHECKPOINT.
- Full regression/package gate is the existing native `Verify` workflow; do not duplicate already-MAIN-VERIFIED task stages.
- Live tunnel + basic FileMCP proof: PASS without restarting PID `16240` or tunnel PIDs `10896` / `15204`.
- Source catalog: 46 tools; currently discovered connector: 22 tools. Live advanced proof remains BLOCKED on deployment/connector rediscovery.
- Prepared `dist/windows-x64/FileMCP-FMG026-ready/FileMCP.exe` with matching canonical 46-tool catalog.
- Docker live proof: ENVIRONMENT BLOCKED; daemon unavailable.
- Evidence: `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.
- NEXT_EXACT_ACTION: commit/push this exact checkpoint -> native Verify full regression/package gate -> repair only real failed stage -> after green Verify, preserve PASS and deploy/reconnect FMG026-ready -> rediscover 46 tools -> LIVE ADVANCED PROOF ONLY -> closure/PR/merge/main-verify.


## FMG-026 native regression PASS / runtime handoff - 2026-10-03

- State: ACTIVE / NATIVE REGRESSION PASS / LIVE ADVANCED PROOF BLOCKED ON CONNECTOR REDISCOVERY.
- Exact head `21d0c6ed05a749be363b108a7a965a7f0deaef9e` -> Verify `37109212534` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Preserve this PASS; do not rerun native regression after desktop restart.
- NEXT_EXACT_ACTION: close current FileMCP desktop -> launch `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe` -> reconnect -> verify 46-tool discovery -> LIVE ADVANCED PROOF ONLY -> closure/PR/merge/main-verify.
