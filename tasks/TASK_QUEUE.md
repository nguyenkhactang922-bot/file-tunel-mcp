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


## FMG-026 runtime-swap blocker - 2026-10-03

- State: ACTIVE / NATIVE REGRESSION PASS / LIVE ADVANCED PROOF BLOCKED.
- Verify `37109212534`: SUCCESS on macOS / Windows x64 / native Windows ARM64; preserve PASS and DO NOT rerun.
- Active runtime remains stale PID `16240` on FMG013-ready; connector remains 22/46 tools.
- FMG026-ready x64 binary is prepared with canonical 46-tool catalog.
- Automated stop/start helper was blocked by safety policy; no side effect occurred.
- BLOCKER: manually exit old FileMCP desktop/tray instance before launching FMG026-ready.
- NEXT_EXACT_ACTION: exit PID `16240` via normal FileMCP UI/tray -> launch `dist/windows-x64/FileMCP-FMG026-ready/FileMCP.exe` -> reconnect -> verify 46 tools -> LIVE ADVANCED PROOF ONLY -> closure/PR/merge/main-verify.


## FMG-026 live advanced proof closure checkpoint - 2026-10-03

- State: **PASS_LOCAL / LIVE_ADVANCED_PASS / GITHUB_CLOSURE_PENDING**.
- Native complete regression/package Verify `37109212534`: PASS and frozen; do not rerun merely for docs/state closure.
- Active runtime: PID `17860`, FMG026-ready SHA-256 `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`.
- Canonical catalog: `46`; effective current policy surface: `45`, with only `run_command` intentionally hidden because `CustomPolicyAllowShell=false`.
- Live advanced acceptance PASS: batch + ContentRef; quarantine transaction; edit adapters; repository-intelligence facade on bounded Git fixture; checkpoint transaction; Windows native ConPTY lifecycle.
- Prior basic live MCP proof remains PASS.
- Temporary fixture cleanup PASS; production/source implementation delta from live proof: NONE.
- Docker live engine remains ENVIRONMENT BLOCKED by unavailable daemon under the frozen availability rule.
- Evidence: `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.

Historical closure sequence: verify state contract + `git diff --check` + exact scoped diff; commit evidence/state closure; inspect remote branch/PR state; push exact head; require exact-head GitHub Verify/checks; review/create one PR to `main`; merge exact reviewed head; require merged-main Verify; only then mark `COMPLETE_UPGRADE_MAIN_VERIFIED` / FMG-026 DONE and continue to the next eligible task/program state.


## FMG-026 complete-upgrade core closure - 2026-10-03

- Primary technical state: **DONE / MAIN VERIFIED**.
- Closure head `e39877808b3fb0394b5b5a2608d6489ad6d8404f` passed push Verify `37120899485` and PR #47 Verify `37121297945` on macOS / Windows x64 / native Windows ARM64.
- PR #47 merged as `03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`.
- GitHub omitted the normal main PushEvent/check suite for that merge, so post-merge verification used a zero-delta verification-only ref pointing exactly to the actual main commit.
- Exact-main-commit Verify `37121899760`, `headSha=03cf7c082e29fb9eb576a875e4d73b018d5cc9f0`: SUCCESS on all three native lanes.
- `FILEMCP COMPLETE-UPGRADE CORE = COMPLETE_UPGRADE_MAIN_VERIFIED`.
- Evidence: `docs/evidence/COMPLETE_UPGRADE_MAIN_VERIFIED.md` and `docs/evidence/FMG-026_COMPLETE_REGRESSION_LIVE_ADVANCED_PROOF_EVIDENCE.md`.
- Optional Docker live engine proof remains ENVIRONMENT BLOCKED under the frozen availability rule.
- Governance state-sync: DONE / MAIN VERIFIED. PR #48 head `552edec938379d309d26a3eab2b0005f0cefcdeb` merged as `5a5abed27e523dac4f62c27e8808c3bb03a6d874`; merged-main Verify `37135393780` SUCCESS on macOS / Windows x64 / native Windows ARM64.

## FMUX-011 closure / FMUX-012 active pointer - 2026-10-04

- FMUX-011 Repository Intelligence: DONE / MAIN VERIFIED.
- FMUX-012 Terminal / PTY: ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-012-terminal-pty`, based directly on verified `fork/main=d378faa0807435be7ca21eff1c573518779c5dd4`.
- Dependencies FMUX-002, FMUX-003 and FMG-020 are DONE / MAIN VERIFIED.
- Scope implemented: native Windows/macOS Terminal destination; real `pty_list` session state; bounded `pty_read` output; backend/policy/session truth; existing-policy Ctrl+C/stop/resize controls; no `pty_start` or `pty_write` presentation authority.
- Local evidence: `tests/test_fmux_terminal_pty_contract.ps1`, app-shell, presentation, Repository regression, persistent PTY, project-state and `git diff --check` PASS; Windows Release build source checkpoint PASS 0 warnings / 0 errors. Evidence file: `docs/evidence/FMUX-012_TERMINAL_PTY_UX_EVIDENCE.md`.
- Runtime checkpoint: correct FMG026-ready FileMCP remains PID `17860`; no restart performed.
- Exact-head attempt 1: candidate `bae6bea5cf23a2577cd474068472de752cb1944e`, Verify `37175574357` FAIL from stale FMUX-011 lifecycle assertion on Windows x64/ARM64 plus macOS non-escaping closure compile error; both were repaired by the targeted fix checkpoint.
- Exact-head attempt 2: fix checkpoint `edd996bd43642e8c5399a90ca14cb109db858fd1`, push Verify `37176690710` SUCCESS on macOS / Windows x64 / native Windows ARM64. Scoped review PASS; no P0/P1; presentation allowlist remains list/read/resize/signal/stop only, bounded and non-authoritative.
- NEXT_EXACT_ACTION: evidence-state-only closure commit -> side-effect guard -> push closure head -> exact-head Verify on closure SHA -> reviewed PR to `main` -> merge exact reviewed head -> merged-main Verify.


