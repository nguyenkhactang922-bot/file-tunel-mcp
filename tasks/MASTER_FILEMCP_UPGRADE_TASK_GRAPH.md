# MASTER FileMCP Upgrade Task Graph

Status: FROZEN IMPLEMENTATION PLAN — NO FEATURE CODE YET
Date: 2026-09-23
Architecture authority: docs/adr/0005-final-coding-agent-gateway-architecture.md
Function authority: docs/design/FINAL_FILEMCP_FUNCTION_UPGRADE_MATRIX.md

## Global task law

Every task follows:

CLAIM -> ANALYZE exact current source -> PLAN -> CODE -> TEST -> EVIDENCE -> independent VERIFY -> COMMIT -> REVIEW -> MERGE -> MAIN VERIFIED -> next READY task.

Before claim:
- exact git root/branch/HEAD/status;
- AGENTS.md;
- ADR-0005;
- current handoff/state;
- this graph.

No task may silently redesign ADR-0005. Architecture changes require a new review/ADR round.

## Dependency graph

```text
FMG-001 Canonical Catalog Authority
   |\
   | +----------------------+
   v                        v
FMG-002 Result Envelope   FMG-003 Policy + Migration
   |\                       |\
   | +--------+              | +-------------------+
   v          v              v                     |
FMG-004   FMG-006       FMG-005                FMG-010
Budgets   Source/File    exec_process           Project Context
/Cursors  Identity          |                      |
   |          |             |                      |
   |          v             |                      |
   |      FMG-007           |                      |
   |      Mutation Guard    |                      |
   |          |             |                      |
   |          v             |                      |
   |      FMG-008           |                      |
   |      Current Mutation  |                      |
   |      Hardening         |                      |
   |          |             |                      |
   +----------+-----> FMG-009 apply_edits         |
                      |                            |
                      +-------------+--------------+
                                    v
                               FMG-011
                         Evidence / Freshness
                                    |
                                    v
                               FMG-012
                    Cross-platform Adversarial Gate
                                    |
                                    v
                               FMG-013
                  Full Regression + Live MCP Proof
                                    |
                                    v
                         PHASE A MAIN VERIFIED
```

FMG-003 policy is required by FMG-005 exec authority and FMG-011 evidence generation metadata.
FMG-006 Source/File Identity is required by FMG-007 and FMG-011.
FMG-004 budget primitives are required by FMG-009 and FMG-010.

## FMG-001 — Canonical Catalog Authority

State: READY ROOT TASK
Depends: ADR-0005

Scope:
- create canonical catalog artifact;
- protocol/catalog/instruction versioning/hash;
- risk/effect/capability metadata;
- exact Windows/macOS runtime validation;
- handler coverage validation;
- live/package catalog hash exposure.

Do not:
- change active authority semantics yet;
- make descriptions authoritative.

Acceptance:
- one authoritative catalog artifact;
- every advertised tool exactly represented;
- every intended handler exactly mapped;
- Windows/macOS canonical hashes equal;
- schema drift test fails closed;
- packaged/native/live catalog proof PASS.

Negative tests:
- missing handler;
- extra runtime tool;
- schema mismatch;
- metadata mismatch;
- malformed catalog;
- stale catalog version.

Evidence:
- catalog fixture;
- parity output;
- Windows/macOS Verify;
- live MCP tools/list/catalog proof.

## FMG-002 — Structured Result Envelope

State: BLOCKED
Depends: FMG-001

Scope:
- versioned result metadata contract;
- status/warnings/truncation/usage/operation identity primitives;
- compatibility with existing text content.

Acceptance:
- existing clients retain usable content;
- structured schema identical across platforms;
- errors distinguish transport/tool/result state.

Negative tests:
- malformed result;
- truncation;
- partial output;
- unknown status/schema version.

## FMG-003 — Server-Owned Policy + Migration

State: BLOCKED
Depends: FMG-001

Scope:
- restricted/workspace-auto/custom;
- migration-only legacy-command-compatible;
- map legacy EnableCommands state;
- policy generation/hash;
- risk/effect authorization;
- effective catalog filtering;
- runtime reauthorization.

