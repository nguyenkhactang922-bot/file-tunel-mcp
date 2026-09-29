# FileMCP Single PROJECT_ROOT Consolidation Evidence

Date: 2026-09-29
Canonical PROJECT_ROOT: `D:\Tools\FileMCP`

## Pre-cleanup audit

Registered sibling worktrees audited before deletion:

- `D:\Tools\FileMCP-FMG013-worktree`
- `D:\Tools\FileMCP-FMG017-worktree`
- `D:\Tools\FileMCP-FMG018-worktree`
- `D:\Tools\FileMCP-FMG020-worktree`
- `D:\Tools\FileMCP-FMUX007-worktree`
- `D:\Tools\FileMCP-FMUX008-worktree`
- `D:\Tools\FileMCP-FMUX009-worktree`
- `D:\Tools\FileMCP-FMUX010-worktree`
- `D:\Tools\FileMCP-FMUX014-worktree`

## Preservation decisions

### Preserved and merged

FMG-020 was the active unique branch and was pushed before deleting its worktree. The useful dirty FMG-013 Git-fixture hardening was merged into FMG-020:

- `core.autocrlf=false` for the repository-query fixture;
- 60-second timeout for large `git add .` fixture staging;
- explicit `TimedOut` evidence in Git-fixture failures.

Verification after that merge:

- Windows test project build: PASS, 0 warnings / 0 errors;
- `repo-query-only`: PASS, 18 assertions.

Preserved checkpoint: `92e4496cb8c4127716d3478645da03a045b41dbe`, pushed to `fork/chatgpt/FMG-020-persistent-pty`.

### Deliberately not merged

- `FMUX-007-settings-policy-v2`: stale alternate UI branch. Applying it over current main would remove/regress later merged FMUX UI work. PR #29 was closed as superseded.
- FMG-017 dirty alternate: audited against PR #36. The merged PR implementation is larger and current main contains both edit adapters plus their negative/runtime coverage.
- FMG-018 divergent alternate: PR #37 established the accepted repository-intelligence architecture used by FMG-019. Current main already covers raw-source exclusion, cache hit/stale/corrupt handling, parser/profile mismatch, bounded giant repositories, cancellation and stale in-flight generation, so the alternate core was not merged.
- FMUX007/008/009/010/014 historical worktrees had no unique commit relative to current main.

## Destructive cleanup result

All sibling FileMCP worktrees were removed only after the audit/preservation steps above, then `git worktree prune` was run.

Post-cleanup verification:

- `git worktree list`: exactly one entry, `D:/Tools/FileMCP`;
- `D:\Tools`: exactly one directory matching `FileMCP*`, `D:\Tools\FileMCP`;
- active branch: `chatgpt/FMG-020-persistent-pty`;
- upstream: `fork/chatgpt/FMG-020-persistent-pty`.

## Anti-regression rule

`AGENTS.md` and `docs/CHATCODE_GLOBAL_MULTI_PROJECT_EXECUTION_LAW.md` now lock FileMCP to the canonical root. Secondary clones/worktrees are prohibited unless the user explicitly supersedes that rule in the same turn.

## Continuation

Continue FMG-020 from `D:\Tools\FileMCP` only. Repository/Git/evidence/runtime state remain the source of truth after stream loss.
