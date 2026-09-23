# Cline Recovery, Checkpoint and Durable Session Audit for FileMCP

Status: INDEPENDENT SOURCE AUDIT COMPLETE
Date: 2026-09-23
Repository: https://github.com/cline/cline
Pinned commit: 9c0e4aaee09f6593eb8d06ec4a35bf19b7dc33f1
Audit clone: D:\Tools\_audit\Cline
Purpose: challenge ADR-0004 on checkpoints, recovery, task/session persistence and completion semantics.

## Finding CL1 - checkpoint is a distinct subsystem, not "Git exists"

Source evidence:
- `sdk/packages/core/src/session/checkpoint-restore.ts`;
- `sdk/packages/core/src/session/session-versioning-service.ts`;
- checkpoint restore/diff tests;
- CLI/runtime restore plumbing.

Cline checkpoint restoration includes:
- checkpoint history tied to run counts;
- restore plan construction;
- worktree restore transaction;
- temporary private Git refs;
- rollback on failure;
- handling staged, unstaged and untracked state;
- restore metadata carried into the replacement/restored session.

FileMCP implication:
If FileMCP ever owns checkpoints, it needs a dedicated lifecycle and cannot claim that ordinary Git history already supplies checkpoint semantics.

## Finding CL2 - destructive restore requires a transaction

`beginWorktreeRestoreTransaction()` captures current staged/unstaged/untracked state before a destructive restore. It hides the snapshot behind a private ref and can commit cleanup or rollback the whole operation.

Tests cover rollback of:
- HEAD;
- staged changes;
- unstaged changes;
- untracked files;
- cleanup of temporary refs.

FileMCP implication:
A future checkpoint restore cannot be implemented as a few `git reset` calls. It requires an explicit transactional design and strong user-intent boundary.

## Finding CL3 - restore refuses to silently destroy later history

`applyCheckpointToWorktree()` checks whether current HEAD still matches the checkpoint base. Tests reject restore when later commits were added or history diverged/amended.

This is a strong safety property.

FileMCP implication:
Any future workspace checkpoint feature must fail closed when repository history has moved unless the user explicitly requests a history-moving operation.

## Finding CL4 - full snapshot semantics are difficult

Tests distinguish snapshot checkpoints that captured untracked files from older/commit-only fallbacks. They also preserve ignored build artifacts in some restore cases.

Cline changelog/source history contains repeated fixes around checkpoint restore, large untracked directories, restart/resume and transaction behavior.

Conclusion:
Checkpoint/recovery is high complexity and should not be smuggled into FileMCP Phase A just because long autonomous tasks are desirable.

## Finding CL5 - Cline persists substantially more content than FileMCP privacy law permits

Source evidence:
`sdk/packages/core/src/services/session-artifacts.ts` creates message artifacts such as `${sessionId}.messages.json`, plus manifests/compaction artifacts and child/subagent message files.

`sdk/ARCHITECTURE.md` describes canonical session transcript persistence, compaction state and resumable sessions.

This is valid for Cline's product, but conflicts with FileMCP's privacy-minimal bridge role.

FileMCP decision:
- do not copy full transcript/task persistence;
- evidence persistence must remain metadata-only;
- if a future checkpoint exists, store Git/object identifiers and opaque metadata, not chat/prompt/tool content.

## Finding CL6 - completion and runtime status are explicit state, not inferred text

Cline architecture distinguishes session running/idle state, completion events and command progress. This reinforces FileMCP's planned rule that terminal output containing "PASS" cannot itself be evidence.

## Finding CL7 - task manager/persistence belongs to a higher product layer

Cline has durable task/session services and, at the audited source, operational task state separated from editable task descriptions. Approval can be revision-bound and stale approvals invalidated.

FileMCP already has a user-defined orchestration law where ChatGPT is the main coding agent and repository state files are authoritative task state. Importing a second local task manager would duplicate authority and expand persistence.

## FileMCP actions after Cline audit

| Capability | Preliminary action | Reason |
|---|---|---|
| Git safe mode | KEEP | security layer, not checkpoint layer |
| execution evidence | ADD | completion/evidence needs explicit state |
| durable chat/session history | REJECT | conflicts with privacy-minimal bridge role |
| local general task manager | REJECT for core architecture | duplicates ChatGPT/repo-state authority |
| workspace checkpoint capture/restore | DEFER | high complexity; must be transactional if later added |
| checkpoint architecture seam | DOCUMENT | keep separate from Git/evidence/observability |
| restart-resumable evidence metadata | ADD selectively | useful without persisting transcript |
| full session resume | REJECT for current core | requires content persistence not justified by product goal |

## Independent conclusion

Cline changes the final model mainly by forcing a strict separation:

`Git history != checkpoint != task state != evidence != observability`.

For current FileMCP product goals, checkpoint is **not a Phase A prerequisite**. The architecture should leave a clean future seam, but the first upgrade should deliver safer execution/editing/evidence without taking ownership of entire agent sessions.

## Evidence classification and final action

Pinned SHA: `9c0e4aaee09f6593eb8d06ec4a35bf19b7dc33f1`
Pinned commit date: 2026-09-23T14:53:49-07:00
License: Apache-2.0
Overall checkpoint/session evidence: **S1 - SHIPPED + SOURCE + TEST**.

Primary source/test paths:
- `sdk/packages/core/src/session/checkpoint-restore.ts`
- `sdk/packages/core/src/session/session-versioning-service.ts`
- `sdk/packages/core/src/hooks/checkpoint-hooks.ts` and `.test.ts`
- `sdk/packages/core/src/services/session-artifacts.ts`
- `sdk/ARCHITECTURE.md`

Additional verified safety properties:
- restore transaction captures staged/unstaged/untracked state behind a private Git ref;
- restore uses Git `update-ref` compare-and-swap before destructive reset, closing the race after HEAD validation;
- later commits/diverged history are refused rather than silently discarded;
- snapshot checkpoints distinguish whether untracked files were actually captured;
- checkpoint telemetry records outcome/duration/kind without workspace path/content;
- full session artifacts still persist message/transcript state and therefore exceed FileMCP privacy scope.

Final FileMCP actions:
- broad durable session/transcript resume: **REJECT**;
- general local task/session manager: **REJECT**;
- workspace checkpoint capture/restore: **DEFER** to a separate future ADR;
- checkpoint seam/documented future lifecycle: **KEEP AS RESERVED SEAM**;
- restart-resumable evidence metadata (operation id, tool id, timestamps, terminal state, hashes/status only): **ADD selectively**;
- Git safe mode: **KEEP** and do not confuse it with checkpoint semantics.

If workspace checkpoint is ever approved, acceptance must include transaction rollback, staged/unstaged/untracked preservation, divergent-history refusal, CAS race test, temp-ref cleanup and user-intent gating.
