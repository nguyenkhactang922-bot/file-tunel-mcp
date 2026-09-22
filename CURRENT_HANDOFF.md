# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `chatgpt/OBS-001-observability-foundation`
Worktree expectation at handoff: CLEAN
Git SHA source of truth: run `git rev-parse HEAD`; do not hardcode a self-invalidating HEAD in this file.

Initiative status:

- FMR-001 PASS.
- OBS-001 through OBS-013 PASS.
- V11-001 through V11-008 PASS.
- FPA-001 PASS.
- Final-product remediation is ACTIVE.
- V11-009 / MAIN VERIFIED remains deferred until final-product P1 blockers are closed.

## Verified Windows baseline

Latest independent audit baseline:

- Release build with warnings-as-errors: PASS, 0 warnings / 0 errors.
- Windows runtime suite: PASS, 414 assertions.
- OBS-013 real ChatGPT cross-turn correlation proof: PASS.
- NuGet vulnerable-package audit: PASS.
- NuGet direct outdated audit: PASS.
- Packaged x64 WPF / tray / tunnel-client / SQLite / OTLP / notices smoke: PASS.

## FPA-001 completed

Windows CI release staging is now canonicalized:

- build default: `FileMCP-release`;
- GitHub Actions job variable: `FILEMCP_WINDOWS_STAGING_NAME=FileMCP-release`;
- x64 and ARM64 workflow builds pass the canonical staging name;
- release-resource verification uses the same staging variable;
- regression test: `tests/test_windows_release_contract.ps1`.

Evidence:
`docs/evidence/FPA-001_CI_STAGING_PARITY_EVIDENCE.md`

## Remaining final-product findings

Authoritative report:
`docs/audit/FINAL_PRODUCT_INDEPENDENT_REPOSITORY_AUDIT_2026-09-22.md`

Authoritative remediation queue:
`tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`

Open findings:

- FPA-002 PASS: macOS logical-chat / MCP tool-surface parity; native macOS + Windows CI run 35718764133 succeeded.
- FPA-003 P1: macOS tunnel restart/backoff/cooldown parity.
- FPA-004 P1 for public-market release: signing/notarization release gate.
- FPA-005 P2: Windows ARM64 runtime assurance.
- FPA-007 P2: duplicate desktop instance UX.
- FPA-008 P2: local MCP connection bounds.
- FPA-009 P3 optional: dynamic health endpoint discovery.

## GitHub merge status

- Upstream: `dongttfd/file-tunel-mcp`.
- PR #2 exists on the upstream repo.
- Authenticated bot account has READ permission upstream.
- Feature branch is pushed to the bot fork.
- Upstream merge remains a permission boundary, not a technical merge/test blocker.

## Resume law

On a new chat:

1. confirm git root / branch / HEAD / status;
2. read `AGENTS.md`;
3. read `docs/CHATCODE_GLOBAL_MULTI_PROJECT_EXECUTION_LAW.md`;
4. read this file;
5. read `PROJECT_STATE.md`;
6. read `tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md`;
7. resume the single authoritative next action;
8. do not repeat completed OBS/V11/FPA tasks.


## FPA-002 completed

Design is frozen and implementation candidate is ready for native macOS verification.

Local Windows-side gates:
- cross-platform tool-surface parity: PASS (19 required public tool names);
- shell syntax via Git Bash: PASS;
- Windows Release build: PASS 0/0;
- Windows runtime: PASS 414 assertions;
- diff check: PASS.

AUTHORITATIVE NEXT_EXACT_ACTION is owned by tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md: CLAIM FPA-003 design gate.


FPA-002 final acceptance:
- GitHub Actions run 35718764133: verify-macos SUCCESS, verify-windows SUCCESS.
- Evidence: docs/evidence/FPA-002_MAC_LOGICAL_CHAT_PARITY_EVIDENCE.md.


## FPA-003 candidate

- Frozen macOS tunnel-supervisor architecture is implemented locally.
- Local static contracts and Windows regression are PASS.
- Candidate evidence: `docs/evidence/FPA-003_MAC_TUNNEL_SUPERVISOR_CANDIDATE.md`.
- FPA-003 remains ACTIVE until native GitHub verify-macos + verify-windows succeed.


FPA-003 final acceptance:
- GitHub Actions run 35723605790: verify-macos SUCCESS, verify-windows SUCCESS.
- Evidence: docs/evidence/FPA-003_MAC_TUNNEL_SUPERVISOR_EVIDENCE.md.


## FPA-005 candidate

- Native Windows ARM64 assurance architecture is frozen and implemented locally.
- Local x64 compatibility smoke, release contract, ARM64 assurance contract, Release build and 414 runtime assertions PASS.
- Candidate evidence: `docs/evidence/FPA-005_WINDOWS_ARM64_NATIVE_ASSURANCE_CANDIDATE.md`.
- FPA-005 remains ACTIVE until GitHub verify-windows-arm64 succeeds on a real ARM64 hosted runner.


FPA-005 final acceptance:
- GitHub Actions run 35726514963: verify-macos SUCCESS, verify-windows SUCCESS, verify-windows-arm64 SUCCESS.
- Native ARM64 WPF/tray/tunnel-client/SQLite/OTLP smoke PASS.
- Evidence: docs/evidence/FPA-005_WINDOWS_ARM64_NATIVE_ASSURANCE_EVIDENCE.md.
- AUTHORITATIVE NEXT_EXACT_ACTION is owned by tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md: CLAIM FPA-007 design gate.


## FPA-007 candidate

- Windows desktop single-instance named-pipe architecture is implemented locally.
- Core suite PASS at 423 assertions.
- Packaged x64 duplicate-launch activation smoke PASS.
- Candidate evidence: `docs/evidence/FPA-007_WINDOWS_SINGLE_INSTANCE_CANDIDATE.md`.
- FPA-007 remains ACTIVE until native GitHub macOS/x64/ARM64 jobs succeed.


FPA-007 final acceptance:
- GitHub Actions run 35728230159: verify-macos SUCCESS, verify-windows SUCCESS, verify-windows-arm64 SUCCESS.
- Native x64 + ARM64 second-launch activation smoke PASS.
- Evidence: docs/evidence/FPA-007_WINDOWS_SINGLE_INSTANCE_EVIDENCE.md.
- AUTHORITATIVE NEXT_EXACT_ACTION is owned by tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md: CLAIM FPA-008 design gate.


## FPA-008 candidate

- Cross-platform local MCP connection cap + idle/header timeout implementation is complete locally.
- Windows Release build and runtime suite PASS at 428 assertions.
- Static cross-platform contracts PASS.
- Candidate evidence: `docs/evidence/FPA-008_CONNECTION_BOUNDS_CANDIDATE.md`.
- FPA-008 remains ACTIVE until native macOS/Windows x64/Windows ARM64 GitHub jobs succeed.


FPA-008 final acceptance:
- GitHub Actions run 35745850301: macOS, Windows x64 and Windows ARM64 all SUCCESS.
- Evidence: docs/evidence/FPA-008_CONNECTION_BOUNDS_EVIDENCE.md.
- Next: FPA-009 design gate, then FPA-004 release signing scope.


## FPA-009 candidate

- Official tunnel-client health.url-file discovery is implemented for Windows dynamic health endpoints.
- Local contracts/build/runtime PASS at 444 assertions.
- Candidate evidence: docs/evidence/FPA-009_DYNAMIC_HEALTH_DISCOVERY_CANDIDATE.md.
- FPA-009 remains ACTIVE until native macOS/Windows x64/Windows ARM64 CI succeeds.
