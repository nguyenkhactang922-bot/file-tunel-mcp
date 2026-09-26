# FMG-010 - Project Context Provenance / Digest - Candidate Evidence

Date: 2026-09-26
State: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING
Branch: chatgpt/FMG-010-project-context

Scope implemented:
- canonical read-only project_context tool under catalog 1.5.0;
- bounded root-to-scope repository instruction discovery;
- same-scope AGENTS.override.md precedence over AGENTS.md;
- deterministic ordered provenance with strong file versions and content hashes;
- deterministic context_digest / generation;
- authenticated bounded continuation cursor bound to tool/options/root/generation/position;
- explicit repository_untrusted / grants_authority=false metadata;
- local policy metadata only; project content never grants authority;
- existing Codex skill metadata reused without inlining skill bodies;
- ToolBudget + cooperative cancellation;
- equivalent Windows C# and macOS Swift implementation;
- native macOS build/dev/CI compile wiring.

Adversarial coverage:
- deterministic root -> nested provenance;
- nested conflict / override precedence;
- malicious repository authority request;
- policy generation/hash unchanged;
- digest stability and relevant-source change;
- stale cursor rejection;
- path escape rejection;
- oversized instruction rejection;
- caller-lowered budget;
- cooperative cancellation;
- skill metadata only;
- MCP tools/list and tools/call exposure.

Canonical:
catalogVersion: 1.5.0
tools: 22
catalog SHA-256: f717cf599faf112964a981e516de0898d4ce140c3f6daca15d732f13216a53aa

Local gates PASS:
- project_context contract
- tool catalog contract
- tool surface parity
- FMG-006 source-state contract
- FMG-007 mutation-guard contract
- FMG-008 mutation-hardening contract
- FMG-009 apply-edits contract
- Swift/build shell syntax
- git diff --check

Windows exact-worktree:
- Release build PASS, 0 warnings / 0 errors
- windows-project-context: ok
- full runtime PASS, 715 assertions
- isolated x64 package/app smoke PASS
- ZIP SHA-256: 9ABA9428D8CD22F0FE29F30D3D3D05FAA3327D512DA95DDAC183EE28DE31ECFB

Remaining gate:
Native GitHub Verify required on exact committed candidate:
- verify-macos
- verify-windows
- verify-windows-arm64

Do not mark FMG-010 DONE or claim FMG-011 until exact-head native Verify, scoped review, merge and merged-main verification complete.