## FMUX-012 closure / next-ready pointer - 2026-10-04

- FMUX-012 Terminal / PTY: DONE / MAIN VERIFIED.
- Closure head `feb365864c32a3f7bb297bc4bba59c6171a73a9d`; push Verify `37177215836` SUCCESS; PR #50 Verify `37177568204` SUCCESS; merged main `38b20e633957ea6c279b110dac54072b29df14a6`; merged-main Verify `37177832479` SUCCESS across macOS / Windows x64 / native Windows ARM64.
- Runtime checkpoint: correct FMG026-ready FileMCP remains PID `17860`; no restart performed.
- State-sync branch: `state/FMUX-012-main-verified`, based exactly on verified main `38b20e633957ea6c279b110dac54072b29df14a6`.
- FMUX-013 Recovery dependencies FMUX-002, FMUX-003, FMG-016, FMG-021 and FMG-022 are DONE / MAIN VERIFIED; FMUX-013 becomes the lowest-numbered next task after this state-sync is MAIN VERIFIED.
- State-sync next action: commit -> push -> exact-head Verify -> reviewed PR -> merge -> merged-main Verify; only then claim FMUX-013.

- State-sync attempt 1: head `6a6d247f774a379426dc32c9e7022477d888ed95`, Verify `37183274280` completed FAILURE. macOS SUCCESS; Windows x64/native ARM64 failed only stale FMUX-012 lifecycle assertion after graph closure. Targeted contract fix is local PASS; no product source or runtime changed.
- State-sync retry action: commit fix -> side-effect guard remote exact old head/no PR -> push new exact head -> three-lane Verify -> reviewed PR -> merge -> merged-main Verify -> only then claim FMUX-013.

- State-sync attempt 2: lifecycle-fix head `ad199846fd2d7fe50311c7965f11ca88ddda0999` passed push Verify `37183856103` on macOS / Windows x64 / native Windows ARM64; scoped review PASS, no P0/P1.
- Next: evidence-state-only closure commit -> side-effect guard -> push new closure head -> exact-head three-lane Verify -> one reviewed PR -> merge -> merged-main Verify -> only then claim FMUX-013.


## FMUX-013 Recovery claim - 2026-10-04

- FMUX-012 governance state-sync: DONE / MAIN VERIFIED. PR #51 merged as `dad103c569cbfc6d68b343445287152013c6f29e`; merged-main Verify `37186288521` SUCCESS on macOS / Windows x64 / native Windows ARM64.
- FMUX-013 Recovery: ACTIVE / CLAIMED on `chatgpt/FMUX-013-recovery`, based exactly on verified main `dad103c569cbfc6d68b343445287152013c6f29e`.
- Dependencies FMUX-002, FMUX-003, FMG-016, FMG-021, FMG-022: DONE / MAIN VERIFIED.
- Frozen scope: quarantine; checkpoints; restore plan; rollback; partial-recovery states.
- NEXT: inspect existing Windows/macOS quarantine/checkpoint/restore presentation bridges and frozen design specs -> implement truthful Recovery UX only -> targeted contract/build evidence -> exact-head verification lifecycle.


## FMUX-013 Recovery local verification - 2026-10-04

