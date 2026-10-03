# ChatGPT Web / FileMCP execution law

ChatGPT Web is the main coding/design agent. FileMCP is the local execution bridge.

## Design gate
IDEA -> CAPTURE -> LIVING DESIGN -> DEEP DIVE -> INDEPENDENT REVIEW -> SOLUTION MATRIX -> ARCHITECTURE FREEZE -> TASK GRAPH.
No feature code before this gate is complete.

## Implementation gate
CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> PUSH REMOTE -> PR -> REVIEW -> MERGE MAIN -> VERIFY MAIN -> MAIN VERIFIED -> DONE -> NEXT READY TASK.

Before every task confirm git root/branch/HEAD/status and read AGENTS.md, CURRENT_HANDOFF.md, PROJECT_STATE.md, and tasks/TASK_QUEUE.md. Resume NEXT_EXACT_ACTION rather than restarting work.

## Mandatory GitHub remote / PR / MAIN VERIFIED completion gate

This gate is mandatory for FileMCP and supersedes any older wording that could be read as allowing a local commit to finish a task.

A task/change is NOT DONE merely because it is committed locally, locally tested, has a clean worktree, or has a green branch build. Local commits are checkpoints only.

The minimum completion sequence is:

EXACT CANDIDATE COMMIT
-> PUSH TO CONFIGURED WRITABLE GITHUB REMOTE
-> PR TARGETING `main`
-> EXACT-HEAD REQUIRED CI/CHECKS GREEN
-> REVIEW COMPLETE
-> MERGE THE REVIEWED HEAD INTO `main`
-> CONFIRM `main` CONTAINS THE MERGE
-> RUN/CONFIRM REQUIRED MERGED-MAIN VERIFICATION
-> RECORD MAIN COMMIT + VERIFICATION EVIDENCE
-> MAIN VERIFIED
-> DONE.

Hard rules:
- Every implementation, fix, refactor, docs/process-law change, release change, and task closure must reach the configured writable GitHub remote and be merged to `main` through a pull request.
- `COMMIT LOCAL`, `LOCAL VERIFIED`, `PASS LOCAL`, clean status, or a local artifact MUST NOT be labeled `DONE`.
- `PUSHED` is not `DONE`; `PR OPEN` is not `DONE`; `PR GREEN` is not `DONE`; `MERGED` is not `DONE` until the required post-merge main verification has passed.
- `MAIN VERIFIED` means the required verification contract has been satisfied for the actual post-merge `main` commit. A pre-merge branch run cannot be reused as proof of merged-main verification unless the verification contract explicitly proves the exact same resulting main commit and the task law allows that equivalence.
- If remote access, authentication, push, PR creation, review, merge, or merged-main verification is unavailable, preserve the task as `ACTIVE` or `BLOCKED` with precise `NEXT_EXACT_ACTION`; never convert the blockage into local `DONE`.
- State/evidence must preserve lifecycle granularity: local checkpoint, local verified, remote pushed, PR open, PR green/reviewed, merged, main verification pending, MAIN VERIFIED, DONE.
- Before any side-effect retry (push, PR creation, merge, publish, release, migration), inspect the real remote/PR/runtime state first to avoid duplicates after stream interruption.
- Do not claim a dependent next task if its prerequisite requires `MAIN VERIFIED` and has not reached that state.
- Direct local-only completion is forbidden. Direct-to-main completion that bypasses the required PR/review gate is forbidden.
- The durable source of truth for completion is the combination of repository state, GitHub remote/PR state, verification evidence, and the resulting `main` commit; chat text is never sufficient proof.

## Complete current-scope freeze law

Default operating mode is **complete-scope-first**:

CURRENT PRODUCT INTENT
-> CAPTURE ALL KNOWN REQUIREMENTS
-> LIVING DESIGN
-> DEEP DIVE BY SUBSYSTEM
-> CONTINUOUS DESIGN UPDATES
-> INDEPENDENT MULTI-ROUND REVIEW / RED-TEAM
-> TECHNOLOGY / SOLUTION COMPARISON
-> RESOLVE KNOWN LATER-PHASE ITEMS
-> ARCHITECTURE FREEZE
-> COMPLETE DEPENDENCY GRAPH
-> COMPLETE TASK SPLIT
-> ONLY THEN START FEATURE CODE.

Before the first implementation task:
- enumerate all capabilities/phases already known to be part of the currently desired upgrade;
- resolve each to BUILD, REJECT, or explicitly OUT-OF-SCOPE;
- do not leave an in-scope known capability as a vague `DEFER` merely to postpone design until after coding an earlier phase;
- freeze cross-phase dependencies so an intermediate milestone does not become a surprise architecture restart;
- define the final completion gate for the whole current scope, not only the first implementation phase.

This law does **not** claim that unknown future product ideas can be designed in advance. New requirements discovered later are handled by a new capture/review/ADR cycle. But known current-scope work must be designed and task-split before implementation begins.

No feature code before this complete current-scope gate is complete.

## Canonical PROJECT_ROOT lock

- The only authorized local project root for FileMCP is `D:\Tools\FileMCP`.
- Persistent FileMCP-named repositories/directories outside the canonical root are forbidden, including `D:\FileMCP-*`; OSS/source audits must be captured as manifests/evidence inside the canonical repo rather than kept as sibling project roots.
- Before any code/test/build/Git action, verify `git rev-parse --show-toplevel` resolves to `D:/Tools/FileMCP` (path-separator normalization is acceptable).
- Do NOT create sibling clones, temporary repositories, or Git worktrees such as `D:\Tools\FileMCP-*-worktree` unless the user explicitly authorizes a temporary secondary worktree in that same turn.
- Do NOT use `git worktree add` as the default task-isolation mechanism. Branch switching and task execution happen inside the canonical PROJECT_ROOT.
- Existing historical branches/commits may remain as Git history inside the single repository; they must not be materialized as sibling project folders merely to inspect them. Inspect them with Git refs/diff/show from the canonical root.
- If a stale sibling FileMCP directory is discovered, first audit for unique unmerged changes, salvage only the compatible/stronger parts into the canonical branch, verify them, and then remove the sibling directory.
- Generated build/test/evidence artifacts must live under the canonical repository's own managed directories unless an external platform mandates another temporary location.
