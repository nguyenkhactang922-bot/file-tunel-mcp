# FINAL CROSS-REPO INDEPENDENT ARCHITECTURE AUDIT — MASTER EXECUTION SPEC

Status: **FROZEN AUDIT EXECUTION SPEC — NOT YET THE FINAL AUDIT RESULT**
Date: 2026-09-23
Target repository: **FileMCP**
Target workspace: `D:\Tools\FileMCP`
Current design branch at creation: `chatgpt/chatcmd-integration-audit`
Current FileMCP design HEAD at creation: `088c690c2d810d7971e5d5d866f8b7c97086bd4e`
Current baseline architecture authority: `docs/adr/0004-chatcmd-inspired-execution-foundation.md`
Current ChatCMD audit baseline: `docs/audit/CHATCMD_INDEPENDENT_MULTI_ROUND_INTEGRATION_AUDIT_2026-09-23.md`

---

# 0. PURPOSE

This document defines the **last independent comparative architecture audit** that must be completed before FileMCP begins the ChatCMD-inspired implementation queue at CCI-001.

The purpose is not to find more features for the sake of adding features.

The purpose is to answer, with source-level evidence:

> **What is the strongest architecture FileMCP should adopt for a secure, reliable, cross-platform coding-agent execution gateway after comparing multiple mature open-source approaches rather than inheriting the assumptions of a single reference repository?**

This final audit exists specifically to prevent:

- single-reference bias from ChatCMD;
- copying a subsystem merely because another project implements it;
- confusing README claims with shipped runtime behavior;
- importing product-specific complexity that FileMCP does not need;
- missing a primitive that would later force a breaking architecture redesign;
- weakening FileMCP's existing security/privacy boundaries while adding agent capabilities;
- designing Windows first and discovering macOS incompatibility later;
- freezing task graphs before recovery, large-repo behavior, evidence, policy and sandbox trade-offs have been compared.

The result of this audit must either:

1. **CONFIRM ADR-0004**;
2. **AMEND ADR-0004** with explicit changes; or
3. **SUPERSEDE ADR-0004** with a final architecture ADR.

No feature implementation may begin merely because one compared repository appears stronger in one area.

---

# 1. NON-NEGOTIABLE FILEMCP BASELINE

Every comparison begins from FileMCP's existing strengths. A reference architecture is not allowed to erase them without overwhelming evidence and a new explicit security decision.

## 1.1 Transport and authentication

- MCP listeners remain loopback-only by default.
- OpenAI Secure MCP Tunnel remains the preferred remote connectivity path.
- Runtime local-auth tokens remain ephemeral or stored in platform credential storage.
- No public bearer-token URL becomes the primary FileMCP access model.
- No cookie extraction or browser-session reuse is introduced.
- No third-party browser DOM automation becomes a required execution path.

## 1.2 Filesystem boundary

- Shared-root containment must never be weakened.
- Symlink/reparse/junction escape defenses must remain fail-closed.
- Root deletion protections must remain.
- Future versioning/editing systems must revalidate authority at mutation time, not only at initial read time.

## 1.3 Git boundary

- Git worktree and metadata containment remain mandatory.
- Safe-mode suppression of hooks/signing/content filters/config escape vectors may only become stronger.
- Repository-local credentials or transport settings must not silently expand authority.
- Non-interactive Git behavior remains preferred for automated operation.

## 1.4 Privacy boundary

Observability/evidence must not persist by default:

- prompts;
- chat text;
- raw tool arguments;
- raw commands;
- file contents;
- Git commit messages;
- cookies;
- bearer credentials;
- private keys;
- API keys.

Metadata, counters, hashes/fingerprints, operation states and bounded artifact metadata may be persisted only when their security/privacy purpose is explicit.

## 1.5 Product operating model

FileMCP is primarily:

```text
ChatGPT / MCP client
        ↓
secure local execution gateway
        ↓
files / Git / process / build / test / evidence
```

It is not automatically required to become:

- a full IDE;
- a browser automation product;
- a general multi-user cloud task manager;
- a persistent chat-history platform;
- a sub-agent operating system;
- a container platform.

Those capabilities must earn their place independently.

---

# 2. REPOSITORY SET FOR FINAL AUDIT

The final audit uses a deliberately small but complementary reference set.

Each repository represents a different architectural strength. No repository is treated as the global winner.

## R0 — FileMCP

Local source of truth: `D:\Tools\FileMCP`

Role:
- target architecture;
- security baseline;
- cross-platform baseline;
- integration-cost baseline.

Must be evaluated from exact current source, not memory from earlier FileMCP versions.

## R1 — ChatCMD

Repository: `https://github.com/int04/ChatCmd`

Existing pinned baseline from the previous audit:

`c20e134ad6b60ef12eee7231bcbca56f5252be45`

Primary comparison areas:
- canonical tool catalog;
- structured command execution;
- tool result envelope;
- version tokens;
- atomic/versioned editing;
- resource budgets;
- approval/policy;
- evidence/freshness;
- PTY;
- task/sub-agent architecture.

Existing ChatCMD findings remain input evidence, but this final audit must challenge them rather than simply copy them.

## R2 — OpenAI Codex

