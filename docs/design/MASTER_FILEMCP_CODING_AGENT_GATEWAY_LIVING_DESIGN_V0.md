# MASTER FileMCP Coding-Agent Gateway Living Design V0

Status: LIVING DRAFT — NOT ARCHITECTURE FREEZE
Date: 2026-09-23
Baseline HEAD: 38026d8a23136b9371369855354acabe4bb8b3e2
Authority inputs: the 14 new Markdown artifacts created on 2026-09-23 plus current AGENTS/process/execution laws and exact current source.

## Purpose

This is the continuously updated working design for the next FileMCP architecture. It intentionally sits above ADR-0004 while the final cross-repo audit is in progress. It must change when source evidence or independent review disproves an assumption.

No feature code may be implemented from this document until the final comparative audit, ADR-0005 and master dependency graph are complete.

## Problem statement

FileMCP is already a verified local execution bridge with strong loopback authentication, shared-root containment, Git safe mode, native Windows/macOS runtimes, bounded one-shot process execution, tool-surface parity checks and privacy-minimal observability. The next problem is not to rebuild those strengths. The problem is to make the bridge substantially more reliable for coding-agent work without expanding its trust surface unnecessarily.

The next architecture must answer five gaps that remain source-visible today:

1. tool contracts are duplicated across native implementations and lack one canonical catalog hash/version authority;
2. MCP command execution is shell-string-facing even though native ProcessRunner layers already support executable + argv;
3. file reads/writes lack optimistic-concurrency identity and version-checked mutation;
4. large-repository list/search/read operations use fixed limits rather than one resumable budget/cursor contract;
5. FileMCP has observability but not a formal metadata-only evidence/freshness model for deciding whether a verification claim still applies to current source state.

The final audit must also decide whether FileMCP actually needs additional primitives that ADR-0004 only deferred or did not settle: optional sandboxing, repository-symbol maps, checkpoint/recovery, PTY, MCP composition, a local task engine and sub-agents.

## Current strengths that begin as preservation candidates

These are not pre-declared immutable winners; they are protected until a stronger source-backed alternative proves otherwise:

- loopback MCP listener + runtime local auth;
- OpenAI Secure MCP Tunnel integration instead of public bearer-token MCP URLs;
- SafePathResolver/shared-root containment and reparse/junction defenses;
- Git safe mode: worktree/metadata containment, hook/signing/config/content-filter restrictions and non-interactive behavior;
- native Windows C# + macOS Swift implementation rather than a cross-language rewrite;
- bounded ProcessRunner implementations with process-tree/process-group cleanup;
- metadata/counter-only observability and secret redaction;
- cross-platform contract verification and native CI.

## Preliminary target layers — subject to audit

```text
MCP CLIENT / CHATGPT
        ↓
SECURE TUNNEL + LOOPBACK AUTH
        ↓
CANONICAL CATALOG + CAPABILITY CLASSIFICATION
        ↓
SERVER-OWNED POLICY / AUTHORITY
        ↓
OPERATION CONTEXT
workspace + project-context digest + cancellation + resource budget
        ↓
┌──────────────────────┬──────────────────────┬─────────────────────┐
│ FILESYSTEM           │ GIT                  │ PROCESS             │
│ versioned read/stat  │ existing safe mode   │ exec_process        │
│ expected-version     │ structured results   │ explicit run_command│
│ atomic apply_edits   │ source fingerprint   │ optional later PTY  │
└──────────────────────┴──────────────────────┴─────────────────────┘
        ↓
STRUCTURED RESULT / METADATA-ONLY EVIDENCE
        ↓
OBSERVABILITY / HEALTH / OPTIONAL EPHEMERAL ARTIFACTS
```

## Unresolved architecture decisions

These remain OPEN until cross-repo evidence is complete:

- host execution only vs host + policy vs optional sandbox vs mandatory sandbox;
- whether exec_process needs only the existing ProcessRunner or a durable execution registry/journal;
- exact file version-token strength and mutation semantics;
- whether patch/search-replace/model-specific editing belongs above apply_edits;
- whether project-context digest alone is enough for large repositories or a symbol/repository map is required;
- whether checkpoints should exist independently of Git and evidence;
- whether persistent PTY belongs in Phase B or must move earlier;
- whether FileMCP should compose external MCP servers or simply coexist with them;
- whether any local task/sub-agent runtime is justified at all.

## Preliminary sequencing hypothesis — NOT FINAL TASK GRAPH

```text
catalog authority
  ↓
structured result contract
  ↓
structured exec_process       file version identity
        ↓                           ↓
execution evidence             versioned mutation/apply_edits
        \                           /
         \                         /
          shared budget/cursor/freshness
                    ↓
          project-context decision
                    ↓
            policy/autonomy model
                    ↓
       recovery/checkpoint decision
                    ↓
          optional sandbox decision
                    ↓
            independent red-team
```

This sequence may change after Codex/OpenHands/Aider/Cline/Goose comparison.

## Design update rule

After every deep-dive subsystem audit:

