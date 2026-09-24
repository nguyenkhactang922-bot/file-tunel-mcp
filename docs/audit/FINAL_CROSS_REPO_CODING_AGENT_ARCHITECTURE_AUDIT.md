# FINAL Cross-Repo Coding-Agent Architecture Audit

Status: SYNTHESIS COMPLETE — PENDING RED-TEAM/FREEZE
Date: 2026-09-23
Target: FileMCP

## 1. Exact audited sources

| Reference | Exact commit | Role in audit |
|---|---|---|
| FileMCP | `9f25db7cb3927a2ff18c260ffdc19710de9c922d` at synthesis start | target/current implementation truth |
| ChatCMD | `c20e134ad6b60ef12eee7231bcbca56f5252be45` | catalog, exec, versioned edits, budgets, evidence, PTY/subagent counter-reference |
| OpenAI Codex | `cb1eea3e98ebc433ab5f9c12ce043e979d1902df` | policy, OS sandbox, exec lifecycle, patch/path-race defense, project instruction provenance |
| OpenHands | `1b0dc0b20f224a4e40a31ca1790b51208145bfe5` | current product/source topology |
| OpenHands software-agent-sdk | `5b36cacccc2bbe6f8fbce9e1d3ff4b0a3dcddadb` | canonical workspace/runtime/isolation implementation |
| Aider | `5dc9490bb35f9729ef2c95d00a19ccd30c26339c` | repo map, edit formats, Git/user-change workflow |
| Cline | `9c0e4aaee09f6593eb8d06ec4a35bf19b7dc33f1` | checkpoint/recovery/session persistence |
| Goose | `e678c3b64a1dfd3c262a6a2019f158d33d5dcab0` | MCP composition/filtering, recipes, subagent product layer |

The OpenHands audit deliberately follows its current canonical runtime dependency rather than attributing old runtime behavior to the current Agent Canvas repository.

## 2. Source-first evidence result

The final architecture is based on shipped source and test presence, not roadmap prose. The strongest source-backed findings are:

- ChatCMD: router-derived catalog/hash, structured command result, authenticated version tokens, atomic/versioned edit engine, resource budgets, cancellation/conflict/symlink-swap tests.
- Codex: distinct policy and sandbox layers, platform-specific isolation, explicit filesystem/network authority, path-swap patch tests, instruction provenance.
- OpenHands SDK: workspace abstraction, host/remote/container backends, hardened per-conversation Docker lifecycle and resource controls.
- Aider: tree-sitter repository map, symbol/reference ranking and bounded token rendering; multiple model-facing edit adapters.
- Cline: transactional checkpoint restore with rollback, divergence guard and staged/unstaged/untracked handling; broad durable session artifacts.
- Goose: multi-provider tool composition/filtering and full subagent/session machinery.

Focused external tests that could not finish inside the local bridge timeout are recorded as environment/time-blocked rather than converted into PASS claims.

## 3. What problem FileMCP actually has

FileMCP is already strong at the bridge boundary. Its next architecture problem is **correctness and evidence under autonomous coding work**, not rebuilding transport or becoming an agent platform.

Current source-visible gaps are:

1. no single canonical tool/schema/capability authority across C# and Swift;
2. MCP process tool is shell-string-facing despite structured native ProcessRunner layers underneath;
3. no optimistic file identity / expected-version contract;
4. no mutation-time no-follow/path-identity revalidation contract;
5. no canonical atomic multi-edit primitive;
6. traversal uses hard caps but lacks one shared budget/cursor/cancellation contract;
7. observability is not a server-owned verification/evidence authority;
8. project instruction context lacks a canonical provenance/digest contract;
9. large-repository structural context is absent;
10. risk policy is coarser than the future catalog requires.

## 4. Strong FileMCP systems that should not be replaced

### Transport/auth — KEEP

FileMCP loopback-only listener, strict Host/Origin checks, local runtime token and Secure MCP Tunnel form a narrower trust surface than ChatCMD-style public bearer URLs or browser bridges.

### Safe path boundary — KEEP + HARDEN

Current canonicalization/reparse protections are valuable and already tested. The missing property is commit-time identity/path revalidation, not a wholesale resolver replacement.

### Git safe mode — KEEP

No compared repository provides a better fit for FileMCP's combination of contained Git metadata, disabled hooks/signing/content-filter attack paths, sanitized environment and non-interactive execution. Sandbox/container layers are complementary, not replacements.

### Native ProcessRunner — KEEP + HARDEN

Both Windows and macOS already use executable+argv internally, bounded output, timeout/cancellation mechanics and process-tree/group cleanup. The missing layer is the MCP contract/evidence/policy around them.

