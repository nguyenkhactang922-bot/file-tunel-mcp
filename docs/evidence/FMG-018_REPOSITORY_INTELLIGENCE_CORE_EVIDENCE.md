# FMG-018 Repository Intelligence Core / Cache Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-29
Branch: chatgpt/FMG-018-repo-intelligence-core

## Resume classification

After stream interruption, repo/runtime source-of-truth classified FMG-018 as INTERRUPTED at CODE stage:
- no FMG-018 test/build process was running;
- no FMG-018 exit/log artifact existed;
- Windows repository-intelligence implementation and tests were already present;
- macOS repository-intelligence parity and CI wiring were present but had no completed gate evidence.

Work resumed from that checkpoint only; prior MAIN VERIFIED tasks were not restarted.

## Scope implemented

Internal repository-intelligence core only. No new MCP query tools are exposed in FMG-018.

Windows and macOS:
- RepositoryIntelligenceProvider interface;
- built-in LexicalSymbolProvider;
- provider id/version and completeness=heuristic truth label;
- Git-tracked inventory via git ls-files;
- ignored-directory policy for generated/vendor/cache directories;
- bounded tracked-file inventory;
- bounded per-file / aggregate lexical indexing;
- lightweight C#/Swift/Python/JavaScript/TypeScript symbol and import extraction;
- unsupported-language file-level metadata fallback;
- binary/non-UTF8 degradation without parser failure;
- import and same-directory relation/ranking metadata;
- SourceStateRef-bound generation identity;
- rebuildable JSON metadata cache outside the workspace;
- corrupt/identity-mismatched cache delete/rebuild;
- stale generation cleanup;
- cancellation checks;
- no raw full-source persistence by default;
- repository intelligence is heuristic metadata only and never authorization.

## Tool-surface guard

FMG-018 does not expose repo_map, symbol_search or related_files.
Canonical tool surface remains:
- catalog version: 1.9.0;
- 31 canonical tools;
- Windows runtime catalog SHA-256: 7b053baec3ddd1ce8789e651bdd0e9f6d1354387c03f2ddf8a1a05763d32d4d8.

FMG-019 remains BLOCKED until FMG-018 MAIN VERIFIED.

## Local verification

PASS:
- project-state contract;
- repository-intelligence contract;
- Windows repository-intelligence-only integration: 20 assertions;
- Windows test project build: 0 warnings / 0 errors;
- Windows Release app build: 0 warnings / 0 errors;
- Windows full runtime regression: 859 assertions, including windows-repository-intelligence-core: ok;
- macOS runtime shell wiring syntax;
- macOS release-build shell syntax;
- git diff --check.

macOS native compiler/runtime verification remains pending and is delegated to the exact-head native Verify gate.

## Negative / adversarial coverage

Covered in native fixtures/contracts:
- generated/vendor/obj paths ignored;
- unsupported languages degrade to file-level metadata;
- binary/non-UTF8 file degrades safely;
- case/path preservation fixture;
- cache contains metadata only and excludes raw source sentinel;
- corrupt cache rebuilds;
- source mutation changes SourceStateRef and generation;
- stale cache generation is cleaned up;
- cancellation aborts indexing;
- cache root inside workspace is rejected;
- future FMG-019 facade names remain absent.

## Scope guard

- no raw full-source persistent index;
- no authorization or path decision consumes repository-intelligence results;
- SafePathResolver/Git/SourceStateRef remain authoritative;
- no new public MCP tools;
- no FMG-019 query facade;
- no FMG-020+ functionality.

## Next exact action

Inspect latest fork/main and remote FMG-018 branch/PR state before any push.
If no duplicate/newer work exists:
1. commit this exact local-verified candidate;
2. sync latest verified main if it advanced and rerun only affected gates;
3. push exact head;
4. require native Verify on macOS / Windows x64 / Windows ARM64;
5. scoped review;
6. PR/merge only exact green head;
7. require merged-main Verify;
8. mark FMG-018 DONE / MAIN VERIFIED and claim FMG-019.
