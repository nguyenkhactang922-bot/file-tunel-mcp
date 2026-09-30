# FMG-022 Checkpoint Restore Transaction Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-09-30
Branch: chatgpt/FMG-022-checkpoint-restore
Pre-commit head: 7ad8fe30e295632389473b61960f67deb36fbccc

## Resume classification

After Resume stream loss, source-of-truth classified FMG-022 as INTERRUPTED at CODE stage:
- canonical root D:\Tools\FileMCP;
- branch chatgpt/FMG-022-checkpoint-restore;
- dirty implementation present on Windows/macOS;
- no FMG-022 build/test process running;
- no prior FMG-022 exit/evidence artifact;
- FMG-020 and FMG-021 already MAIN VERIFIED.

Work resumed from the existing restore implementation only; no passed task/stage was restarted.

## Scope implemented

- checkpoint_restore tool and policy capability;
- restore planning against checkpoint manifest;
- default divergence/history refusal;
- explicit stronger policy gate for history-moving restore;
- mandatory rollback checkpoint before mutation;
- staged / unstaged / untracked restoration;
- index-mode restoration;
- Mutation Guard / source-state revalidation before mutation;
- post-restore verification;
- rollback on restore failure;
- retained recovery material + partial_recovery_required on rollback failure;
- restore journal and crash recovery;
- Windows/macOS transactional parity;
- checkpoint schema v2 index metadata required for exact staged restore.

## Local verification

PASS:
- project-state contract;
- checkpoint-restore contract: catalog 1.13.0 / 46 tools / transactional parity;
- targeted Windows checkpoint restore runtime: 29 assertions;
- canonical catalog contract: 46 tools, SHA-256 30ecf017a35db8ebeb6344786576664035f504cae8996a0c4a223df797254364;
- tool-surface parity;
- workspace-checkpoint capture compatibility after FMG-022;
- Windows test-project build: 0 warnings / 0 errors;
- Windows Release app build after required NuGet restore: 0 warnings / 0 errors;
- full Windows runtime regression: 955 assertions;
- full Windows runtime includes windows-workspace-checkpoint-restore: ok;
- macOS Swift runtime/build shell syntax PASS.

The first Release build attempt used --no-restore while the local NuGet cache was missing Microsoft.NET.ILLink.Tasks 8.0.31. Running the required dotnet restore fixed only the environment/cache stage; the product candidate was unchanged.

The first full-runtime invocation lost the bridge stream and provided no durable exit artifact. It was not treated as PASS. The exact Windows runtime stage was rerun with durable stdout/stderr/exit capture; stdout finished with windows-core-tests: ok (955 assertions), stderr was empty, and durable exit code was 0.

## Scope guard

- no FMG-023 execution-backend work is claimed;
- no direct history movement is enabled by default;
- rollback failure cannot report PASS;
- restore requires checkpoint/artifact integrity and repository identity;
- mutation authority remains SafePathResolver / Mutation Guard / policy / version/source-state primitives;
- rollback material is retained until verification/cleanup succeeds.

## Next exact action

Inspect latest fork/main and remote FMG-022 branch/PR state before any side effect.
If no newer/duplicate candidate exists:
1. commit this exact local-verified FMG-022 candidate;
2. sync latest verified main only if it advanced, rerunning only affected gates;
3. push exact head;
4. require native Verify on macOS / Windows x64 / Windows ARM64;
5. perform scoped review;
6. PR/merge only exact green head;
7. require merged-main Verify;
8. mark FMG-022 DONE / MAIN VERIFIED and claim FMG-023.

## Final local diff-hygiene checkpoint

Before commit, scoped diff review found one literal NUL byte in `WorkspaceCheckpointGit.cs`, causing Git to classify the C# source as binary. The source byte was normalized to the canonical C# escape `\0` without changing runtime semantics. Post-fix proof: `git diff --check` PASS; Windows test-project build PASS 0 warnings/errors; targeted checkpoint restore PASS 29 assertions.
