# FMG-011 - Metadata-Only Evidence / Freshness Candidate Evidence

Date: 2026-09-27
Status: LOCAL VERIFIED / NATIVE CI PENDING
Branch: `chatgpt/FMG-011-metadata-evidence`

## Frozen authority

- `docs/design/FMG-011_METADATA_EVIDENCE_FRESHNESS_FROZEN.md`
- `docs/design/FMG-011_INDEPENDENT_REVIEW.md`
- `docs/design/FMG-011_DECISION_MATRIX.md`
- `tasks/FMG-011_TASK_GRAPH.md`

## Implemented

### Protocol / identity

- Reserved MCP metadata key: `io.filemcp/evidence`.
- Supported server-owned criteria:
  - `tool.success`
  - `process.exit_zero`
- Opaque server-generated evidence IDs: `ev_<32 lowercase hex>`.
- Tool result envelope operation ID is generated before dispatch and shared exactly with evidence metadata.
- Caller cannot provide verification state.

### Windows durable store

- Separate `evidence-v1.sqlite3` store; no telemetry tables.
- WAL + bounded record count + bounded store size + 30-day retention.
- Startup recovery converts unfinished `running` evidence to `unknown`.
- Terminal authoritative state exists only after durable terminal write.
- Durable write failure downgrades passed/failed/stale to unknown.
- Corrupt persistence fails closed.

### macOS durable store

- Separate bounded atomic JSON snapshot under FileMCP Application Support.
- Same evidence IDs/states/criteria semantics.
- Same 30-day retention / 10k record / 32 MiB defaults.
- Restart converts running records to unknown.
- Corrupt snapshot remains unavailable instead of silently resetting.

### Freshness

Evidence binds metadata-only:
- SourceStateRef identity;
- project-context digest;
- policy generation/hash;
- canonical catalog hash/version.

`process.exit_zero` captures pre/post source/context when scoped to a repo. A change during execution cannot pass.

`evidence_get` recomputes transient source/context scope:
- equal -> current;
- relevant source/context change -> stale;
- recompute failure -> unknown;
- policy/catalog change -> stale.

### Required mode

- `required=false`: evidence-store failure does not block the tool; metadata reports unavailable/unknown.
- `required=true`: unavailable evidence/freshness prerequisite blocks before tool/process dispatch and returns not-run/blocked.

### Privacy

Durable evidence intentionally excludes:
- prompts/chat;
- raw tool arguments;
- executable/argv/environment;
- raw command;
- stdout/stderr;
- file contents;
- Git messages;
- credentials/tokens/correlation handles.

Only bounded metadata identities/state are durable.

## Adversarial verification

Windows dedicated FMG-011 suite proves:
- stdout text containing PASS + nonzero exit => failed;
- structured zero exit => passed;
- timeout => unknown;
- restart running => unknown;
- retention;
- terminal-record quota and active-record exhaustion behavior;
- hard storage quota;
- SourceStateRef metadata bound;
- corrupt persistence rejection;
- malformed/tampered evidence ID rejection;
- narrow unrelated source change remains fresh;
- relevant source change becomes stale;
- policy change becomes stale;
- catalog mismatch becomes stale;
- result-envelope/evidence exact operation-ID sharing;
- `evidence_get`;
- required false/true storage-failure behavior;
- terminal persistence failure never returns passed;
- durable store excludes stdout/argv privacy sentinel.

macOS native harness now contains matching store/server tests:
- false-PASS authority;
- restart/retention/quota/corrupt/tampered ID;
- operation-ID sharing;
- `evidence_get`;
- durable privacy sentinel scan;
- narrow fresh -> relevant stale;
- required=false executes/unavailable;
- required=true blocked before launch.

## Local gates

```text
tool-catalog-contract: PASS
canonical tools: 23
catalog sha256: 8c5365afc0ae89e417c144ba77bbdc6a068e3fdbeefd92d674a62e1647c69d91

tool-surface-parity: PASS
exec-process-contract: PASS
file-version-source-state-contract: PASS
project-context-contract: PASS
metadata-evidence-contract: PASS
Git Bash syntax check: PASS
git diff --check: PASS

Windows Release build -warnaserror:
PASS - 0 warnings / 0 errors

Windows runtime:
PASS - windows-evidence-freshness: ok
PASS - windows-core-tests: 750 assertions
```

## Scoped privacy/security review

- no telemetry-table coupling in evidence stores;
- no raw stdout/stderr/command/prompt/credential durable fields;
- no tracked private-key/token pattern found by scoped scan;
- evidence metadata does not grant filesystem/Git/command authority;
- `evidence_get` is read-only and workspace-fingerprint scoped.

## Remaining acceptance

FMG-011-H remains pending until the exact committed candidate has native GitHub Verify SUCCESS on:
- macOS;
- Windows x64;
- Windows ARM64.

After native green:
- perform exact-head scoped review;
- merge by PR;
- run merged-main Verify;
- mark FMG-011 DONE / MAIN VERIFIED;
- only then claim FMG-012.

## Final closure

- Final candidate: `54270a86e03ebcdb86d01954d791065d5abdf1bc`.
- PR: #17.
- Merge main: `ddc8b27839469dcc5a6ff36bb531cf0b3dda87aa`.
- Merged-main native Verify: run `36296831946` SUCCESS on macOS / Windows x64 / Windows ARM64.
- FMG-011: DONE / MAIN VERIFIED.