1. record the source evidence separately;
2. change this living design only when evidence materially changes a decision;
3. record why the decision changed;
4. do not silently convert an OPEN question into a frozen decision;
5. do not create implementation tasks until dependency contradictions are resolved.

## Current design status

- 14 source documents ingested: COMPLETE.
- current FileMCP source baseline mapped: IN PROGRESS.
- ChatCMD deep audit: COMPLETE baseline, must be revalidated against final comparisons.
- Codex audit: COMPLETE - source audit at docs/audit/CODEX_SOURCE_AUDIT_2026-09-23.md.
- OpenHands audit: COMPLETE - exact runtime source at software-agent-sdk v1.49.4 / e7cc8c27; see docs/audit/OPENHANDS_SOURCE_AUDIT_2026-09-23.md.
- Aider audit: COMPLETE - source audit at docs/audit/AIDER_LARGE_REPO_EDITING_AUDIT_2026-09-23.md.
- Cline audit: COMPLETE - source audit at docs/audit/CLINE_RECOVERY_CHECKPOINT_AUDIT_2026-09-23.md.
- Goose audit: COMPLETE - source audit at docs/audit/GOOSE_MCP_ORCHESTRATION_AUDIT_2026-09-23.md.
- independent contradiction/red-team rounds: PENDING.
- ADR-0005: NOT CREATED.
- final task graph: NOT CREATED.
- feature coding: FORBIDDEN.

## Codex R2 architecture update

Pinned source: openai/codex@cb1eea3e98ebc433ab5f9c12ce043e979d1902df

1. Policy authority is a stronger invariant: future risk/capability catalog metadata never grants authority; active authority is server-owned. Filesystem and network dimensions remain separable and deny rules survive escalation.

2. Optional OS sandbox remains OPEN but serious. Codex ships/test platform sandbox machinery deeply. OpenHands must decide host-native sandbox vs optional container/remote isolation vs host-first only.

3. Structured exec_process remains the preferred new MCP primitive. Codex internal command lifecycle confirms executable/argv-style structure plus bounded cancellation, while FileMCP should expose that safer boundary directly.

4. Atomic versioned editing remains stronger than Codex apply_patch for Phase A. Codex patch tests prove partial side effects can remain after later failure, so expected-version atomic edits stay foundational.

5. Project context is strengthened: hierarchical instruction discovery, source provenance, bounded bytes and untrusted-project behavior become target requirements. Repository instructions are context, never authorization.

6. Broad local thread/rollout persistence is rejected. A much smaller metadata-only checkpoint layer stays OPEN pending Cline/OpenHands.

Open after Codex: optional isolation model; repository symbol map; minimal checkpoint/recovery; PTY timing; external MCP composition; local task/sub-agent runtime.
## Cross-repo synthesis update R3

Evidence inputs now include independent audits of ChatCMD, Codex, OpenHands runtime/SDK, Aider, Cline and Goose.

### Decisions that have converged

- **Transport/auth:** KEEP FileMCP loopback + runtime token + Secure MCP Tunnel. Public bearer-token MCP URLs and browser DOM automation remain rejected.
- **Path/Git safety:** KEEP + HARDEN. Existing SafePathResolver/Git safe mode remain stronger product-fit controls than generic alternatives. Add a mutation-time path/identity revalidation guard for write/delete race safety.
- **Catalog:** ADD a language-neutral canonical manifest with protocol/catalog/instruction hashes and capability/risk metadata. Runtime policy remains authoritative; catalog metadata never grants permission.
- **Execution:** KEEP native ProcessRunner; ADD structured `exec_process`; KEEP `run_command` as explicit high-risk shell compatibility. The first implementation may call existing runners directly; a multi-backend execution abstraction is deferred until a second backend is actually approved.
- **Isolation:** host-native execution remains default. Optional OS/container isolation is a source-backed future hardening mode, not a Phase A dependency and not a replacement for policy/Git/path controls.
- **Environment:** new structured exec must use a sanitized baseline plus explicit overrides/allow rules rather than automatically inheriting the full FileMCP host environment.
- **Filesystem concurrency:** ADD authenticated/opaque version identity, expected-version mutation, commit-time Mutation Guard and atomic `apply_edits`. Model-friendly patch/search-replace formats may be adapters later, not the storage authority.
- **Traversal:** KEEP current simple list/search/read behavior as baseline but ADD shared budgets, signed/bound cursors where continuation is exposed, explicit usage/truncation and cooperative cancellation inside traversal loops.
- **Evidence:** ADD a metadata-only evidence/freshness layer separate from observability. Persist operation state and opaque digests only; never raw prompt/tool args/commands/file content/Git messages/secrets.
- **Project context:** ADD bounded instruction discovery/provenance/digest. Repository instructions never grant authority.
- **Repository intelligence:** ADD an optional/on-demand structural symbol-map architecture slot after Phase A/profile proof; keep cache rebuildable and separate from observability. Do not persist full source as an index.
- **Checkpoint:** DEFER. Git, checkpoint, task state, evidence and observability remain distinct. Any future destructive workspace restore requires a separate transaction/recovery design/ADR.
- **PTY:** DEFER. It is useful for interactive workflows but not a prerequisite for deterministic build/test evidence.
- **MCP composition:** REJECT from FileMCP core. FileMCP should coexist with other MCP servers rather than becoming an MCP-of-MCP secret/provider manager.
- **Local task engine/sub-agents:** REJECT from FileMCP core under the current product law. ChatGPT remains the orchestration layer; adding local agents would redefine the product and requires a future product ADR.

