# FINAL Recovery, Checkpoint and Task-State Model

Status: FROZEN BY ADR-0005
Date: 2026-09-23

## Core separation

```text
Git history
!= workspace checkpoint
!= project task state
!= execution evidence
!= observability
```

No subsystem is allowed to silently become all five.

## Git

Purpose:
- source history/integration;
- controlled Git operations;
- reviewable commits.

Security remains FileMCP Git safe mode.

FileMCP does not auto-commit after each AI edit as a low-level gateway behavior.

## Project task state

Current authority remains repository-owned Markdown + ChatGPT orchestration:
- CURRENT_HANDOFF.md;
- PROJECT_STATE.md;
- task queues/laws.

FileMCP does not create a competing local task/session authority.

## Execution evidence

ADD privacy-minimal evidence:
- operation state;
- source digest;
- criterion/result metadata;
- bounded retention.

Evidence supports verification freshness, not conversational resume.

## Workspace checkpoints

DEFER.

Cline demonstrates safe restore requires:
- divergence guard;
- staged/unstaged/untracked semantics;
- transactional restore;
- rollback if restore fails;
- user-intent handling.

This complexity is not required for Phase A.

Any future checkpoint implementation requires a separate ADR and destructive-operation acceptance suite.

## Application/process restart

Phase A may persist metadata-only terminal evidence so a restart can distinguish:
- completed terminal operation;
- failed operation;
- unknown/in-flight operation at crash.

It does not resume arbitrary process execution automatically.

Unknown in-flight side effects are never replayed automatically.

## Task/session transcript persistence

REJECT from FileMCP core:
- prompt history;
- raw command history;
- tool body/result history;
- file content snapshots for general session resume.

This preserves the privacy boundary and avoids duplicating ChatGPT's role.

## PTY recovery

PTY is deferred. If introduced later, PTY restart/expiry/replay semantics require a dedicated design.

## Sub-agent recovery

Not applicable in current core because local task/sub-agent runtime is rejected.

## Recovery principle

When correctness is uncertain after a crash:

> prefer UNKNOWN/BLOCKED + re-verification over automatic replay of potentially side-effecting operations.