### Observability — KEEP, evidence separate

Current telemetry persists counters/metadata rather than sensitive task content. This privacy boundary should be preserved. New verification evidence must be separate and equally privacy-minimal.

### Native dual-runtime strategy — KEEP

No evidence justifies a Rust/Python rewrite. Cross-platform contract generation/validation is cheaper and safer than replacing working C#/Swift runtimes.

## 5. Final comparative decisions by subsystem

### 5.1 Canonical tool catalog

**Decision: ADD/ADAPT.**

Use a language-neutral canonical manifest containing tool names, input/output schemas, protocol/catalog/instruction versions/hashes, risk/effect class and declared feature flags. Both native runtimes must prove their advertised catalogs match it.

Important invariant: catalog annotations are descriptive. Active authority is server-owned policy and cannot be changed by request metadata.

### 5.2 Process execution

**Decision: ADD `exec_process`; KEEP `run_command` compatibility.**

`exec_process` takes executable + argv + cwd + bounded explicit environment overrides + timeout/output budgets. It returns terminal state, exit code, timeout/cancel/truncation and operation identity.

New structured exec must use a sanitized baseline environment instead of inheriting the entire FileMCP process environment by default.

`run_command` remains available for shell workflows but is classified as high-risk/open-world and is not the preferred deterministic build/test primitive.

A durable command-idempotency registry is DEFERRED until a concrete retry problem requires it; an idempotency key must not pretend arbitrary commands are side-effect safe.

### 5.3 Execution backend / sandbox

**Decision: host-first; optional isolation DEFERRED.**

Phase A uses current native runners. The public/structured exec contract must not assume host-specific result semantics, but FileMCP should not prematurely refactor every tool behind a generic workspace backend before a second backend is approved.

A later isolation ADR may add OS sandbox/container backend. It must specify network policy, mounts, credentials, image/provenance, lifecycle/cleanup and cross-platform acceptance. Mandatory Docker is rejected.

### 5.4 File identity and mutation

**Decision: ADD strong version identity + Mutation Guard + atomic `apply_edits`.**

The canonical mutation safety condition is:

```text
expected strong version still matches
AND
commit-time canonical/no-follow path identity still matches authorized object/ancestor chain
AND
atomic publish succeeds
```

For mutation preconditions, metadata-only versions are insufficient as the sole strong check. Use an authenticated/opaque token binding path/identity plus content-strength evidence appropriate to the operation. Lightweight metadata versions may still be exposed for read/cache hints.

Pre-commit cancellation/conflict leaves the original intact and removes staging. Cancellation after atomic publish reports committed success, not a false cancellation.

Model-oriented patch/search-replace/unified-diff adapters are DEFERRED above this primitive.

### 5.5 Traversal / large outputs

**Decision: KEEP current tools + HARDEN with shared budgets/cursors/cancellation.**

Hard caps remain. Add a common ToolBudget and cooperative cancellation inside traversal/read loops. Resumable cursors, where exposed, must be opaque/signed and bind workspace/root, query/options and a generation/freshness identity so tampering/stale continuation fails closed.

Artifact spillover is DEFERRED until inline bounds materially block workflows.

### 5.6 Evidence / verification

**Decision: ADD metadata-only evidence layer.**

Evidence records may contain:
- operation/execution ID;
- tool/capability class;
- start/end/state/exit/timeout/cancel/truncation;
- backend class identifier;
- opaque workspace/source-state digest;
- artifact metadata/hash where explicitly produced;
- verification criterion identifiers.

Evidence must not persist raw prompt/chat/tool args/commands/file content/Git messages/secrets.

Evidence freshness states must include at least: passed, failed, not-run, unknown, stale, blocked and not-applicable where justified. The word `PASS` in stdout is never authoritative.

Evidence persistence must have bounded retention/quota and be logically separate from telemetry tables.

### 5.7 Project context

**Decision: ADD bounded project-context provenance/digest.**

Return instruction sources, scope/provenance, bounded excerpts/ranges and effective digest. Repository instructions influence behavior but never authority. Restricted/untrusted profiles may suppress or demote repository-owned instructions.

### 5.8 Repository intelligence

**Decision: architecture slot ACCEPTED; implementation DEFERRED to Phase B/profile gate.**

Aider proves value for large repositories. If implemented, provide on-demand structural metadata (`repo_map` / `symbol_search`) using parser/tag caches with explicit invalidation. Cache is rebuildable performance state, not observability/evidence, and must not persist full source by default.

Ordinary file/search tools must work when the index/cache is unavailable or corrupt.

### 5.9 Policy / autonomy

**Decision: ADD/ADAPT server-owned profiles.**

