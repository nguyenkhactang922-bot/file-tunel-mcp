# FMG-011 Metadata-Only Evidence and Freshness - Frozen Design

Date: 2026-09-26
Status: FROZEN FOR CURRENT IMPLEMENTATION
Depends: FMG-002, FMG-003, FMG-006, FMG-010 - MAIN VERIFIED

## Authority

Evidence is server-owned metadata, never task/transcript storage.
Terminal text containing PASS has zero verification authority.
Raw prompts, chat, tool args, commands, stdout/stderr, file contents, Git messages and secrets are forbidden from durable evidence.
Evidence persistence is physically/logically separate from telemetry.
Storage failure can never create a false passed record.

## Request facade

Evidence request uses reserved MCP metadata key io.filemcp/evidence, stripped before strict tool validation.

Supported server-known criteria:
- tool.success: proves only that the FileMCP tool call completed without tool error.
- process.exit_zero: exec_process only; proves structured process exit code zero, not stdout semantics.

Metadata fields:
- criterionId
- repoPath, optional source freshness scope
- relevantPaths, optional bounded repo-relative scope
- required, default false; added before integration completion

Caller cannot invent arbitrary verification state.

## Operation identity

ToolResultEnvelope creates the operation ID before dispatch when evidence is requested.
The exact same operation ID is attached to result envelope and durable evidence.

Evidence ID is an opaque server-generated ID independent of command/path/content.

## Freshness

When repoPath is supplied, FileMCP persists metadata-only SourceStateRef plus project-context digest.

process.exit_zero:
- capture source/context before launch and after completion;
- source/context mismatch during execution cannot pass.

tool.success:
- capture the post-operation source/context because successful mutation tools intentionally change source.

evidence_get recomputes source/context using stored bounded scope.
Equal dependency state preserves passed/failed.
Successful mismatch returns stale.
Recompute failure returns unknown.

Freshness also binds:
- canonical catalog hash/version;
- policy generation/hash;
- project-context digest when repository scope exists.

## Verification states

Supported states:
passed, failed, not-run, unknown, stale, blocked, not-applicable.

Process timeout/cancel/ambiguity is unknown.
Policy revoked before side effect is blocked.
Required evidence unavailable before launch is not-run/blocked and process does not start.

Stdout/stderr never changes verification state.

## Durable storage contract

Common semantic limits:
- 30 day retention;
- hard record-count quota;
- hard storage-size quota;
- restart conversion of unfinished running records to unknown;
- terminal passed/failed is authoritative only after durable terminal write;
- evidence failure never blocks ordinary tools unless required=true.

Windows implementation:
- separate evidence-v1.sqlite3;
- reuse existing Microsoft.Data.Sqlite dependency;
- WAL with bounded page/journal settings;
- no telemetry tables.

macOS implementation:
- separate bounded atomic JSON metadata snapshot under Application Support;
- no new SQLite dependency;
- atomic replacement and bounded record/file size.

Storage engine is platform-private; MCP evidence semantics are identical.

## Persisted metadata allowlist

Allowed:
schema version, evidence ID, operation ID, workspace fingerprint, tool name/class, criterion ID, timestamps, operation/verification state, backend class, repo-relative scope metadata, SourceStateRef metadata/digest, project-context digest, policy generation/hash, catalog hash/version, exit/timed-out/cancelled/truncation metadata.

Forbidden:
executable/argv/environment, absolute cwd, stdout/stderr, raw command, prompt/chat, source bytes, Git message, credentials, auth/correlation handles.

## Catalog/API

Canonical catalog will expose read-only evidence_get.
exec_process/tool calls request evidence through reserved metadata rather than duplicating evidence fields in every tool input schema.
Tool/result schema parity remains mandatory on Windows/macOS.

## Acceptance

Required adversarial tests:
- stdout PASS plus nonzero process exit is failed;
- exit zero authority comes only from structured terminal result;
- source/context change causes stale;
- unrelated narrow-scope change remains fresh;
- policy/catalog/context change causes stale;
- required=false storage failure executes but returns unknown/unavailable;
- required=true storage failure prevents launch;
- terminal persistence failure never returns passed;
- crash/restart running record becomes unknown;
- retention/quota/size pressure;
- corrupt/truncated persistence;
- durable secret/privacy scan;
- unknown/tampered evidence ID;
- exact cross-platform state/schema behavior.

Native Verify macOS, Windows x64 and Windows ARM64 must all pass before merge.