### New architecture invariant discovered after R2

A mutation is authorized only if **both** are still true at commit time:

1. the expected file/version identity still matches; and
2. the canonical/no-follow path authority still resolves to the same authorized object/ancestor chain.

This `Version + Mutation Guard` conjunction is now stronger than ADR-0004's original version-token-only wording.

### Architecture slots still deliberately deferred rather than unknown

- optional isolated execution backend;
- persistent PTY;
- ephemeral large-output artifact spillover;
- repository intelligence implementation after benchmark/profile gate;
- checkpoint capture/restore under a separate ADR if later justified.

These are deliberate DEFER decisions, not unresolved blockers for Phase A architecture freeze.

## OpenHands R3 architecture update

OpenHands resolves the isolation question for the current architecture.

### Phase A execution topology

FileMCP remains **host-native by default**. Existing shared-root/Git/process containment stays mandatory, and the new structured execution/policy layers are built on top of the native ProcessRunner. Docker is not introduced as a normal prerequisite.

### Reserved future seam

The final architecture may reserve an execution-backend seam, but no generic backend abstraction is required before a second backend is actually approved. A later isolated backend may be added without changing MCP tool semantics if it satisfies hardened runtime requirements.

### Minimum isolated-backend contract if later approved

- per-runtime identity/credentials;
- explicit workspace/persistence mounts only;
- reparse/symlink-safe host containment;
- non-root execution;
- dropped capabilities and no-new-privileges;
- loopback-only control plane;
- CPU/memory/PID caps;
- sanitized environment and explicit secret mediation;
- image pin/provenance;
- explicit outbound-network policy;
- health/start/stop/restart/cleanup evidence;
- execution result records backend identity.

### Rejected from current core

OpenHands-style event-sourced conversation runtime and local subagent/task engine are rejected from FileMCP core. FileMCP remains a narrow execution gateway; ChatGPT Web remains the coding/orchestration agent.

### Still open after OpenHands

- minimal metadata-only checkpoint/recovery (Cline decides);
- large-repository intelligence (Aider decides);
- external MCP/tool composition (Goose decides);
- persistent PTY timing remains Phase B.

## Aider R4 architecture update

Pinned source: Aider-AI/aider@5dc9490bb35f9729ef2c95d00a19ccd30c26339c

Aider confirms that large repositories benefit from structural symbol intelligence, but it should remain an **optional on-demand context service** rather than silently expanding FileMCP into a persistent code-index product.

Final living decision after R4:
- Phase A project_context: rules/provenance/digest/budget only;
- Phase B repository intelligence: optional bounded `repo_map` / `symbol_search`;
- cache is rebuildable performance metadata, separate from telemetry/evidence;
- no raw full-source persistent index by default;
- repo-map failure never blocks baseline file/search/edit tools;
- Aider search/replace/patch formats may later compile into the safer FileMCP versioned edit primitive; they are not the storage/security contract;
- Aider automatic Git commit workflow is not imported into low-level FileMCP.

## Cline R5 architecture update

Pinned source: cline/cline@9c0e4aaee09f6593eb8d06ec4a35bf19b7dc33f1

Cline closes the recovery question for Phase A. FileMCP does **not** become a durable agent-session product.

Approved now:
- explicit operation/evidence identity;
- terminal success/failure/cancel/timeout state;
- optional metadata-only restart-resumable evidence records;
- project task state remains repository-owned Markdown under the user's operating law.

Deferred:
- destructive workspace checkpoint capture/restore; if ever built it receives a separate ADR and transactional Git acceptance suite.

Rejected:
- prompt/transcript/tool-body persistence for general session resume;
- a second local task/session authority competing with ChatGPT Web and repo state.

This keeps recovery useful without expanding FileMCP's privacy boundary.

## Goose R6 architecture update

Pinned source: block/goose compatible upstream aaif-goose/goose@e678c3b64a1dfd3c262a6a2019f158d33d5dcab0

Goose reinforces FileMCP's product boundary rather than expanding it.

Approved concept:
- effective catalog filtering by active server-owned policy, while runtime authorization remains independent and fail-closed.

Rejected from FileMCP core:
- MCP-of-MCP extension hosting;
- external provider lifecycle/OAuth/credential management;
- recipe engine duplication;
- local subagent/background-agent runtime and its model/session/task persistence.

FileMCP remains a hardened local execution bridge. ChatGPT or a separate future gateway composes other MCP servers/agents.