Repository: `https://github.com/openai/codex`

Primary comparison areas:
- sandbox architecture;
- execution policy;
- permission escalation/request model;
- process execution boundary;
- shell vs structured command semantics;
- filesystem/network policy separation;
- MCP/tool integration;
- patch/edit mechanics;
- session/recovery behavior;
- trusted vs untrusted project instructions.

Why mandatory:

Codex is the strongest counter-reference to ChatCMD for the question:

> **Should FileMCP solve risky execution primarily through policy/approval, OS sandboxing, or a combination of both?**

## R3 — OpenHands

Repository: `https://github.com/OpenHands/OpenHands`

Primary comparison areas:
- execution isolation;
- local vs Docker vs remote runtime boundaries;
- agent/action/runtime separation;
- workspace mounting;
- recovery/restart;
- long-running tasks;
- resource control;
- backend abstraction;
- security implications of executing arbitrary agent actions.

Why mandatory:

OpenHands is the strongest counter-reference for:

> **Does FileMCP need an optional isolated runtime, or is host execution with strong containment/policy the correct product architecture?**

This audit must not assume containers are automatically safer or more appropriate. It must measure usability, setup cost, filesystem fidelity, performance, platform support and failure recovery.

## R4 — Aider

Repository: `https://github.com/Aider-AI/aider`

Primary comparison areas:
- repository map / large-codebase context;
- symbol-level context selection;
- edit formats;
- file mutation reliability;
- Git integration;
- dirty-worktree handling;
- undo/review model;
- lint/test feedback loop.

Why mandatory:

Aider is the strongest counter-reference for:

> **Does FileMCP need only project-context digest/provenance, or also a first-class repository/symbol map for large codebases?**

It is also a major reference for deciding whether range-edit APIs are sufficient or whether model-specific edit protocols need an abstraction above them.

## R5 — Cline

Repository: `https://github.com/cline/cline`

Primary comparison areas:
- shared agent core across CLI/IDE/SDK;
- task persistence;
- checkpoints;
- resume/recovery;
- plan/act separation;
- MCP interaction;
- human supervision model;
- change recovery;
- multi-surface consistency.

Why mandatory:

Cline is the strongest counter-reference for:

> **How much recovery/checkpoint/task state should FileMCP own locally without violating its privacy-minimal architecture?**

## R6 — Goose

Repository: `https://github.com/aaif-goose/goose`

Primary comparison areas:
- MCP extension composition;
- extension/tool filtering;
- recipe/workflow structure;
- delegation/sub-agent concepts;
- local extensibility;
- tool capability boundaries;
- reusable automation patterns.

Why included:

Goose is a focused comparison for extension composition and future orchestration. It does not need the same audit depth as Codex/OpenHands/Aider unless source findings contradict ADR-0004.

---

# 3. REPOSITORY INTEGRITY / PINNING RULE

At audit execution time, every external repository must be cloned or fetched into an **audit-only location outside the FileMCP Git tree**.

Recommended location:

`D:\Tools\_audit\<repo-name>`

For each repository record:

- canonical repository URL;
- default branch;
- exact commit SHA;
- commit date;
- latest tag/release if relevant;
- license;
- local clone path;
- whether source is complete enough for the subsystem being audited.

No final statement may say "repo X does Y" without identifying the exact audited commit.

If a repository changes during the audit:

- do not silently update;
- either continue on the original pinned SHA;
- or explicitly restart that repository's affected audit rounds with a new pinned SHA.

---

# 4. EVIDENCE CLASSIFICATION

Every capability claim must receive exactly one implementation-status classification.

## S1 — SHIPPED + SOURCE + TEST

Runtime implementation exists and relevant tests/contracts exist.

## S2 — SHIPPED + SOURCE, TEST NOT VERIFIED

Runtime implementation exists, but audit could not verify tests or tests are absent.

## S3 — DOC CLAIM WITH SOURCE PARTIAL

Documentation describes behavior and some source exists, but end-to-end implementation is incomplete or unclear.

## S4 — PROPOSAL / PLAN ONLY

Design/roadmap/issue exists but runtime implementation was not found.

Never use this as evidence that the capability is already mature.

## S5 — STALE / CONTRADICTORY DOCUMENTATION

Documentation conflicts with source, tests, or another authoritative document.

## S6 — AUDIT-ENVIRONMENT-BLOCKED

Source/test appears runnable but local audit environment cannot complete the test because of missing toolchain, OS, credentials or hardware.

This is neither PASS nor FAIL.

## S7 — VERIFIED ABSENT

The capability was specifically searched for and source evidence was not found.

## S8 — REJECTED FOR FILEMCP

Capability may work in the reference repository but is explicitly unsuitable for FileMCP.

---

# 5. SOURCE-FIRST AUDIT LAW

For every important claim, audit in this order:

```text
README / docs claim
        ↓
locate source
        ↓
read implementation
        ↓
find caller/dispatch path
        ↓
find security/policy boundary
        ↓
find tests
        ↓
attempt focused test/build when practical
        ↓
classify evidence
        ↓
map to FileMCP
```