Acceptance:
- false -> restricted-equivalent;
- true -> legacy-command-compatible;
- workspace-auto only explicit local choice;
- model/repo cannot elevate;
- hidden tool cannot bypass runtime denial;
- policy generation changes invalidate prepared side effects.

Negative tests:
- self-elevation attempt;
- repository instruction authority attempt;
- stale prepared operation after policy reduction;
- catalog says allowed but policy denies;
- migration regression.

## FMG-004 — ToolBudget / Cancellation / Cursor Core

State: BLOCKED
Depends: FMG-002

Scope:
- common budget schema;
- hard caps + caller-lower-only semantics;
- cooperative cancellation;
- usage/truncation metadata;
- authenticated cursor core.

Acceptance:
- long loops stop within bounded cancellation latency;
- caller cannot raise server cap;
- cursor binds tool/options/root/generation/position;
- cursor expiry/tamper fail closed;
- restart invalidation documented/tested.

Negative tests:
- oversized budget;
- tampered cursor;
- options mismatch;
- stale root/policy generation;
- cancellation mid-scan.

## FMG-005 — Structured exec_process + Environment Authority

State: BLOCKED
Depends: FMG-002, FMG-003, FMG-004

Scope:
- MCP exec_process;
- executable + argv;
- contained cwd;
- minimal platform environment baseline;
- locally configured pass-through;
- policy-checked request overrides;
- timeout/output budget;
- structured result;
- existing native runners reused.

KEEP:
- run_command compatibility path.

Acceptance:
- no implicit shell interpolation;
- secret-like host env not implicitly forwarded;
- ProcessRunner cleanup preserved;
- Windows/macOS result equivalence;
- run_command behavior documented high-risk.

Negative tests:
- NUL/invalid argv;
- cwd escape;
- forbidden env override;
- timeout;
- cancellation;
- child leakage;
- output exhaustion;
- nonzero exit vs MCP transport success.

## FMG-006 — Strong File Version + SourceStateRef

State: BLOCKED
Depends: FMG-001, FMG-002

Scope:
- strong opaque/authenticated file version identity;
- read/stat exposure;
- SourceStateRef provider/version;
- Git-backed repository fingerprint components;
- narrow relevant-file dependency support.

Acceptance:
- stale file change detected;
- target replacement detected;
- evidence state provider does not persist raw source/diff;
- Git dirty/untracked scoped changes can invalidate relevant evidence;
- source-state algorithm is versioned.

Negative tests:
- same size/mtime but changed content;
- replacement object;
- dirty tracked change;
- relevant untracked change;
- unrelated narrow-scope change does not falsely invalidate where scope excludes it.

## FMG-007 — AuthorizedPathSnapshot / Mutation Guard

State: BLOCKED
Depends: FMG-006

Scope:
- stable root/parent/target identity snapshot;
- new-target parent + expected leaf state;
- final no-follow/reparse-safe recheck;
- Windows/macOS native identity implementations.

Acceptance:
- path string equality alone cannot satisfy guard;
- ancestor/target swap rejected;
- unsupported ambiguity fails closed;
- equivalent security semantics across OSes.

Negative tests:
- symlink/junction swap;
- parent replacement;
- target replacement;
- new-file leaf inserted before commit;
- root authority change.

## FMG-008 — Harden Existing write/delete Mutations

State: BLOCKED
Depends: FMG-007, FMG-003

Scope:
- expected-version support;
- Mutation Guard integration;
- current write_file/delete_file/delete_directory compatibility;
- destructive policy classes;
- dry-run where architecture requires.

Acceptance:
- stale overwrite/delete rejected;
- original remains safe before commit;
- root protections preserved;
- backward compatibility explicitly tested.

Negative tests:
- stale token;
- path swap;
- cancellation before commit;
- delete race;
- policy removal before commit.

## FMG-009 — Atomic Versioned apply_edits

State: BLOCKED
Depends: FMG-004, FMG-008

