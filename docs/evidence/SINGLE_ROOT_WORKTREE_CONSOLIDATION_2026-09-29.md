# Single-Root Worktree Consolidation Evidence - 2026-09-29

## Authority

User locked FileMCP to one canonical project root:

`D:\Tools\FileMCP`

No sibling FileMCP worktree/clone is allowed for normal execution after this checkpoint.

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

FMG-020 was the active unique branch. Its unique code was committed and pushed before deletion of its worktree. The useful dirty FMG-013 Git-fixture hardening was then merged into the FMG-020 branch:

- `core.autocrlf=false` for the repository-query fixture;
- 60-second timeout for large `git add .` fixture staging;
- explicit `TimedOut` evidence in Git-fixture failures.

Verification after merge:

- Windows test project build: PASS, 0 warnings / 0 errors;
- `repo-query-only`: PASS, 18 assertions.

Preserved active head: `92e4496cb8c4127716d3478645da03a045b41dbe` and pushed to `fork/chatgpt/FMG-020-persistent-pty`.

### Deliberately not merged

- `FMUX-007-settings-policy-v2`: stale alternate UI branch. Applying it to current main would remove/regress a large amount of later FMUX UI work. PR #29 was closed as superseded.
- FMG-017 dirty alternate: audited against PR #36. The merged PR implementation is larger and current main contains both model-friendly edit adapters plus their negative/runtime coverage. Dirty alternate was therefore superseded.
- FMG-018 alternate implementation: PR #37 already established the accepted repository-intelligence implementation used by FMG-019. The sibling worktree represented a divergent alternate core. Current main already covers raw-source exclusion, stale/corrupt cache rebuild, parser/profile mismatch, giant-repository bounds and stale in-flight generation, so the divergent core was not merged.
- FMUX007/008/009/010/014 worktrees had no unique commit relative to current main and were historical merged worktrees.

## Destructive cleanup result

All sibling FileMCP worktrees were removed through `git worktree remove --force` only after the audit/preservation steps above, then `git worktree prune` was run.

Expected post-cleanup state:

- `git worktree list`: exactly one entry, `D:/Tools/FileMCP`;
- `D:\Tools` contains exactly one directory matching `FileMCP*`: `D:\Tools\FileMCP`;
- active branch in the canonical root: `chatgpt/FMG-020-persistent-pty`;
- upstream: `fork/chatgpt/FMG-020-persistent-pty`.

## Prevention rule

`AGENTS.md` now contains a Single-project-root lock. Future coding chats must use the canonical root and must not create sibling worktrees unless the user explicitly supersedes that rule.
