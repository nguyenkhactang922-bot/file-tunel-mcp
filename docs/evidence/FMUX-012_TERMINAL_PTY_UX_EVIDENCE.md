# FMUX-012 Terminal / PTY UX Evidence

Date: 2026-10-04
Task: FMUX-012 — Terminal / PTY
Branch: `chatgpt/FMUX-012-terminal-pty`
Verified base: `fork/main = d378faa0807435be7ca21eff1c573518779c5dd4`
State: ACTIVE / LOCAL VERIFIED / EXACT-HEAD NATIVE VERIFY PENDING.

## Frozen scope

- PTY session list from real FMG-020 structured results.
- Selected active terminal with bounded output reads.
- Backend, policy and session state shown explicitly.
- Existing-policy controls only: Ctrl+C, stop and resize.
- No PTY start or stdin-write affordance in presentation scope.
- Restart resume remains explicitly unsupported.
- Presentation must not persist/copy raw PTY output or secret-like stdin into FileMCP activity/evidence telemetry and must not grant new authority.

## Implementation

The native desktop apps now expose a Terminal / PTY destination backed by a deliberately narrow presentation bridge into the already-verified FMG-020 PTY runtime.

The bridge allowlist is exactly:
- `pty_list`
- `pty_read`
- `pty_resize`
- `pty_signal`
- `pty_stop`

`pty_start` and `pty_write` are intentionally absent. Every presentation call still flows through canonical `LocalTools` authorization and the existing execution-backend PTY capability checks. Policy metadata is surfaced with `presentation_grants_authority=false`.

Windows WPF:
- `NavTerminalButton` / `TerminalTab`.
- session DataGrid with workspace, state, PID, session ID and last activity.
- bounded output reader: 16 KiB per read, 64 KiB maximum displayed text.
- Ctrl+C / Stop / Resize controls enabled only for `state=running` sessions.
- per-session cursor tracking; cursor eviction is stated explicitly.
- no terminal-input field and no `pty_start` / `pty_write` presentation call.

macOS AppKit:
- Terminal sidebar destination / hidden-tab page.
- session table plus bounded monospaced output view.
- bounded output reader: 16 KiB per read, 64 KiB maximum displayed text.
- Ctrl+C / Stop / Resize controls enabled only for `state=running` sessions.
- one-second refresh only while the Terminal page is selected; timer is invalidated on shutdown.
- no terminal-input field and no `pty_start` / `pty_write` presentation call.

## Runtime / recovery truth

Bootstrap on 2026-10-04 confirmed:
- project root `D:/Tools/FileMCP`.
- branch `chatgpt/FMUX-012-terminal-pty`.
- base HEAD `d378faa0807435be7ca21eff1c573518779c5dd4` before candidate commit.
- FileMCP PID `17860` remains alive from `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`.
- observability SQLite WAL continued updating, so the existing runtime was not restarted.

The interrupted chat was classified as INTERRUPTED at the FMUX-012 CODE checkpoint. FMUX-011 and FMG-020 were not rerun.

## Local evidence

PASS:
- `tests/test_fmux_terminal_pty_contract.ps1` — exact five-tool presentation allowlist; `pty_start` / `pty_write` absent; 16 KiB read / 64 KiB display bounds; no Terminal-to-log copy; restart resume explicit.
- `tests/test_fmux_app_shell_contract.ps1` — Terminal is now an implemented destination while Recovery remains guarded.
- `tests/test_fmux_presentation_contract.ps1`.
- `tests/test_fmux_repository_intelligence_contract.ps1` regression.
- `tests/test_persistent_pty_contract.ps1` — catalog 1.13.0 / 46 tools; Windows ConPTY; macOS POSIX PTY; restart resume false; raw PTY evidence/telemetry absent.
- `tests/test_project_state_contract.ps1` — branch/state alignment and exactly one authoritative next action.
- `git diff --check` — PASS; only repository line-ending warnings, no whitespace error.
- Windows Release build after the Windows FMUX-012 source changes: `dotnet build windows/FileMCP.Windows.sln -c Release --no-restore -warnaserror` — 0 warnings / 0 errors.

