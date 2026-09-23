# FINAL Execution, Editing and Evidence Model

Status: FROZEN BY ADR-0005
Date: 2026-09-23

## 1. Structured execution

### Canonical deterministic primitive

Add `exec_process`:

Input contract:
- executable;
- arguments[];
- cwd inside authorized root;
- explicit bounded environment overrides;
- timeout;
- output budget;
- optional future backend selector only when a second backend is approved.

No implicit shell interpolation.

Output contract:
- operationId / executionId;
- terminalState;
- exitCode;
- timedOut;
- cancelled;
- stdout/stderr bounded payload;
- truncation state/omitted-byte metadata;
- timestamps/duration;
- backend class identifier;
- warnings;
- evidence/source-state linkage where requested.

Tool-call transport success does not imply process success.

### Existing shell primitive

KEEP `run_command`:
- shell compatibility;
- explicitly classified high-risk/open-world;
- not preferred for deterministic build/test invocation;
- does not become authoritative verification merely because output contains PASS.

### Native runners

KEEP Windows/macOS ProcessRunner implementations:
- executable + argv already native;
- bounded output;
- timeout/cancel;
- process tree/group cleanup.

HARDEN:
- shared structured result;
- sanitized environment baseline;
- evidence identity.

### Idempotency

DEFER durable idempotency registry.

An idempotency key cannot make an arbitrary side-effecting command safe to replay. Add registry only when retry semantics and operation classes are explicitly designed.

## 2. File identity

Add strong opaque/authenticated version identity.

For mutation correctness the token must bind enough state to detect:
- target replacement;
- content change;
- identity/path mismatch;
- stale read.

Metadata-only identity may exist for cache/read hints but is not sufficient as the sole strong mutation precondition.

Cross-platform token encoding may be common while native identity acquisition differs.

## 3. Mutation Guard

Every destructive or content-replacing mutation reaches a final gate:

```text
policy still allows
AND expected strong version matches
AND canonical/no-follow path identity still authorized
AND ancestor/target identity has not been swapped
THEN commit
```

This guard applies to:
- write/overwrite;
- apply_edits;
- delete file;
- recursive delete;
- future move/copy/quarantine operations.

## 4. Atomic apply_edits

Add canonical low-level `apply_edits`:
- expectedVersion required for existing file;
- coordinate system explicitly defined;
- edits must be non-overlapping;
- dryRun supported;
- preserve BOM/newline behavior explicitly;
- stage complete result outside target;
- recheck version + Mutation Guard;
- atomic publish;
- cleanup staging on pre-commit failure.

Cancellation semantics:
- cancelled before commit: original remains unchanged;
- cancellation arriving after successful atomic publish: report committed success with cancellation-after-commit warning/state, never false rollback.

## 5. Higher-level edit adapters

DEFER:
- search/replace adapter;
- unified diff adapter;
- model-specific patch format.

If later added, each compiles to the same versioned `apply_edits` authority. No adapter bypasses expected-version/Mutation Guard.

## 6. Shared ToolBudget

Introduce a common budget contract:
- hard server cap;
- caller may only lower;
- timeout;
- bytes read/written;
- entries/files scanned;
- metadata calls;
- output bytes;
- open files/processes where applicable.

Long traversal/read loops check cancellation/budget cooperatively.

## 7. Cursor contract

Where continuation is needed, cursor is opaque/authenticated and binds:
- workspace/root identity;
- tool/query/options;
- generation/freshness state;
- position;
- expiration/schema version.

Tamper, option mismatch or stale generation fails closed.

## 8. Evidence model

Evidence is server-owned operation metadata, not transcript storage.

Verification states:
- passed;
- failed;
- not-run;
- unknown;
- stale;
- blocked;
- not-applicable.

Evidence may bind:
- operation ID;
- source/workspace digest;
- executable/tool class;
- result state;
- artifact hash/metadata;
- criterion ID.

Evidence becomes stale when the source state it proves no longer matches the current required state.

The string PASS in stdout has zero authority by itself.

## 9. Evidence persistence

If durable:
- bounded retention;
- bounded quota;
- cleanup/compaction;
- schema version/migration;
- restart-safe incomplete state handling;
- no raw command/tool args/file content/prompt/Git message.

A crashed in-flight operation reopens as unknown/aborted unless durable terminal evidence proves otherwise.

## 10. Git results

Existing Git safe mode remains.

Git tool outcomes may emit structured result/evidence metadata, but FileMCP does not automatically commit as a task-orchestration side effect.

## 11. Failure injection acceptance

Must test:
- timeout/cancel;
- child leak;
- output truncation;
- unsafe environment override;
- stale file token;
- concurrent writer;
- path swap/junction/symlink swap;
- cancellation at each edit stage;
- atomic publish failure;
- policy change during prepared operation;
- cursor tamper/staleness;
- evidence freshness invalidation;
- restart with in-flight evidence.

## 12. Backend isolation seam

Phase A result schema may include backend identity, but no generic backend framework is required before a second backend is approved.

A future isolated backend must reuse the same external exec/evidence semantics and receive a separate ADR.
## 13. Red-team precision amendments

### SourceStateRef

Evidence dependencies are explicit and versioned. Repository-wide evidence may bind canonical worktree identity, HEAD OID, index/tree identity, dirty tracked fingerprint, scoped untracked fingerprint, catalog hash and policy generation. Narrow evidence may instead bind only relevant file version refs and artifact identity. Freshness is recomputed with the same provider/version. Raw source/diff content is not persisted.

### AuthorizedPathSnapshot

Mutation Guard captures stable object identity. Existing target: parent/ancestor + target identity. New target: parent identity + expected leaf state. Immediately before publish/delete, no-follow/native identity is rechecked. A path string match without object identity is insufficient.

### exec_process environment

Default arbitrary host-env inheritance is false. A minimal platform baseline is server supplied; local config defines additional allowed pass-through names/patterns; request overrides are bounded and policy checked. Secret-like environment variables are not implicitly forwarded.

### run_command compatibility

Existing run_command environment semantics may remain during migration to avoid silent breakage. It is tagged high-risk/open-world. Any future tightening requires compatibility evidence and explicit migration.

### Cursor and policy generation

Cursor binds tool/options/root/generation/position and expires. Prepared side effects capture policy generation and reauthorize before commit/exec.