Do not:
- treat README prose as runtime truth;
- treat a plan file as shipped behavior;
- infer security from tool descriptions;
- infer atomicity from a function name;
- infer sandboxing from Docker support;
- infer evidence quality from terminal text;
- infer recovery from persisted records without restart tests;
- infer cross-platform parity from one OS implementation.

---

# 6. CAPABILITY CARD REQUIRED FOR EVERY IMPORTANT FINDING

Every candidate subsystem must be summarized using this exact logical structure:

**Capability:**
**Reference repo:**
**Pinned SHA:**
**Evidence classification:**
**Source paths:**
**Tests/source proof:**
**What problem it solves:**
**Trust boundary introduced:**
**Persistent data introduced:**
**Failure modes:**
**Cross-platform implications:**
**Performance implications:**
**Migration/compatibility cost:**
**FileMCP equivalent today:**
**Gap in FileMCP:**
**Primary final action (KEEP / KEEP + HARDEN / ADAPT / REPLACE / ADD / DEPRECATE / REMOVE / DEFER / REJECT):**
**Prerequisites:**
**Required FileMCP test evidence:**
**Open questions:**

A capability cannot enter the final architecture without a completed card.

---

# 6A. FILEMCP FUNCTION / SUBSYSTEM UPGRADE MATRIX - MANDATORY

This final audit must not stop at architecture-level conclusions.

It must audit the actual FileMCP functions/subsystems that are running in the current repository and decide, for each meaningful capability, whether the current implementation should be preserved, strengthened, adapted, replaced, supplemented, deprecated, removed, deferred or explicitly rejected.

## 6A.1 Exact-current-source rule

Every FileMCP row must be derived from the exact current FileMCP source resolved during ROUND 0.

Do not use remembered behavior from an earlier FileMCP revision.

For each function/subsystem record at minimum:

- FileMCP capability name;
- exact Windows source file/class/method when applicable;
- exact macOS source file/type/function when applicable;
- MCP tool/schema entry points when applicable;
- current behavior;
- current strengths;
- current weaknesses / missing guarantees;
- current security boundary;
- current performance/resource characteristics;
- current cross-platform parity state;
- current tests/evidence;
- stronger or alternative reference implementations found in R1-R6;
- whether the reference actually solves the same problem;
- migration and compatibility cost;
- required negative tests;
- final upgrade action.

## 6A.2 Allowed final upgrade actions

Every audited FileMCP capability must end in exactly one primary action:

| Action | Meaning |
|---|---|
| KEEP | Current FileMCP implementation is already the correct architecture; preserve it as-is except ordinary maintenance. |
| KEEP + HARDEN | Preserve the implementation and contract, but add missing safety, evidence, performance or parity guarantees. |
| ADAPT | Reuse the existing FileMCP subsystem as the base and import selected ideas/contracts from references. |
| REPLACE | Current implementation is materially weaker or structurally wrong; introduce a stronger replacement with migration/compatibility plan. |
| ADD | Capability does not currently exist and should be added as a new subsystem/tool. |
| DEPRECATE | Keep temporarily for compatibility while a stronger path becomes preferred. |
| REMOVE | Capability should be removed because it is redundant, unsafe or conflicts with the final architecture. |
| DEFER | Useful, but dependencies/evidence/product need do not justify implementation in the current upgrade wave. |
| REJECT | Explicitly unsuitable for FileMCP even if reference repositories implement it. |

Secondary notes may be attached, but the primary action must be unambiguous.

## 6A.3 Replacement rule

A reference implementation may replace a FileMCP capability only when the audit proves all of the following:

1. the current FileMCP capability has a concrete weakness, not merely a stylistic difference;
2. the proposed replacement solves that weakness in shipped source, not only documentation;
3. the replacement does not weaken FileMCP security/privacy invariants;
4. Windows and macOS feasibility is designed;
5. migration/compatibility behavior is explicit;
6. rollback is possible or the irreversible trade-off is explicitly accepted;
7. acceptance and negative tests are defined;
8. the replacement does not create a larger unnecessary product surface.

If those conditions are not met, prefer KEEP + HARDEN or ADAPT over REPLACE.

## 6A.4 Add-new-function rule

A new function/subsystem may be added only when:

- no existing FileMCP capability already solves the need adequately;
- the capability closes a source-verified gap;
- its authority/trust boundary is explicit;
- persistence/privacy impact is explicit;
- Windows/macOS scope is explicit;
- dependency position in the master task graph is explicit;
- it has measurable acceptance evidence.

Do not add a feature simply because another repository has it.

## 6A.5 Function-level comparison schema

The final audit must produce a matrix with at least these columns:

| FileMCP current capability | Exact source | Current strength | Current weakness | Best external reference(s) | Reference evidence class | Gap type | Final action | Target design | Migration / compatibility | Required evidence |
|---|---|---|---|---|---|---|---|---|---|---|

Representative categories that must be covered include, at minimum:

- tool catalog / schema generation;
- LocalMcpServer request handling;
- local authentication;
- Secure MCP Tunnel integration;
- SafePathResolver / path containment;
- read_file / read_file_range;
- search_content / search_filenames;
- write_file;
- delete_file / delete_directory;
- process runner;
- run_command;
- Git discovery / status / diff / add / commit / push;
- Git safe mode;
- Codex skill discovery/loading;
- observability correlation;
- telemetry persistence;
- runtime/tunnel supervision;
- Windows/macOS parity tests;
- release/build verification contracts.

