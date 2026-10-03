# AGENTS.md

## Repository-specific rules

- Repository: FileMCP.
- Follow docs/process/IDEA_CAPTURE_AND_DESIGN_LAW.md for every new feature or architectural change.
- Keep MCP listeners loopback-only.
- Never weaken shared-root containment, reparse/junction defenses, Git safe mode, secret redaction, or tunnel environment allowlisting.
- Runtime API keys/local-auth tokens stay in Credential Manager or transient process environment, never telemetry/state files.
- Observability stores metadata/counters only. Never persist request/response bodies, tool arguments, commands, file contents, Git messages, prompt/chat text, cookies, or bearer credentials.
- Token metrics must be labeled as MCP payload estimates unless an upstream source provides authoritative usage.
- Multi-drive workspaces remain independent security/runtime boundaries; aggregation is read-only.
- TCP connections must never be presented as distinct chats.
- Build/test evidence is mandatory before PASS.
- Lifecycle after architecture freeze: CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> PUSH REMOTE -> PR -> REVIEW -> MERGE MAIN -> VERIFY MAIN -> MAIN VERIFIED -> DONE -> NEXT READY TASK.

## Mandatory GitHub remote / PR / MAIN VERIFIED completion law

- Every implementation, fix, refactor, documentation/process-law change, release change, and task closure in this repository MUST end on the configured writable GitHub remote and MUST be merged into `main` through a pull request.
- A local commit is only a durable checkpoint. `COMMIT LOCAL`, `LOCAL VERIFIED`, a clean worktree, or a locally green build/test MUST NEVER be interpreted or recorded as `DONE`.
- Before a task may become `DONE`, all of the following are mandatory and must have durable evidence: the exact candidate commit exists; the task branch is pushed to the configured writable GitHub remote; a PR targets `main`; required exact-head CI/checks are green; review is complete; the exact reviewed head is merged; `main` contains the merge; required merged-main verification/checks are green; and state/evidence records the resulting main commit as `MAIN VERIFIED`.
- Direct local-only completion and silent direct-to-main completion are forbidden. If GitHub, authentication, remote push, PR creation, review, merge, or merged-main verification is unavailable, the task remains `ACTIVE` or `BLOCKED` with `NEXT_EXACT_ACTION`; it does not become `DONE`.
- A successful pre-merge branch CI run is not `MAIN VERIFIED`. `MAIN VERIFIED` refers only to evidence collected from the post-merge `main` commit required by the task's verification contract.
- State files MUST distinguish at least: local checkpoint / local verified / remote pushed / PR open / PR green-reviewed / merged / main verification pending / MAIN VERIFIED / DONE. They must never collapse these into a local `DONE`.
- Before push/PR/merge or any retry with side effects, inspect the real remote/PR/merge state first so interrupted chat streams cannot create duplicate pushes, duplicate PRs, duplicate merges, or duplicate release actions.
- The next task in a dependency chain MUST NOT be claimed when its prerequisite requires `MAIN VERIFIED` and has not reached that state.
- Any historical text that appears to allow `COMMIT -> DONE` is superseded by this section.

## Complete-current-scope pre-code law

- FileMCP follows complete-scope-first design. Before the first feature implementation task is claimed, every capability/phase in the currently approved upgrade scope must be captured, deep-dived, compared, independently reviewed/red-teamed, repaired, architecture-frozen, dependency-checked, and task-split.
- Do not deliberately stop at an intermediate implementation milestone to reopen a known later architecture phase. Known later-scope items must be resolved before coding as BUILD, REJECT, or explicitly OUT-OF-SCOPE by product authority.
- Ambiguous `DEFER` is not an acceptable final pre-code state for a capability already inside the currently desired product scope.
- For the current FileMCP complete upgrade, ADR-0006 and `tasks/MASTER_FILEMCP_COMPLETE_UPGRADE_TASK_GRAPH.md` are the ordering authorities. FMG-001 is the only initial READY task; FMG-013 is a foundation milestone; FMG-026 is the complete-upgrade final gate.
- Any later change to product boundary, trust boundary, persistence class, or dependency architecture requires a new ADR/review round; task-level implementation detail may evolve inside the frozen contracts.

## FMUX product-experience law

- FMG-001..FMG-026 remains the engine/gateway scope and MUST NOT be diluted by FMUX work.
- FMUX authority is ADR-0007 plus tasks/MASTER_FILEMCP_FMUX_TASK_GRAPH.md.
- FMUX consumes core/runtime truth; presentation code must never grant authority, bypass policy, invent evidence, or expose unavailable FMG capability.
- Preserve native stacks: Windows WPF and macOS AppKit unless a future product-authority ADR explicitly changes that boundary.
- Do not start FMUX-002 before FMUX-001 MAIN VERIFIED; follow the frozen FMUX dependency graph thereafter.

## Canonical PROJECT_ROOT lock

- The only authorized local PROJECT_ROOT for FileMCP is `D:\Tools\FileMCP`.
- Persistent FileMCP-named repositories/directories outside the canonical root are forbidden, including `D:\FileMCP-*`; OSS/source audits must be captured as manifests/evidence inside the canonical repo rather than kept as sibling project roots.
- Before any code/test/build/Git action, verify `git rev-parse --show-toplevel` resolves to `D:/Tools/FileMCP` (path-separator normalization is acceptable).
- Do NOT create sibling clones, temporary repositories, Git worktrees, or directories such as `D:\Tools\FileMCP-*-worktree` unless the user explicitly supersedes this rule in that turn.
- Do NOT use `git worktree add` as the normal task-isolation mechanism. Branch switching and task execution happen inside the canonical PROJECT_ROOT.
- Only one coding branch may be active in the canonical working tree at a time. Other chats may inspect/monitor state, but must not switch the active branch or create parallel worktrees while another coding task is running.
- Before switching branches, verify a clean worktree and inspect process/runtime/side-effect state. Preserve unfinished work with commits and remote branches, not sibling worktrees.
- Historical branch refs may remain in Git for audit/recovery; inspect them with Git refs/diff/show from the canonical root instead of materializing sibling folders.
- If a stale sibling FileMCP directory is ever discovered, audit for unique unmerged changes, salvage only compatible/stronger parts into the canonical branch, verify them, then remove the sibling directory.
- Generated build/test/evidence artifacts must live under canonical repository-managed directories unless an external platform requires another temporary location.
- `Repo + Git + evidence + runtime state` remain source of truth; chat-stream continuity is not authority.
