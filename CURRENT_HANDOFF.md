# CURRENT HANDOFF

## Current status

Project: FileMCP
Branch: `main`
Worktree expectation at handoff: CLEAN
Git SHA source of truth: run `git rev-parse HEAD`; do not hardcode a self-invalidating HEAD in this file.

Initiative status:

- FMR-001 PASS.
- OBS-001 through OBS-013 PASS.
- V11-001 through V11-008 PASS.
- FPA-001 PASS.
- Final-product remediation is ACTIVE.
- V11-009 technical fork-main verification PASS; final V11-009 remains EXTERNAL-BLOCKED on upstream merge authority and FPA-004 real production-signing evidence.

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


FPA-009 final acceptance:
- GitHub Actions run 35748443822: macOS, Windows x64 and Windows ARM64 all SUCCESS.
- Evidence: docs/evidence/FPA-009_DYNAMIC_HEALTH_DISCOVERY_EVIDENCE.md.
- Next: FPA-004 public-market signing/notarization design gate.


## FPA-004 plumbing candidate

- Frozen architecture: commit 968e05a.
- Release workflow/scripts + secret-hygiene contract implemented locally.
- Windows Release build PASS 0/0; runtime PASS 444 assertions; x64 packaged smoke PASS; x64/ARM64 candidate packages build PASS.
- Candidate evidence: docs/evidence/FPA-004_PRODUCTION_SIGNING_PLUMBING_CANDIDATE.md.
- Connected fork currently has no production-release environment and no release secrets.
- FPA-004 remains ACTIVE until native Verify succeeds; after that it becomes EXTERNAL-BLOCKED unless real signing/notarization credentials are provisioned and the Production Release workflow succeeds.


## FPA-004 external blocker

- Plumbing implementation commit: 934fb73.
- Native Verify run 35752248896: macOS SUCCESS, Windows x64 SUCCESS, Windows ARM64 SUCCESS.
- Evidence: docs/evidence/FPA-004_PRODUCTION_SIGNING_PLUMBING_EVIDENCE.md.
- Fork environment production-release: created.
- Seven required release secrets: not configured.
- Production Release workflow is on the feature branch and must reach the chosen canonical default branch before workflow_dispatch registration.
- Upstream PR #2 is OPEN; connected bot has read-only permission upstream.
- Exact next action is owned by tasks/FINAL_PRODUCT_AUDIT_FIX_QUEUE.md. Do not mark FPA-004 or APP RELEASE READY PASS without a real credentialed production release run.


Final post-remediation note:\n- production-release environment is created on the fork with a main-only deployment branch policy.\n- final audit: docs/audit/FINAL_PRODUCT_POST_REMEDIATION_AUDIT_2026-09-22.md.\n- no new repo-internal technical blocker found.\n

Default-branch Production Release registration VERIFIED:
- fork main: 884e9a89a98ddd5343bb4d3e6aef8b4499f810cb
- native Verify run 35755705022: macOS / Windows x64 / Windows ARM64 SUCCESS
- Production Release workflow active on default branch
- production-release environment restricted to main
- 0/7 real release secrets configured
- Remaining blocker: real credentials + one real Production Release run.


V11-009 technical fork-main verification PASS:
- exact fork main: 1d3e14d23a089bf36d36c1a3c2eb315005136793
- native Verify run 35756276412: macOS / Windows x64 / Windows ARM64 SUCCESS
- final V11-009 remains EXTERNAL-BLOCKED; do not repeat technical main gates unless code changes.


Credential boundary recheck:
- Windows code-signing identity metadata scan: 0 usable identities.
- Local production release credential presence: 0/7.
- GitHub production-release Environment secret names: 0/7.
- No secret values/private keys were read or exported.
- No further automatic release action is valid until real credentials are provisioned.