The audit must also add rows for capabilities that do not exist in FileMCP today but are serious candidates, such as:

- canonical catalog hash/version;
- structured exec_process;
- structured result/evidence envelope;
- file version token;
- expected-version mutation;
- atomic apply_edits;
- shared budget/cursor contract;
- project-context digest;
- repository symbol map/index if justified;
- checkpoint/recovery layer if justified;
- policy profiles;
- PTY if justified;
- local task/sub-agent runtime only if the final architecture approves it.

## 6A.6 Strong-current-function protection

When FileMCP is stronger than the references, the matrix must say so explicitly.

Examples may include, subject to actual source verification:

- shared-root containment;
- Windows reparse/junction defenses;
- Git safe-mode constraints;
- loopback + runtime local-auth boundary;
- OpenAI Secure MCP Tunnel integration;
- privacy-minimal observability.

Such capabilities should normally become KEEP or KEEP + HARDEN, not be replaced merely for architectural uniformity with another repository.

## 6A.7 Weak-current-function replacement proof

When FileMCP is weaker, the audit must show:

current source -> exact weakness -> reference source -> stronger property -> target FileMCP contract -> migration -> tests.

Example logical shape only:

run_command
-> flexible but shell-string-facing
-> underlying ProcessRunner already executable + argv
-> ChatCMD/Codex structured execution provides a stronger MCP boundary
-> KEEP ProcessRunner
-> KEEP run_command for compatibility
-> ADD exec_process as preferred structured primitive
-> DEPRECATE nothing until usage evidence supports it.

This example is not pre-approved as the final decision; the final audit must revalidate it against exact current source.

## 6A.8 Mandatory final artifact

The audit must produce:

`docs/design/FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md`

This file is a release gate for the final architecture. It must contain every meaningful FileMCP capability audited and every approved new capability.

No MASTER FINAL architecture may be frozen while this matrix contains:

- UNKNOWN;
- TBD;
- unmapped exact source;
- unresolved cross-platform feasibility;
- unresolved replacement migration;
- unresolved security/privacy impact;
- unresolved acceptance evidence.

---

# 7. FINAL AUDIT ROUNDS

A later round may overturn an earlier recommendation.

## ROUND 0 — FILEMCP EXACT BASELINE

Before comparing external repositories:
1. resolve Git root, branch, HEAD and worktree;
2. read AGENTS.md, execution law, current handoff, project state, ADR-0004, ChatCMD source mapping, decision matrix and candidate task queue;
3. enumerate actual tool schemas on Windows and macOS;
4. map current process, file, Git, tunnel, telemetry and skill subsystems.
5. enumerate meaningful current FileMCP functions/subsystems into the function-upgrade inventory required by Section 6A.

Output: **FILEMCP_BASELINE_TRUTH**

No comparison may use a remembered or earlier FileMCP state.

## ROUND 1 — REPOSITORY SOURCE INTEGRITY

For R1-R6:
- pin SHA;
- record license;
- identify architecture entry points;
- distinguish source from generated/vendor code;
- identify tests;
- identify unshipped plan/roadmap areas;
- attempt a focused build/test smoke when practical.

Required result: a table proving which reference claims are source-backed.

## ROUND 2 — SYSTEM ARCHITECTURE COMPARISON

Compare client/runtime boundary, MCP/server boundary, task layer, filesystem, Git, process, sandbox/isolation, persistence, evidence, UI/browser dependencies and extension model.

Question:

> What is the smallest architecture that gives FileMCP the reliability benefits without inheriting unrelated product layers?

## ROUND 3 — SECURITY / TRUST BOUNDARY AUDIT

Compare:
- local auth;
- bearer credentials;
- public endpoints;
- origin/host restrictions;
- workspace scope;
- process authority;
- network authority;
- environment-variable authority;
- repository instructions;
- approval/policy source of truth;
- child/delegated authority;
- credential storage;
- browser trust;
- persistent secret exposure.

Mandatory adversarial questions:
- Can the model increase its own authority?
- Can repository content alter policy?
- Can a tool escape the workspace?
- Can Git configuration execute or exfiltrate unexpectedly?
- Can child agents inherit too much?
- Can stale approval be replayed?
- Can a public URL leak authority?
- Can observability become a content exfiltration database?

Result: **FILEMCP_FINAL_TRUST_MODEL_CANDIDATE**

## ROUND 4 — SANDBOX VS HOST EXECUTION

Primary references: Codex, OpenHands, FileMCP.

Compare:
- OS sandbox;
- container sandbox;
- VM/remote runtime;
- host execution with root containment;
- filesystem fidelity;
- Git credential access;
- developer-tool availability;
- build performance;
- Windows/macOS feasibility;
- setup burden;
- network controls;
- debugging;
- recovery after process crash.

Evaluate four outcomes:
- Option A: host execution only;
- Option B: host execution + strong policy;
- Option C: host execution default + optional isolated runtime;
- Option D: isolated runtime mandatory.

