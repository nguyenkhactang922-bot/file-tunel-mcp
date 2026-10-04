# FMUX-013 Recovery UX Evidence

Status: ACTIVE / LOCAL VERIFIED / MACOS NATIVE CI PENDING
Date: 2026-10-04
Branch: `chatgpt/FMUX-013-recovery`
Base verified main: `dad103c569cbfc6d68b343445287152013c6f29e`
Runtime checkpoint: PID `17860`, `FileMCP-FMG026-ready`, not restarted.

## Frozen scope

FMUX-013 presents existing FMG-016/021/022 truth only:
- quarantine metadata and restore;
- checkpoints and detail metadata;
- checkpoint dry-run restore plan;
- restore with core rollback protection;
- explicit rolled-back and `partial_recovery_required` states.

No new runtime authority is introduced.

## Presentation authority

The dedicated Recovery presentation bridge allowlists exactly:
- `quarantine_list`
- `quarantine_get`
- `quarantine_restore`
- `checkpoint_list`
- `checkpoint_get`
- `checkpoint_restore`

It does not expose `quarantine_delete`, `checkpoint_capture`, `checkpoint_delete`, `pty_start`, `pty_write` or `run_command`. All calls still execute through existing `LocalTools`, policy, source/version checks and rollback safeguards. Presentation metadata continues to declare `presentation_grants_authority=false`.

## Recovery interaction contract

Windows and macOS implement native master/detail Recovery pages.

Quarantine:
- metadata-only list/detail;
- root and original target visible before restore;
- native confirmation required;
- UI supplies only `quarantine_ref`, so it cannot opt into `replace_existing`, `expected_target_version` or target-path override;
- `restored`, `rolled_back`, and `partial_recovery_required` are surfaced distinctly.

Checkpoint:
- metadata-only list/detail with bounded entry preview;
- Restore remains disabled until `checkpoint_restore(dry_run=true, history_mode=preserve)` returns `planned`;
- native confirmation shows root, repository and preserve-history mode;
- apply uses `dry_run=false` and lets core source-state validation/rollback revalidate;
- `partial_recovery_required` is displayed as HIGH SEVERITY and retained as a persistent Recovery notice across refresh.

Recovery UI does not copy raw file contents into diagnostics/activity logs.

## Local verification

PASS:
- `tests/test_fmux_recovery_contract.ps1`
- `tests/test_fmux_app_shell_contract.ps1`
- `tests/test_fmux_presentation_contract.ps1`
- `tests/test_project_state_contract.ps1`
- `git diff --check`
- Verify workflow YAML parse
- Windows Release build: `dotnet build windows/FileMCP.Windows.sln -c Release --no-restore -warnaserror` => 0 warnings / 0 errors.

The Windows host does not provide `swiftc`; therefore macOS native typecheck/build is deliberately not claimed locally. The exact-head GitHub `verify-macos` lane is the required native authority before PR/merge.

## Review

Scoped local review: PASS, no P0/P1 found. Recovery is capability-backed, least-authority, plan-before-checkpoint-restore, fail-closed, and keeps partial-recovery state visible.

## Next gate

Create the task candidate commit, side-effect guard remote/PR state, push exact head, and require GitHub Verify success on macOS / Windows x64 / native Windows ARM64 before opening the reviewed PR. Local commit is not DONE.


## Exact-head native verification

Candidate `8e444cc5ffa76b0c97cb756d04b3be7620a87ccc` passed GitHub Verify `37189165659` on macOS / Windows x64 / native Windows ARM64. macOS native static/typecheck, integration and app build all passed; Windows lanes passed FMUX Recovery contract plus full build/integration/package/smoke coverage.

Scoped exact-head review: PASS, no P0/P1 found. Forbidden authority scan is empty in Recovery UI sections; the bridge remains the exact six-tool allowlist and runtime PID `17860` remains correct/unrestarted.

State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS. Next: evidence/state-only closure commit -> exact-head Verify of closure SHA -> one reviewed PR -> guarded merge -> merged-main Verify.
