# FMUX-018 Performance + Visual Consistency Evidence

Status: LOCAL VERIFIED
Date: 2026-10-05
Branch: `chatgpt/FMUX-018-performance-visual-consistency`
Claim base: verified main `6f5a14492d99e00d202d793eeb1525141aa0cd92`

## Frozen authority

FMUX-018 verifies the frozen product requirements for live-list performance, bounded rendering, token drift, layout consistency and startup/render regressions. The frozen design forbids arbitrary feature-view product color literals, requires background refresh not to steal focus, and forbids auto-scrolling after the user moves away from live tail. The repaired audit additionally requires bounded in-memory windows, virtualized/list-efficient rendering, throttled/coalesced refresh, and no forced live-tail.

## Audit matrix

| Area | Before | Finding / repair | Local evidence |
| --- | --- | --- | --- |
| Windows live collections | Activity 500; Changes 250; Evidence 500; Repository 100; Artifact batches 100; Terminal display 64 Ki chars with 16 KiB reads | Bounds retained; DataGrid row virtualization retained across live/data surfaces | `test_fmux_performance_visual_consistency_contract.ps1` PASS; structured-activity and terminal contracts PASS |
| macOS live collections | Same bounded event windows and Terminal limits | Bounds retained; native `NSTableView` remains list-efficient | FMUX-018 contract PASS; terminal/activity contracts inspect parity |
| Windows refresh cost | Selected live grids and Diagnostics text could update for each log callback | Added one pending background presentation refresh; bursts coalesce before live views render | FMUX-018 contract PASS; WPF Release build PASS |
| macOS refresh cost | Log text was coalesced at 50 ms, but Activity/Changes/Evidence/Repository/Artifacts still reloaded per callback | Reused the 50 ms log flush to coalesce selected live-event view refreshes | FMUX-018 contract PASS; native Swift typecheck/build delegated to exact-head Verify |
| Hidden Diagnostics rendering | Large bounded log model could still trigger text layout while Diagnostics was hidden | Windows/macOS render Diagnostics buffer only while the Diagnostics/log tab is selected; opening the tab flushes current model | Source review + FMUX-018 gate |
| Windows Terminal live-tail | `ScrollToEnd()` was unconditional after every PTY poll | Added `ApplyTextPreservingLiveTail`; follow only if the view was already at tail, otherwise restore prior offset | FMUX-018 gate PASS; WPF build PASS |
| macOS Terminal live-tail | `scrollToEndOfDocument(nil)` was unconditional | Added `replaceTextPreservingLiveTail` with prior viewport preservation | FMUX-018 gate PASS; native Verify pending |
| Diagnostics live-tail | Windows/macOS logs forced live-tail | Same preserve-live-tail behavior now applies to Diagnostics | FMUX-018 gate PASS |
| Windows product palette drift | `Gray`, `#D8D8D8`, `#666666`, and raw chart colors existed in feature XAML | Replaced with semantic `FileMcp*Brush` resources; chart series use semantic info/success brushes | raw-color scan = 0; accessibility/theme contract PASS |
| macOS code-surface palette drift | Fixed calibrated dark background + white text | Replaced with native `.textBackgroundColor` / `.textColor`; action tint uses semantic selected-control text color | fixed calibrated-code-surface scan = 0; accessibility/theme contract PASS |
| Startup/render regression | Existing Verify already performs packaged Windows startup/window/tray/single-instance smoke and native macOS typecheck/build/package | No duplicate launcher added; new FMUX-018 contract is wired into both Windows native Verify lanes | FMUX-018 contract PASS; local WPF build PASS; exact-head native Verify pending |

## Test-first checkpoint

The new `tests/test_fmux_performance_visual_consistency_contract.ps1` was run before implementation and correctly failed on the missing Windows coalesced-refresh invariant (`_livePresentationRefreshScheduled`). After the targeted repairs it passes.

## Local verification

PASS:
- `tests/test_fmux_performance_visual_consistency_contract.ps1`
- `tests/test_fmux_accessibility_theme_contract.ps1`
- `tests/test_fmux_structured_activity_contract.ps1`
- `tests/test_fmux_terminal_pty_contract.ps1`
- `tests/test_fmux_app_shell_contract.ps1`
- `tests/test_project_state_contract.ps1`
- `git diff --check`
- `dotnet build windows/src/FileMCP.App/FileMCP.App.csproj -c Release -r win-x64 --no-restore`
  - 0 warnings
  - 0 errors

## Runtime / side-effect guard

The existing FMG026-ready runtime PID `14804` was not restarted. No production/API/database/deploy side effect was performed. The FMUX-018 claim checkpoint remains local-only until the candidate is committed and remote branch/PR guards are checked.

## Remaining lifecycle

1. mark FMUX-018 `ACTIVE / LOCAL VERIFIED` in durable state;
2. scoped diff review + state contract;
3. commit candidate;
4. side-effect guard remote branch/PR/main;
5. push exact candidate head;
6. require three-lane exact-head Verify (macOS / Windows x64 / native Windows ARM64);
7. one reviewed PR;
8. guarded merge;
9. exact merged-main Verify;
10. governance state-sync to MAIN VERIFIED;
11. claim FMUX-019.