No option wins by ideology.

## ROUND 5 — PROCESS EXECUTION CONTRACT

Compare:
- shell-string execution;
- executable + argv;
- environment filtering;
- cwd authority;
- timeout;
- cancellation;
- process-tree cleanup;
- output bounds;
- idempotency;
- execution IDs;
- retry semantics;
- terminal state;
- interactive vs non-interactive execution.

Key decision:

> Is ADR-0004's additive exec_process model sufficient, or does FileMCP require a deeper execution registry/journal before exposing it?

Mandatory output: final exec_process contract requirements.

## ROUND 6 — FILE READ / EDIT / CONCURRENCY AUDIT

Compare:
- whole-file writes;
- exact replacement;
- range edits;
- unified diff;
- patch protocol;
- model-specific edit formats;
- expected version;
- file identity;
- atomic publish;
- metadata preservation;
- newline/BOM handling;
- concurrent writer conflict;
- copy/move/delete safety;
- dry-run;
- rollback/quarantine.

Primary references: ChatCMD, Aider, Codex, FileMCP.

Mandatory decision:

> What is the lowest-level canonical mutation primitive FileMCP should expose?

Higher-level adapters must not weaken optimistic concurrency.

## ROUND 7 — LARGE-REPOSITORY CONTEXT AUDIT

Primary reference: Aider repository map.

Also inspect Codex project/rules handling, ChatCMD project_context and Cline context mechanisms if source-backed.

Compare:
- raw file search;
- symbol graph;
- repository map;
- AST/tree-sitter indexing;
- Git-aware changed-file prioritization;
- lexical ranking;
- dependency/call relationships;
- cache invalidation;
- context token cost;
- large monorepo scaling;
- privacy/persistence.

Critical question:

> Is ADR-0004 project_context digest enough, or must FileMCP add a repository-symbol-map subsystem?

Possible outcomes:
- digest only;
- digest + on-demand symbol map;
- persistent metadata-only symbol index;
- no index until profiling.

## ROUND 8 — TOOL CATALOG / MCP CONTRACT AUDIT

Compare:
- canonical catalog generation;
- schema hashing;
- capability/risk classification;
- result schema;
- tool filtering;
- MCP extension composition;
- live connector consistency;
- build/package consistency;
- version negotiation;
- deprecation.

Primary references: ChatCMD, Goose, Codex, FileMCP.

Mandatory decision: define the **single FileMCP catalog source of truth** and how native C# + Swift runtimes prove exact compatibility.

## ROUND 9 — POLICY / APPROVAL / AUTONOMY AUDIT

Compare allow/prompt/deny, risk classes, sandbox mode, local policy files, per-operation approval, reusable grants, task policy, child policy, user settings and autonomous mode.

FileMCP UX requirement:

Routine workspace automation should not require unnecessary clicking when the user has already locally authorized the profile.

Required authority direction:

```text
USER / LOCAL CONFIGURATION
        ↓
AUTHORITY
        ↓
MODEL REQUEST
```

Never model-request → self-granted authority.

## ROUND 10 — GIT / CHECKPOINT / RECOVERY AUDIT

Primary references: Aider, Cline, ChatCMD, FileMCP.

Compare:
- dirty-worktree handling;
- AI-change isolation;
- commit boundaries;
- undo;
- checkpoints;
- branch strategy;
- restart recovery;
- incomplete task state;
- recovery after app crash/reboot;
- source-state freshness.

Critical distinction:

```text
GIT HISTORY
≠
TASK CHECKPOINT
≠
EXECUTION EVIDENCE
≠
OBSERVABILITY
```

## ROUND 11 — EVIDENCE / VERIFICATION / COMPLETION AUDIT

Compare:
- tool returned vs process success;
- work outcome;
- verification state;
- source freshness;
- execution ownership;
- stale evidence;
- restart-invalid evidence;
- artifact identity;
- criterion mapping;
- PASS semantics.

Mandatory rule:

**Terminal text containing the word PASS is never authoritative evidence.**

Required verification states:
- passed;
- failed;
- not-run;
- unknown;
- stale;
- blocked;
- not-applicable where justified.

## ROUND 12 — PERSISTENCE / PRIVACY AUDIT

Compare what each reference persists:
- tasks;
- messages;
- commands;
- arguments;
- terminal output;
- artifacts;
- Git data;
- file content;
- tool results;
- credentials;
- browser state.

Classify every proposed FileMCP store as:
- REQUIRED DURABLE;
- EPHEMERAL;
- CACHE;
- OBSERVABILITY METADATA;
- FORBIDDEN CONTENT.

No new persistent store is accepted without retention, cleanup, crash semantics, ownership, quota, redaction and migration rules.

## ROUND 13 — PTY / LONG-RUNNING PROCESS AUDIT

Compare one-shot process, background process, PTY, replay cursor, stdin handoff, resize/signals, dev servers, interactive credentials and restart semantics.

Decision: confirm whether PTY remains Phase B or must move earlier.

Default presumption:

**PTY is not the canonical build/test evidence primitive.**

## ROUND 14 — EXTENSION / MCP COMPOSITION AUDIT

Primary reference: Goose.