Scope:
- canonical range-edit primitive;
- expected strong version;
- coordinate system;
- non-overlap validation;
- BOM/newline preservation;
- dry-run;
- staging + final version/Mutation Guard;
- atomic publish.

Acceptance:
- no partial target mutation before final publish;
- cancellation pre-commit leaves original;
- cancellation after committed publish reports committed result;
- Windows/macOS parity.

Negative tests:
- overlapping edits;
- stale token;
- huge edit/budget exhaustion;
- external writer;
- path swap;
- staging failure;
- publish failure;
- cancellation at every stage.

## FMG-010 — Project Context Provenance / Digest

State: BLOCKED
Depends: FMG-001, FMG-004, FMG-006

Scope:
- bounded instruction discovery;
- ordered provenance/scope;
- digest/schema version;
- range continuation;
- no-authority marker;
- skill integration without duplicate recipe engine.

Acceptance:
- deterministic ordered provenance;
- context digest changes on relevant instruction change;
- repository context never grants policy;
- bounded reads/cancellation.

Negative tests:
- oversized instruction file;
- nested conflicting rules;
- malicious rule requesting authority;
- stale range/version;
- path escape.

## FMG-011 — Metadata-Only Evidence / Freshness

State: BLOCKED
Depends: FMG-002, FMG-003, FMG-006, FMG-010

Scope:
- evidence identity/state;
- SourceStateRef linkage;
- policy/catalog generation;
- passed/failed/not-run/unknown/stale/blocked/N/A;
- retention/quota/cleanup;
- restart handling;
- logical separation from telemetry.

Acceptance:
- stdout PASS alone never marks verification;
- source change makes scoped evidence stale;
- storage failure cannot create false pass;
- raw prompt/command/tool args/file/Git messages/secrets absent;
- incomplete crash state becomes unknown/aborted as appropriate.

Negative tests:
- stale source;
- policy/catalog generation change;
- DB unavailable/full;
- process crash during evidence;
- secret/redaction scan;
- retention cleanup.

## FMG-012 — Cross-Platform Adversarial Contract Gate

State: BLOCKED
Depends: FMG-001 through FMG-011

Scope:
- exact contract parity;
- Windows/macOS failure semantics;
- security adversarial suite;
- packaging/native verification.

Acceptance:
- catalog/schema hashes parity;
- all Phase A negative suites PASS;
- no one-platform-only common feature;
- Release build 0 warnings/errors;
- native macOS/x64/ARM64 verification.

## FMG-013 — Full Regression + Live MCP Proof

State: BLOCKED
Depends: FMG-012

Scope:
- entire existing runtime regression;
- packaged smoke;
- live Secure MCP Tunnel/MCP discovery;
- structured exec live proof;
- version/mutation/evidence live proof;
- state/evidence documentation.

Acceptance:
- existing verified behavior not regressed;
- live catalog exact hash;
- real tool calls prove structured contracts;
- MAIN VERIFIED after review/merge;
- state/handoff/task graph updated.

No fake PASS from local unit tests alone.

## Phase B candidate graph — NOT ACTIVE

Not implementation-authorized by this queue:
- optional isolated execution backend;
- repository intelligence / symbol map;
- persistent PTY;
- checkpoint/restore;
- artifact spillover;
- durable command idempotency registry.

Each requires its own activation/design gate or focused ADR/profile benchmark as defined by ADR-0005.

## Explicitly excluded from task graph

No tasks for:
- browser DOM automation;
- public bearer-token endpoint;
- external MCP provider hosting;
- local general task manager;
- local sub-agent runtime;
- broad transcript/content persistence;
- language rewrite.

## Implementation start gate

Architecture is frozen by ADR-0005.

Implementation may start only after:
- this graph is committed/reviewed;
- CURRENT_HANDOFF/PROJECT_STATE name FMG-001 as the future-program NEXT_EXACT_ACTION without overwriting the unrelated V11-009 upstream authority gate;
- work occurs on a dedicated implementation branch;
- FMG-001 is claimed alone.

Until then: DO NOT CODE.