Native macOS compiler/runtime is not available on this Windows host. The exact-head GitHub `macos-26` Verify remains the authority for `swiftc -warnings-as-errors`, integration, app build and bundled-resource verification. Windows ARM64 native build/smoke likewise remains CI authority.

## Security / truth review

- UI does not call `pty_start` or `pty_write`.
- UI does not add an stdin editor.
- PTY output is read into bounded in-memory presentation state only; no new log/event/evidence marker carries raw PTY bytes.
- Ctrl+C / stop / resize are existing PTY operations and remain subject to server policy and execution-backend capability checks.
- Session metadata continues to state `restart_resume_supported=false` and `grants_authority=false`.
- Presentation bridge metadata explicitly states `presentation_grants_authority=false`.
- No runtime restart was required or performed for source implementation/testing.

## Remaining remote gates before DONE

1. Create the exact candidate commit and push the FMUX-012 branch after side-effect guard.
2. Require exact-head GitHub Verify; macOS / Windows x64 / native Windows ARM64 must succeed.
3. Perform scoped review against verified base and repair only real P0/P1 findings if any.
4. Commit/push evidence-state closure if exact-head run metadata changes durable state, then require Verify on that closure SHA.
5. Create/review exactly one PR targeting `main`.
6. Merge the exact reviewed head with head guard.
7. Require merged-main Verify on the resulting `main` commit.
8. Only then mark FMUX-012 DONE / MAIN VERIFIED and claim the next dependency-valid FMUX task.

## Exact-head attempt 1 — failed gates and targeted fixes

Candidate: `bae6bea5cf23a2577cd474068472de752cb1944e`
Verify run: `37175574357`
Result: FAIL; no PR was created and no merge occurred.

Failure decomposition:
- Windows x64: failed only `Verify FMUX Repository Intelligence presentation contract` because the historical FMUX-011 regression contract still required literal `State: ACTIVE / CLAIMED` after FMUX-011 had legitimately reached `DONE / MAIN VERIFIED`.
- Native Windows ARM64: same single stale FMUX-011 lifecycle assertion; subsequent steps were skipped by the workflow after that failure.
- macOS: static verification reached the native workflow, then integration compilation failed in `LocalMCPRuntime.swift` because `withPresentationServer` captured the implicitly non-escaping generic `body` parameter in a closure stored in `operation`.

Targeted fixes only:
- `tests/test_fmux_repository_intelligence_contract.ps1` now scopes lifecycle validation to the FMUX-011 graph section and accepts either the historical in-flight state `ACTIVE / CLAIMED` or the closed state `DONE / MAIN VERIFIED`. Targeted local rerun: PASS.
- `macos/LocalMCPRuntime.swift` marks the presentation helper closure parameter `@escaping`, matching how it is captured before synchronous dispatch. Native macOS compile/integration re-verification remains CI-only on this Windows host.

The failed run is fully completed. No other CI rerun was started while it was active, Windows implementation source was not changed, and runtime PID `17860` was not restarted.


## Exact-head attempt 2 — native verified / scoped review pass

Candidate: `edd996bd43642e8c5399a90ca14cb109db858fd1`
Verify run: `37176690710`
Result: SUCCESS on macOS, Windows x64, and native Windows ARM64.

Scoped review result: PASS; no P0/P1 remains.
- Desktop presentation bridge allowlist is exactly `pty_list`, `pty_read`, `pty_resize`, `pty_signal`, `pty_stop`.
- `pty_start` and `pty_write` remain outside presentation authority on both native stacks.
- Read windows remain bounded at 16 KiB and displayed output at 64 KiB.
- Terminal output is rendered only in the live terminal surface and is not copied into diagnostics/activity evidence.
- Policy metadata explicitly records `presentation_grants_authority=false`.
- Restart resume remains explicitly unsupported rather than synthesized.
- Runtime PID `17860` was not restarted.

Remaining closure gates: evidence-state-only closure commit -> push exact closure SHA -> exact-head Verify -> reviewed PR to `main` -> guarded merge -> merged-main Verify.