Compare:
- external MCP servers;
- local tools;
- capability discovery;
- extension allowlists;
- tool filtering;
- namespacing;
- conflicting tool names;
- extension trust;
- extension secrets;
- lifecycle/versioning.

Question:

> Should FileMCP become an MCP tool gateway/composer, or remain a focused local execution server that coexists with other MCP servers?

## ROUND 15 — TASK / SUB-AGENT ORCHESTRATION AUDIT

Primary references: ChatCMD, Goose, Cline/OpenHands if source-backed.

Compare:
- parent/child tasks;
- context inheritance;
- authority inheritance;
- concurrency;
- dependency graph;
- child result;
- child evidence;
- lease;
- heartbeat;
- watchdog;
- cancellation;
- restart recovery.

Mandatory rule:

A sub-agent reporting "done" or "pass" cannot directly set verified parent state.

This remains Phase C unless overwhelming evidence requires an earlier primitive.

## ROUND 16 — CROSS-PLATFORM FEASIBILITY

For every proposed common FileMCP capability define:
- Windows implementation path;
- macOS implementation path;
- OS primitive differences;
- filesystem semantics;
- path casing;
- symlink/reparse behavior;
- job object/process group behavior;
- credential storage;
- sandbox options;
- packaging;
- test runner availability.

Classify each feature:
- COMMON;
- WINDOWS-ONLY WITH EXPLICIT SCOPE;
- MACOS-ONLY WITH EXPLICIT SCOPE;
- DEFER UNTIL PARITY DESIGN EXISTS.

## ROUND 17 — PERFORMANCE / RESOURCE CONTROL

Compare:
- file scan limits;
- bytes read;
- output limits;
- process concurrency;
- file-descriptor usage;
- terminal buffers;
- index size;
- SQLite growth;
- CPU;
- memory;
- cancellation latency;
- backpressure;
- artifact quota.

Audit small, medium, large and monorepo sizes.

Every long loop must answer:
- where is cancellation checked?
- what is the hard cap?
- what can caller lower?
- what is persisted?
- what is resumable?
- how is partial output represented?

## ROUND 18 — FAILURE-INJECTION AUDIT

Required failure classes:
- app crash during write;
- process timeout/cancellation;
- child process leakage;
- output-limit exhaustion;
- stale file version;
- file changed between validation and commit;
- symlink/reparse swap;
- Git config escape attempt;
- dirty worktree;
- corrupted cache/index;
- SQLite unavailable/full;
- network/tunnel loss;
- MCP client disconnect;
- restart with in-flight evidence;
- missing executable;
- invalid/expired cursor;
- policy change during pending operation.

For each define safe terminal state, cleanup, recoverability, evidence state and diagnosis.

## ROUND 19 — CONTRADICTION MATRIX

For every major architecture topic create:

| Topic | ChatCMD | Codex | OpenHands | Aider | Cline | Goose | FileMCP today | Final FileMCP decision | Reason |
|---|---|---|---|---|---|---|---|---|---|

Required topics:
- command execution;
- shell use;
- sandboxing;
- workspace authority;
- network authority;
- approval;
- policy source;
- file editing;
- optimistic concurrency;
- rollback;
- Git handling;
- large-repo context;
- tool catalog;
- extension model;
- evidence;
- checkpoints;
- persistence;
- PTY;
- sub-agents;
- task state;
- recovery;
- observability;
- privacy;
- cross-platform strategy.

Before selecting the final FileMCP decision for each topic, update the Section 6A function/subsystem matrix so the architecture conclusion is traceable to the actual current FileMCP implementation.

Where approaches conflict, explain:
what each optimizes → what FileMCP optimizes → trade-off → chosen design → accepted failure mode → prevented failure mode.

Do not select a winner based on stars, popularity, language or aesthetics.

## ROUND 20 — INDEPENDENT RED-TEAM REVIEW

After the proposed final architecture exists, perform a fresh review that assumes it is wrong.

Try to prove:
- trust model too broad;
- persistence leaks sensitive content;
- catalog authority drifts;
- policy bypass exists;
- version tokens are insufficient;
- apply_edits can corrupt files;
- stale evidence can still pass;
- recovery can duplicate side effects;
- Git safe mode can be bypassed;
- optional sandbox is unusable;
- mandatory sandbox breaks developer workflows;
- large-repo indexing stores too much;
- PTY creates unbounded state;
- sub-agent design expands authority incorrectly;
- cross-platform parity is fake;
- migration/rollback is incomplete.

Every P0/P1 architecture blocker must be repaired or explicitly rejected before freeze.

---

# 8. COMPARISON DIMENSIONS

Every repo must be described across the same dimensions:

1. security boundary;
2. filesystem correctness;
3. Git correctness;
4. process correctness;
5. sandbox/isolation;
6. policy/approval;
7. autonomous usability;
8. recovery;
9. evidence quality;
10. persistence/privacy;
11. large-repo scalability;
12. context intelligence;
13. MCP/tool-contract quality;
14. extension composition;
15. cross-platform feasibility;
16. implementation complexity;
17. migration cost;
18. operational burden;
19. failure diagnosability;
20. testability.

No single overall winner score is allowed.

