# FMG-018 Repository Intelligence Core / Cache Evidence

Status: WINDOWS CORE TARGETED VERIFIED / MACOS PARITY PENDING

Branch: `chatgpt/FMG-018-repository-intelligence-core`

## Windows core checkpoint

Implemented:
- `IRepositoryIntelligenceProvider` contract;
- built-in `LexicalSymbolProvider` with provider id/version, `completeness=heuristic`, parser profile hash;
- Git-tracked inventory through existing safe Git execution path;
- ignored-directory/generated/binary/oversized policy;
- lightweight language-aware symbol/import extraction;
- deterministic file relations/ranking;
- SourceStateRef binding and post-index revalidation before cache publication;
- rebuildable metadata-only cache outside workspace;
- stale/profile-mismatch/corrupt cache delete+rebuild;
- no raw full-source persistence;
- no authorization dependence on intelligence.

Targeted Windows proof:
- Release compilation succeeded for the candidate code path;
- `repo-intelligence-only`: `windows-repository-intelligence: ok`;
- `windows-repo-intelligence-only-tests: ok (22 assertions)`.

Negative/edge coverage includes:
- tracked-only inventory and exclusion of untracked/vendor/generated/binary files;
- unsupported language file-level degradation;
- canonical Git path casing;
- stale SourceStateRef invalidation;
- corrupted cache recovery;
- parser/profile mismatch invalidation;
- bounded giant-repo truncation;
- cooperative cancellation;
- in-flight source-state race prevents stale cache publication;
- baseline `read_file` remains independent from intelligence/cache.

## Remaining gate

1. implement macOS provider/service/cache parity using existing safe Git + SourceStateRef primitives;
2. add native Swift parity/adversarial tests and compile-list wiring;
3. cross-platform contract;
4. local affected gates + full Windows regression;
5. exact-head native Verify macOS / Windows x64 / Windows ARM64;
6. scoped review -> PR/merge -> merged-main Verify;
7. mark FMG-018 DONE / MAIN VERIFIED -> claim FMG-019.

## Cross-platform implementation checkpoint

Status: LOCAL VERIFIED / NATIVE CI PENDING.

macOS parity implemented:
- `macos/RepositoryIntelligence.swift`: provider protocol, lexical heuristic provider, bounded tracked inventory, metadata-only cache, SourceStateRef recheck, stale/corrupt recovery, relations/ranking, cancellation/bounds, no authorization dependency;
- `LocalTools.captureRepositoryIntelligence` reuses existing safe `gitRepo`, `runGit` and `captureSourceStateRef` primitives;
- app build, CI typecheck and both native Swift runtime compile lists include the new file;
- native Swift harness covers tracked-only inventory, symbol/import/relation, metadata-only cache, hit/stale/corrupt recovery, max-files bound, cancellation and in-flight SourceStateRef race.

Local verification PASS:
- repository-intelligence contract;
- file-version/source-state contract;
- project-context contract;
- canonical catalog 1.9.0 / 31 tools unchanged;
- cross-platform tool-surface parity;
- project-state contract;
- Windows Release build: 0 warnings / 0 errors;
- FMG-018 isolation: 22 assertions PASS;
- full Windows regression: 856 assertions PASS;
- git diff check PASS.

NEXT_EXACT_ACTION: commit local-verified cross-platform candidate, sync latest fork/main, rerun only affected gates if main advanced, push exact synchronized head, require native Verify on macOS + Windows x64 + native Windows ARM64, then scoped review -> PR/merge -> merged-main Verify -> FMG-018 DONE / MAIN VERIFIED -> claim FMG-019.
