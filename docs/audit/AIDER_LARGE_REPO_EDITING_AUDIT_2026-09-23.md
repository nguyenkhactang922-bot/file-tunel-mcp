# Aider Large-Repository Context and Editing Audit for FileMCP

Status: INDEPENDENT SOURCE AUDIT COMPLETE
Date: 2026-09-23
Repository: https://github.com/Aider-AI/aider
Pinned commit: 5dc9490bb35f9729ef2c95d00a19ccd30c26339c
Audit clone: D:\Tools\_audit\Aider
Purpose: challenge ADR-0004 on project context, large-repository navigation, edit protocols and Git workflow.

## Finding A1 - repository map is a real source-backed context subsystem

Source evidence:
`aider/repomap.py` contains `RepoMap` with:
- tree-sitter queries for symbol definition/reference tags;
- syntax-aware fallback token/name extraction;
- a disk-backed tag cache;
- cache invalidation based on file modification time;
- ranking/personalization over file/symbol relationships;
- token-budget-aware rendering;
- in-memory map/tree-context caches.

Tests/source evidence:
- `tests/basic/test_repomap.py`;
- fixtures and callers exercise `RepoMap.get_repo_map`, map-token behavior and map enable/disable cases.

FileMCP implication:
Current `search_content` and `search_filenames` are safe locators but do not provide structural repository intelligence. For large codebases, an **on-demand symbol/repository map** is a legitimate missing capability.

However, Aider's goal is prompt-context construction inside an agent. FileMCP is an execution gateway. Therefore FileMCP should expose structural metadata as a tool/service and let ChatGPT decide when to use it; it should not silently inject maps into every request.

## Finding A2 - metadata cache can remain separate from observability

Aider caches symbol/tag data in a dedicated cache rather than treating it as telemetry.

FileMCP impact:
If FileMCP adds a repository map:
- cache is a performance cache, not evidence or observability;
- cache must store structural metadata only by default, not raw full source;
- cache version/invalidation must be explicit;
- corruption must be recoverable by deletion/rebuild;
- cache must respect shared-root containment and ignored directories;
- resource budgets/cancellation must exist before large-repo indexing ships.

## Finding A3 - multiple model-facing edit formats are useful above, not below, the filesystem contract

Source evidence:
Aider ships multiple coder/edit strategies, including:
- search/replace edit blocks (`editblock_coder.py`);
- patch format (`patch_coder.py`);
- unified-diff style paths;
- whole-file editing.

Tests exist for edit block, unified diff and whole-file behavior under `tests/basic/`.

These formats optimize model reliability. They are not a substitute for a safe storage primitive.

FileMCP impact:
Freeze a lower-level mutation core first:

`strong version token -> mutation guard -> atomic apply_edits`

Later, optional patch/search-replace adapters can translate model-friendly formats into the canonical versioned mutation primitive.

Do not make a model-specific patch syntax the security boundary.

## Finding A4 - Aider edit strategies do not provide the same optimistic concurrency contract FileMCP needs

EditBlockCoder and patch parsing read/match current text and can recover from mismatches, but the source does not establish a server-owned cryptographic/opaque expected-version contract comparable to ChatCMD's version tokens.

FileMCP decision:
Do not replace the ChatCMD-inspired version-token design with Aider search/replace matching. Use Aider only to inform optional higher-level edit adapters.

## Finding A5 - Git workflow protects user changes but is a different layer from FileMCP Git safe mode

Source evidence:
- `aider/repo.py` implements Git repository operations;
- `base_coder.py` detects dirty files and can commit pre-existing dirty state before agent edits;
- auto-commit behavior records AI changes in Git.

Aider optimizes undo/review/user-change separation. FileMCP's Git safe mode optimizes hostile-repository containment and non-interactive execution.

These are complementary, not interchangeable.

FileMCP implication:
- KEEP FileMCP Git safe mode;
- checkpoint/undo semantics, if added, sit above safe Git execution;
- do not auto-commit user work as an invisible side effect of a low-level FileMCP tool.