---

# 9. REQUIRED FINAL ARCHITECTURE QUESTIONS

The audit is incomplete until each has an explicit answer:

1. Does FileMCP remain host-execution-first?
2. Is an optional sandbox runtime required?
3. What is the canonical non-interactive process tool?
4. What role remains for run_command?
5. What is the canonical file version token?
6. What is the canonical mutation primitive?
7. Does FileMCP need patch adapters above apply_edits?
8. Does FileMCP need a repository symbol map/index?
9. What is the single source of truth for tool catalog/schema/capability metadata?
10. How does policy interact with catalog visibility?
11. Which authority can the model request but never self-grant?
12. What durable evidence is persisted?
13. How is evidence invalidated when source state changes?
14. What is the difference between evidence, checkpoint, task state and observability?
15. Does FileMCP need checkpoints?
16. Does FileMCP need persistent PTY?
17. Does FileMCP need a local task engine?
18. Does FileMCP need local sub-agents?
19. Should FileMCP compose external MCP servers or coexist beside them?
20. What is the Windows/macOS parity rule for every new common capability?
21. For every meaningful current FileMCP function/subsystem, is the final action KEEP, KEEP + HARDEN, ADAPT, REPLACE, ADD, DEPRECATE, REMOVE, DEFER or REJECT, and what exact source/evidence justifies it?

---

# 10. MASTER FINAL OUTPUT CONTRACT

Executing this spec must ultimately produce:

- `docs/audit/FINAL_CROSS_REPO_CODING_AGENT_ARCHITECTURE_AUDIT.md`
- `docs/design/CROSS_REPO_CAPABILITY_AND_CONTRADICTION_MATRIX.md`
- `docs/design/FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md`
- `docs/design/FINAL_SECURITY_TRUST_BOUNDARY_MODEL.md`
- `docs/design/FINAL_EXECUTION_EDITING_EVIDENCE_MODEL.md`
- `docs/design/FINAL_LARGE_REPO_CONTEXT_ARCHITECTURE.md`
- `docs/design/FINAL_RECOVERY_CHECKPOINT_TASK_STATE_MODEL.md`
- `docs/design/MASTER_FILEMCP_CODING_AGENT_GATEWAY_ARCHITECTURE_V1.md`
- suggested final ADR: `docs/adr/0005-final-coding-agent-gateway-architecture.md`
- `tasks/MASTER_FILEMCP_UPGRADE_TASK_GRAPH.md`

ADR-0005 must explicitly state whether it confirms, amends or supersedes ADR-0004.

No implementation task may exist without dependency, exact scope, acceptance, negative tests, cross-platform requirement, evidence requirement and rollback/migration notes where needed.

---

# 11. FINAL ARCHITECTURE FREEZE GATE

The final architecture may be marked **FROZEN** only when all conditions below are true:

- [ ] FileMCP exact baseline audited.
- [ ] ChatCMD source audit retained and revalidated where necessary.
- [ ] Codex deep audit complete.
- [ ] OpenHands deep audit complete.
- [ ] Aider deep audit complete.
- [ ] Cline targeted audit complete.
- [ ] Goose targeted audit complete.
- [ ] Every major claim pinned to exact source SHA.
- [ ] Docs-only/proposal claims separated from shipped code.
- [ ] Contradiction matrix complete.
- [ ] FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX complete with every meaningful current capability mapped to exact source and one final action.
- [ ] Security trust-boundary audit complete.
- [ ] Sandbox-vs-host decision complete.
- [ ] Process execution contract frozen.
- [ ] File concurrency/editing model frozen.
- [ ] Large-repo context strategy frozen.
- [ ] Catalog/schema authority frozen.
- [ ] Policy/autonomy model frozen.
- [ ] Git/checkpoint/recovery model frozen.
- [ ] Evidence/verification model frozen.
- [ ] Persistence/privacy model frozen.
- [ ] PTY decision complete.
- [ ] Sub-agent decision complete.
- [ ] Cross-platform feasibility complete.
- [ ] Performance/resource-budget review complete.
- [ ] Failure-injection review complete.
- [ ] Independent red-team review complete.
- [ ] All red-team P0/P1 architecture blockers repaired or explicitly rejected.
- [ ] ADR-0005 written.
- [ ] Master task graph written.
- [ ] No hidden feature code was introduced during the design/audit phase.

If any mandatory box is incomplete:

**DO NOT START CCI-001.**

---

# 12. IMPLEMENTATION START RULE AFTER FINAL AUDIT

After final architecture freeze:

```text
MASTER ARCHITECTURE FROZEN
        ↓
FINAL TASK GRAPH
        ↓
CLAIM FIRST ROOT TASK ONLY
        ↓
ANALYZE CURRENT SOURCE AGAIN
        ↓
PLAN
        ↓
CODE
        ↓
TEST
        ↓
EVIDENCE
        ↓
INDEPENDENT VERIFY
        ↓
COMMIT
        ↓
REVIEW
        ↓
MERGE
        ↓
MAIN VERIFIED
        ↓
NEXT READY TASK
```

Do not automatically preserve current CCI numbering if the final comparative audit changes dependencies.

---

