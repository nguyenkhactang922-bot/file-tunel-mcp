# FINAL Security and Trust Boundary Model

Status: FROZEN BY ADR-0005
Date: 2026-09-23

## Security objective

FileMCP is a local execution gateway. Transport identity, workspace authority, process authority, network/open-world authority, repository instructions and model intent are separate concepts.

No request field, prompt, repository file, catalog annotation or child process may grant itself authority.

## Principals

1. Local user / administrator - owns machine/configuration, shared root and active policy.
2. MCP client / ChatGPT - requests actions but cannot create authority.
3. Repository content - supplies context/instructions but never authorization.
4. FileMCP server - authoritative policy/path/Git/mutation/evidence enforcement point.
5. Executed process - receives only selected cwd/environment/backend authority.
6. Optional future isolated backend - separate future runtime boundary, not assumed by Phase A.

## Authority chain

transport authentication -> workspace boundary -> local policy -> capability authorization -> operation validation -> execution/mutation -> evidence.

Each stage may reduce authority. No later stage may expand it.

## Transport

KEEP loopback listener, runtime local token, strict Host/Origin behavior and OpenAI Secure MCP Tunnel. REJECT public bearer-token URL as primary transport, browser DOM/cookie/session bridge and recoverable public bearer tokens.

## Workspace and mutation

KEEP current path containment. HARDEN mutations with a Mutation Guard that revalidates canonical/no-follow target and ancestor identity immediately before destructive/commit action. A version match alone does not authorize a path that has been swapped.

## Policy

Minimum profiles: restricted, workspace-auto and custom/local policy.

Policy dimensions remain separable: content read, mutation, destructive mutation, process execution, network/open-world, Git remote and configuration/permission changes.

Tool visibility may be reduced for UX, but runtime authorization always rechecks. The model, repository instructions and catalog metadata cannot elevate the active profile.

## Process authority

Phase A remains host-native. exec_process uses executable + argv + contained cwd + sanitized environment + explicit bounded overrides + timeout/output budget. run_command remains high-risk shell compatibility.

Policy is not a sandbox. Optional sandboxing is DEFERRED and cannot replace path/Git semantic validation.

## Network/open-world authority

Network/open-world capability is independent of workspace write authority. Phase A host execution cannot promise OS-level egress denial and must not pretend otherwise.

## Git

KEEP Git safe mode: contained worktree/metadata/object paths, hook/signing/config/content-filter defenses, non-interactive behavior and restricted transport settings. Generic sandboxing is complementary only.

## Repository instructions

Project context exposes source/provenance/digest. Repository instructions influence behavior; they never grant authority.

## Persistence/privacy

Allowed durable evidence is metadata only: opaque operation/evidence IDs, capability class, timestamps/state, exit/timeout/cancel/truncation, opaque source/workspace digest, artifact metadata/hash and criterion IDs.

Forbidden by default: prompt/chat text, raw tool args, raw commands, file contents, Git messages, cookies, bearer tokens, API/private keys.

Evidence and telemetry are logically separate contracts even if a future storage engine is shared.

## Delegation

No local task/sub-agent runtime exists in current core. ChatGPT remains orchestration authority. A future local agent layer requires a product ADR because it introduces new principals, provider secrets, persistence and inherited authority.

## Fail closed

Fail closed on invalid local auth, containment ambiguity, stale version, Mutation Guard mismatch, tampered/stale cursor, unsupported policy/backend combinations, policy changes invalidating pending operations and unsafe Git metadata/config.

## Cross-platform rule

A common capability is incomplete until Windows and macOS have equivalent authority semantics, failure classification, adversarial tests and native/package verification. Different primitives are allowed; weaker semantics are not.
## Red-team compatibility and generation rules

- EnableCommands=false -> restricted-equivalent migration.
- EnableCommands=true -> migration-only legacy-command-compatible profile; never auto-convert to workspace-auto.
- New installs begin restricted until local user chooses otherwise.
- Operation context captures policy generation/hash; side-effect authority is rechecked immediately before action.
- Catalog artifact is descriptive and canonical for schema, but only policy grants authority.
- SourceStateRef/evidence IDs are evidence/freshness material, never bearer authorization.