Minimum conceptual profiles:
- restricted;
- workspace-auto;
- custom/local policy.

Risk classes and effective tool visibility may reduce what the model sees, but hidden tools are not the only security boundary. Runtime authorization rechecks policy. The model, project files and catalog metadata cannot elevate authority.

Filesystem/network/open-world dimensions remain separable. Pre-authorized routine workspace work should not require per-call clicking.

### 5.10 Checkpoint / recovery

**Decision: DEFER behind separate ADR.**

Cline proves that safe restore is a transaction with rollback/divergence/untracked semantics, not `git reset`. Current FileMCP does not need this complexity to deliver Phase A correctness.

Keep the conceptual separation:

`Git != checkpoint != task state != evidence != observability`.

Broad persistent session/transcript storage is rejected.

### 5.11 PTY

**Decision: DEFER Phase B.**

PTY is useful for interactive CLIs/debuggers but is not the canonical build/test evidence path. Any PTY later requires bounded replay, expiry, cancellation, policy and cleanup semantics.

### 5.12 MCP composition

**Decision: REJECT from FileMCP core.**

Goose proves MCP composition is viable, but making FileMCP an MCP-of-MCP host would add external provider lifecycle, OAuth/secrets, name conflicts and policy surfaces. ChatGPT can coexist with multiple connectors. FileMCP stays a focused execution server.

### 5.13 Local task engine / sub-agents

**Decision: REJECT from current core architecture.**

ChatCMD/Goose/OpenHands show this is an agent-platform layer with model/provider/session/conversation/persistence authority. The user's operating law explicitly assigns orchestration to ChatGPT and execution to FileMCP. Reintroducing local agents requires a future product ADR, not a hidden Phase C implementation.

## 6. Cross-platform feasibility result

Phase A features are accepted only with an explicit C#/Swift contract plan.

- Catalog: common canonical manifest; native parsing/validation.
- Result envelope: identical schema/semantics; native serialization.
- exec_process: existing native runners; platform-specific process cleanup retained.
- version tokens: common semantic fields/token purpose; platform-specific identity primitives allowed.
- Mutation Guard: Windows handle/reparse identity strategy and macOS/POSIX no-follow/canonical identity strategy may differ, but race rejection behavior must match.
- budgets/cursors: common schema; native cancellation primitives.
- project context/policy/evidence: common contract with native persistence/credential integration where needed.

No "common" tool passes on one-platform evidence alone.

## 7. Performance/resource result

Phase A avoids mandatory repo indexing, containers and PTYs. Resource work focuses on:
- hard server caps;
- caller-lowerable budgets;
- cooperative cancellation;
- bounded output/evidence;
- signed resumable cursors;
- bounded concurrency;
- no unbounded durable task history.

Repository intelligence and isolation are later opt-in layers specifically because they add the most CPU/storage/startup complexity.

## 8. Failure-injection requirements carried into final design

Mandatory negative scenarios include:
- stale file version;
- external writer between read and commit;
- symlink/junction/path swap before commit;
- cancellation before staging / mid-stream / before version recheck / after atomic publish;
- process timeout/cancel/output limit/child leak;
- unsafe environment injection;
- cursor tamper/stale generation;
- search/list cancellation;
- Git config/hook/filter escape attempts;
- telemetry/evidence privacy leakage;
- policy/profile change between preparation and execution;
- missing/unsupported platform backend;
- corrupt/rebuildable repo-map cache when Phase B is added.

## 9. Negative architecture decisions

Explicitly rejected from current FileMCP core:
- browser ChatGPT DOM automation;
- public bearer-token MCP URL as primary transport;
- recoverable public bearer tokens in local database;
- Rust rewrite;
- broad transcript/tool-argument/command/file-content persistence;
- mandatory Docker/VM runtime;
- external MCP composition/gateway role;
- local general task manager;
- local model/sub-agent runtime;
- full-source persistent code index;
- model-specific patch syntax as the low-level storage authority;
- custom application-layer crypto for local obfuscation.

## 10. Architecture synthesis result

The strongest FileMCP architecture is **not** a union of all compared repos. It is:

```text
existing FileMCP secure bridge
+ canonical contracts
+ structured deterministic execution
+ strong versioned/guarded atomic mutation
+ bounded cancellable large-repo primitives
+ metadata-only evidence/freshness
+ project-context provenance
+ server-owned autonomy policy
+ optional later repository intelligence / isolation / PTY
- agent-platform/session/provider/browser/public-endpoint complexity
```

This synthesis is ready for an independent red-team. It is not architecture freeze until the red-team blockers are resolved and ADR-0005 is written.