# 13. BIAS CONTROLS

The audit must defend against:

- popularity bias;
- language bias;
- complexity bias;
- minimalism bias;
- security-theater bias;
- feature-copy bias;
- documentation bias;
- test-count bias.

A sandbox, approval dialog, container, encryption layer, large test suite or popular repository is not automatically evidence of suitability.

---

# 14. REQUIRED NEGATIVE DECISIONS

The audit must explicitly reconsider and decide:

- browser ChatGPT DOM automation;
- public tokenized MCP endpoint;
- recoverable public bearer tokens;
- broad local chat-history persistence;
- mandatory Docker runtime;
- mandatory VM runtime;
- mandatory PTY for normal commands;
- full local task manager;
- local sub-agent runtime;
- repository content indexing;
- React/IDE UI expansion;
- Rust rewrite;
- custom application-layer crypto.

Rejected capabilities must remain documented so they do not quietly return during implementation.

---

# 15. ACCEPTANCE STANDARD FOR "MASTER FINAL"

The phrase **MASTER FINAL** may only be used when the resulting architecture satisfies:

```text
SOURCE-VERIFIED
×
CROSS-REPO-COMPARED
×
SECURITY-REVIEWED
×
PRIVACY-REVIEWED
×
FAILURE-REVIEWED
×
RECOVERY-DESIGNED
×
LARGE-REPO-DESIGNED
×
WINDOWS-FEASIBLE
×
MACOS-FEASIBLE
×
MIGRATION-SAFE
×
ROLLBACK-SAFE
×
TESTABLE
×
TASK-GRAPHED
```

"Complete" does not mean FileMCP contains every feature found in every reference repository.

"Complete" means FileMCP has every primitive required by its own product goals, each primitive has a clear authority and failure model, unnecessary trust surfaces are deliberately excluded, and the implementation order is frozen with verifiable acceptance evidence.

---

# 16. FINAL AUDIT EXECUTION ORDER

```text
PHASE 0
FILEMCP BASELINE TRUTH
        ↓
PHASE 1
PIN + SOURCE-INTEGRITY ALL REPOS
        ↓
PHASE 2
CODEX DEEP AUDIT
        ↓
PHASE 3
OPENHANDS DEEP AUDIT
        ↓
PHASE 4
AIDER DEEP AUDIT
        ↓
PHASE 5
CLINE TARGETED AUDIT
        ↓
PHASE 6
GOOSE TARGETED AUDIT
        ↓
PHASE 7
REVALIDATE CHATCMD FINDINGS
        ↓
PHASE 8
CROSS-REPO CAPABILITY CARDS
        ↓
PHASE 9
SECURITY / SANDBOX / POLICY SYNTHESIS
        ↓
PHASE 10
EXECUTION / EDITING / EVIDENCE SYNTHESIS
        ↓
PHASE 11
LARGE-REPO / CONTEXT SYNTHESIS
        ↓
PHASE 12
GIT / CHECKPOINT / RECOVERY SYNTHESIS
        ↓
PHASE 13
MCP / CATALOG / EXTENSION SYNTHESIS
        ↓
PHASE 14
TASK / PTY / SUB-AGENT SYNTHESIS
        ↓
PHASE 15
CROSS-PLATFORM FEASIBILITY
        ↓
PHASE 16
PERFORMANCE / RESOURCE BUDGET
        ↓
PHASE 17
FAILURE-INJECTION REVIEW
        ↓
PHASE 18
CONTRADICTION MATRIX
        ↓
PHASE 19
PROPOSED MASTER ARCHITECTURE
        ↓
PHASE 20
INDEPENDENT RED-TEAM AUDIT
        ↓
REPAIR ALL ARCHITECTURE BLOCKERS
        ↓
FINAL RE-AUDIT
        ↓
ADR-0005
        ↓
MASTER TASK GRAPH
        ↓
MASTER FINAL ARCHITECTURE FROZEN
        ↓
ONLY THEN: IMPLEMENTATION
```

---

# 17. STOP / ESCALATION CONDITIONS

Stop the affected decision and record a blocker rather than invent certainty when:

- source repository is unavailable;
- exact commit cannot be pinned;
- a key subsystem is closed-source or generated without inspectable implementation;
- test requires unavailable credentials/hardware;
- documentation contradicts source and behavior cannot be resolved;
- an external project changes materially during the audit;
- FileMCP main changes enough that mapping is stale;
- proposed architecture violates AGENTS.md security/privacy law;
- cross-platform feasibility is unknown for a mandatory common capability.

Blocker format:

```text
BLOCKER_ID
affected decision
known evidence
missing evidence
why guessing is unsafe
exact next evidence action
whether the rest of the audit can continue
```

---

# 18. FINAL RULE

The final comparative audit is successful even if it results in **fewer** features than ADR-0004.

The goal is not:

> make FileMCP look like ChatCMD + Codex + OpenHands + Aider + Cline + Goose.

The goal is:

> use those systems as adversarial references to determine the smallest, strongest, safest and most verifiable architecture for FileMCP itself.

Until this specification has been executed through the final independent red-team and re-audit gates:

**ADR-0004 is a strong baseline, not the final master architecture.**
