# FMG-019 Repository Intelligence Query Facade Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING

Branch: `chatgpt/FMG-019-repository-intelligence-query-facade`

## Public surface

Catalog version: `1.10.0`
Canonical tools: 34
Catalog SHA-256: `a11c9512d6b182c13ad760709b99ff9224a702cb477953409e831d7d4e21289d`

New low-risk read-only tools:
- `repo_map`
- `symbol_search`
- `related_files`

All three are `local_tools`, `effect=read`, `filesystem.read`, closed-world, non-destructive, and explicitly return `grants_authority=false` plus `raw_source_persisted=false`.

## Query semantics

PASS locally:
- `repo_map` returns deterministic bounded file metadata pages over the FMG-018 SourceStateRef-bound generation;
- authenticated cursor binds tool/options/workspace/generation and resumes exact position;
- changing `allow_content_ref` does not invalidate the same logical map cursor;
- oversized full maps may spill only to authenticated `TOOL_OUTPUT` ContentRef;
- spill artifact is metadata-only and excludes raw source;
- artifact unavailability is reported explicitly without inventing a ContentRef;
- stale generation is rechecked immediately before return and after artifact publish;
- stale artifact is deleted if generation changes after publish;
- `symbol_search` ranks exact -> prefix -> substring deterministically and reports ambiguity instead of choosing implicitly;
- unsupported/no-symbol provider state is explicit;
- `related_files` reports deterministic incoming/outgoing ranked relations and rejects traversal paths;
- ToolBudget output bounds are enforced on large maps.

## Cursor hardening discovered during full regression

Full regression exposed a Base64URL canonicalization edge case: a 32-byte HMAC signature can have non-canonical final-character aliases that decode to identical bytes because of padding bits.

Fixed cross-platform:
- Windows `AuthenticatedCursorCodec` now rejects non-canonical payload encoding and non-canonical signature encoding before/at authentication;
- macOS `AuthenticatedCursorCodec` has equivalent checks;
- deterministic regression tests construct a non-canonical signature alias and require rejection.

## Windows local verification

PASS:
- `tests/test_repository_intelligence_query_contract.ps1`;
- repository-intelligence predecessor contract after FMG-019 compatibility update;
- canonical catalog contract;
- cross-platform tool-surface parity;
- SourceStateRef/project-context/apply_edits/edit-adapter/batch/quarantine/mutation/exec/evidence contracts;
- Release build: 0 warnings / 0 errors;
- FMG-019 isolation: `windows-repo-query-only-tests: ok (18 assertions)`;
- full Windows regression: `windows-core-tests: ok (876 assertions)`;
- `git diff --check`.

## macOS implementation / verification state

Implemented and wired:
- `macos/RepositoryIntelligenceQuery.swift`;
- LocalTools dispatch + budget surface for all three query tools;
- same authenticated cursor, SourceStateRef freshness and metadata-only ContentRef semantics;
- app build list, static Verify list and both native Swift runtime compile lists include `RepositoryIntelligenceQuery.swift`;
- native Swift acceptance covers pagination, cursor tamper/stale, ambiguity, no-symbol support, related traversal, stale-during-query, ContentRef metadata-only delivery, unavailable artifact and ToolBudget;
- canonical Base64URL cursor alias regression coverage is present.

Native Swift compile/runtime proof is pending GitHub macOS Verify because the local Windows host has no usable macOS Swift toolchain.

## Remaining gate

1. commit local-verified FMG-019 candidate;
2. sync latest verified `fork/main`;
3. rerun affected local gates only if sync changes the candidate;
4. push exact synchronized head;
5. require native Verify on macOS + Windows x64 + native Windows ARM64;
6. scoped review;
7. PR/merge;
8. merged-main Verify;
9. mark FMG-019 DONE / MAIN VERIFIED and claim FMG-020.

## Exact-head native verification / scoped review

Candidate: `fbdb9d5eb36e1b0a90aab64234c2ff7f12c83753`.
Native Verify: run `36544068228` SUCCESS on macOS / Windows x64 / native Windows ARM64.

Scoped review PASS:
- all three FMG-019 tools remain low-risk read-only `filesystem.read` tools with closed-world annotations;
- none enters the serialized mutation lane or grants authority;
- outputs preserve provider/version/completeness/parser profile and `grants_authority=false` / `raw_source_persisted=false`;
- deterministic ranking/page order is explicit and authenticated cursors bind tool/options/workspace/SourceStateRef generation;
- `allow_content_ref` is delivery preference only and does not change logical cursor identity;
- SourceStateRef is rechecked immediately before return and again after ContentRef publish;
- a newly published stale artifact is deleted before the stale-generation error is returned;
- ContentRef uses existing authenticated `TOOL_OUTPUT` store/quota/TTL semantics and contains metadata only;
- Windows full regression PASS 876 assertions; native macOS integration/build PASS on exact head;
- cursor codec now rejects non-canonical Base64URL aliases cross-platform.

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / EVIDENCE-ONLY CLOSURE VERIFY PENDING.

## PR Verify attempt 1 remediation

PR #38 Verify run `36545273004` on closure head `0bfa1017cbbee064d5343c19cfab5141e531bb30`:
- Windows x64 SUCCESS;
- native Windows ARM64 SUCCESS;
- macOS static/catalog SUCCESS;
- macOS integration failed only at pre-listener fixture readiness: ports `18088..18091` were not ready before the 45-second harness watchdog.

The same product head already passed macOS native integration in push Verify runs `36544068228` and `36544798050`. The failure occurred after FMG-018/FMG-019 native fixtures had progressed through repository-query setup, before HTTP listener tests began.

Remediation is test-harness only: extend the pre-listener readiness watchdog from 45s to 90s and document that this bound covers loaded CI startup for FMG-018 indexing + FMG-019 large-map/query fixtures. Product timeouts, query semantics, authority, catalog, SourceStateRef and ContentRef behavior are unchanged.

NEXT_EXACT_ACTION: commit/push this test-only remediation, require exact-head Verify on macOS + Windows x64 + native Windows ARM64 (including PR checks), then merge PR #38 only on the exact remediated head and require merged-main Verify.