## Finding A6 - repository-map benefit must be measured against packaging and parser cost

Aider depends on tree-sitter language support and indexing logic. FileMCP has two native runtimes and a deliberately small package surface.

Final design recommendation:
- Phase A: budgets/cursors + project-context provenance first.
- Phase B: ADD an **on-demand Repository Intelligence service** only after profiling.
- Preferred initial feature: `repo_map`/`symbol_search` returning bounded structural metadata.
- Cache should be rebuildable and optional.
- Do not block ordinary file/search tools on index availability.

## FileMCP actions after Aider audit

| Capability | Preliminary action | Reason |
|---|---|---|
| current literal search tools | KEEP + HARDEN | simple, safe baseline; add cancellation/budget/cursor |
| project-context digest/provenance | ADD | rules/provenance concern remains distinct from code-symbol context |
| repository symbol map | ADD in Phase B | source-backed value for large repos, but parser/cache complexity |
| persistent full-source index | REJECT | privacy/storage complexity unnecessary |
| model-specific edit adapters | DEFER | useful above canonical apply_edits, not foundational |
| versioned atomic apply_edits | ADD | safer canonical mutation primitive |
| FileMCP Git safe mode | KEEP | security semantics stronger/different from Aider workflow |
| automatic dirty-worktree commit | REJECT as low-level tool default | surprising side effect; orchestration should decide commits |

## Independent conclusion

Aider reveals one real omission in ADR-0004: large-repo context should have a first-class future architecture slot, not be reduced to project instruction digest. The final architecture should distinguish:

- **Project Context**: rules, provenance, instruction hashes.
- **Repository Intelligence**: symbols, definitions/references, bounded structural map.

Both remain separate from authorization and observability.

## Evidence classification and audit envelope

Pinned SHA: `5dc9490bb35f9729ef2c95d00a19ccd30c26339c`
Pinned commit date: 2026-05-22T07:39:16-07:00
License: Apache-2.0
Overall evidence: **S1 - SHIPPED + SOURCE + TEST** for RepoMap, cache and edit/Git workflows inspected here.

Primary source paths:
- `aider/repomap.py`
- `tests/basic/test_repomap.py`
- `aider/coders/editblock_coder.py`
- `aider/coders/patch_coder.py`
- `aider/coders/udiff_coder.py`
- `aider/coders/wholefile_coder.py`
- `aider/coders/base_coder.py`
- `aider/repo.py`

Trust boundary introduced by RepoMap: parser/index/cache output is **context only**. It must never grant file/process/Git authority.

Persistent data introduced: rebuildable structural tag/cache metadata. FileMCP must not treat this cache as evidence or telemetry.

Failure modes to preserve in final design:
- unsupported parser/language falls back or returns less structure;
- stale cache if invalidation/versioning is wrong;
- parser/caching cost on very large repositories;
- symbol ranking is heuristic and must not be treated as exhaustive truth;
- cross-platform path/case behavior;
- parser dependency/package size.

FileMCP acceptance evidence if Repository Intelligence is later implemented:
- bounded/cancelable indexing;
- explicit ignored-directory/root containment;
- deterministic cache schema/version and corruption rebuild;
- freshness invalidation tests;
- large-repo resource-budget tests;
- no raw full-source persistence by default;
- Windows/macOS parity;
- repository intelligence unavailable/corrupt must not block ordinary read/search/edit tools.

Final action classification:
- project-context provenance/digest: **ADD Phase A**;
- repository symbol map/search: **DEFER to Phase B / ADD only after profiling**;
- persistent full-source index: **REJECT**;
- Aider model-specific patch/search-replace as security boundary: **REJECT**;
- optional model-friendly edit adapter above canonical versioned apply_edits: **DEFER**;
- automatic dirty-worktree commit as low-level FileMCP behavior: **REJECT**.