- State: ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-013-recovery`.
- Base: verified main `dad103c569cbfc6d68b343445287152013c6f29e`.
- Recovery UX: quarantine/checkpoint master-detail; original-path quarantine restore; checkpoint dry-run plan before preserve-history restore; rollback/partial-recovery state explicit and persistent.
- Presentation authority: exact six-tool Recovery allowlist; no quarantine delete, checkpoint capture/delete, PTY write/start, shell, replace-existing or target override.
- Local gates PASS: FMUX-013 contract, app-shell, presentation, project-state, diff check, workflow YAML parse, Windows Release build 0 warnings / 0 errors.
- macOS native typecheck/build: pending exact-head GitHub Verify because local host has no `swiftc`.
- Next: scoped diff review -> candidate commit -> side-effect guard -> push exact head -> require all native lanes PASS before PR.


## FMUX-013 exact-head verification - 2026-10-04

- Candidate `8e444cc5ffa76b0c97cb756d04b3be7620a87ccc`: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS.
- Push Verify `37189165659`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- macOS typecheck/integration/build and Windows full native lanes are green.
- Runtime PID `17860` remained correct; no restart.
- Next: evidence/state-only closure commit -> closure exact-head Verify -> one reviewed PR -> merge -> merged-main Verify.


## FMUX-013 closure / next-ready pointer - 2026-10-04

- FMUX-013 Recovery: DONE / MAIN VERIFIED.
- Closure head `d64e10439932c4bf05186468107ad179eafd28da`; push Verify `37190237875` SUCCESS; PR #52 Verify `37190637624` SUCCESS; merged main `f5fb42c0d842db126cd4de58ddc952633a4676c8`; merged-main Verify `37190970602` SUCCESS across macOS / Windows x64 / native Windows ARM64.
- Runtime checkpoint: correct FMG026-ready FileMCP remains PID `17860`; no restart performed.
- State-sync branch: `state/FMUX-013-main-verified`, based exactly on verified main `f5fb42c0d842db126cd4de58ddc952633a4676c8`.
- FMUX-014 is already DONE / MAIN VERIFIED. FMUX-015 dependencies FMUX-003, FMG-023 and FMG-024 are DONE / MAIN VERIFIED; FMUX-015 becomes the lowest-numbered next task after this state-sync is MAIN VERIFIED.
- State-sync next action: commit -> push -> exact-head Verify -> reviewed PR -> merge -> merged-main Verify; only then claim FMUX-015 Backend / Isolation UX.

## FMUX-013 state-sync closure / FMUX-015 active pointer - 2026-10-04

- FMUX-013 governance state-sync: DONE / MAIN VERIFIED. PR #53 merged as `f76b4e9a84c428080907859591b4aa4ddc40645c`; merged-main Verify `37194838411` SUCCESS across macOS / Windows x64 / native Windows ARM64.
- FMUX-015 Backend / Isolation UX: ACTIVE / CLAIMED on `chatgpt/FMUX-015-backend-isolation-ux`, based exactly on verified main `f76b4e9a84c428080907859591b4aa4ddc40645c`.
- Dependencies FMUX-003, FMG-023, FMG-024: DONE / MAIN VERIFIED.
- Runtime PID `17860` remains correct; no restart performed.
- Docker live engine remains environment-blocked because the daemon is unavailable; UX must render availability truth rather than a synthetic isolated backend.
- Task next action: audit existing backend/Docker truth projections and implement bounded cross-platform Backend / Isolation UX, then affected local gates -> exact-head native Verify -> review/PR/merge -> merged-main Verify.


## FMUX-015 Backend / Isolation local verification - 2026-10-04

- State: ACTIVE / LOCAL VERIFIED on `chatgpt/FMUX-015-backend-isolation-ux`; base verified main `f76b4e9a84c428080907859591b4aa4ddc40645c`.
- Read-only cross-platform UX shows selected backend identity/status, host vs isolation, network/resource/workspace/environment modes, Docker selected/availability state and bounded image/network/resource policy facts.
- No backend selector, Docker config mutation, Docker CLI/container action, or presentation authority added.
- Local gates PASS: FMUX-015 contract, app-shell, presentation, project-state, execution-backend, Docker-backend, diff check, Windows Release build 0 warnings / 0 errors.
- Live runtime remains PID `17860`, backend `host-native`, grants_authority=false; no restart. Docker daemon remains environment-blocked and is not presented as available.
- macOS native compile/build: pending exact-head GitHub Verify.
- Next: final scoped diff review -> candidate commit -> remote/PR guard -> push exact head -> three-lane Verify before PR.
