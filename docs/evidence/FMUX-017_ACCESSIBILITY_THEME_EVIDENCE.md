# FMUX-017 Accessibility / Keyboard / Theme Evidence

Date: 2026-10-05
Task: FMUX-017 Accessibility / Keyboard / Theme Enforcement
Branch: `chatgpt/FMUX-017-accessibility`
Claim base: verified main `680b426fb076e9ab0da249a41eda508aa7d5b760`
State at this checkpoint: `ACTIVE / LOCAL VERIFIED`

## Frozen acceptance enforced

- keyboard-first navigation and logical focus order;
- visible keyboard focus;
- semantic accessible names/descriptions;
- text/non-text contrast suitable for WCAG-AA expectations;
- Windows system light/dark/high-contrast compatibility;
- macOS native system appearance/semantic-color behavior;
- reduced-motion respect;
- scaling/reflow without clipping critical controls.

## Implementation

### Windows WPF

- application semantic brushes are remapped from the current Windows app theme;
- `SystemParameters.HighContrast` maps presentation brushes to Windows system colors;
- `SystemEvents.UserPreferenceChanged` and system-parameter changes refresh theme resources at runtime;
- the app/window and remaining diagnostic/status literals use semantic `DynamicResource` brushes;
- the shared keyboard focus visual is explicit and applied to the window-wide Button style;
- existing navigation `AutomationProperties.Name` coverage remains authoritative;
- the existing resizable window remains the scaling/reflow boundary.

### macOS AppKit

- navigation buttons receive explicit accessibility labels/help while keeping native controls;
- navigation buttons remain keyboard-focusable and the window recalculates its native key-view loop;
- the main window is resizable and has a minimum useful content size;
- no app/window appearance override is introduced, so AppKit native semantic colors continue to follow system appearance/contrast;
- the existing loading-border animation is suppressed when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true.

No runtime/tool authority, policy, credential, execution, PTY, Git, filesystem, or network permission was expanded.

## Contract / CI hardening

Added `tests/test_fmux_accessibility_theme_contract.ps1` and wired it into both Windows x64 and native Windows ARM64 Verify lanes. The contract fail-closes on loss of:

- Windows system theme/high-contrast hooks;
- semantic theme resources / explicit focus treatment;
- representative navigation accessible names;
- Windows/macOS resize/reflow guarantees;
- macOS navigation accessibility + system appearance behavior;
- reduced-motion enforcement;
- valid FMUX-017 lifecycle/branch authority.

## Local verification

PASS:

- `tests/test_fmux_accessibility_theme_contract.ps1`
- `tests/test_fmux_app_shell_contract.ps1`
- `tests/test_fmux_presentation_contract.ps1`
- `tests/test_project_state_contract.ps1`
- `git diff --check`
- `dotnet build windows/FileMCP.Windows.sln -c Release --no-restore -warnaserror` -> 0 warnings / 0 errors

Build-fix history kept scoped: initial WPF compile exposed ambiguous `Color` / `SystemColors` imports; only the WPF media/system-color aliases were corrected, then the same failed build stage passed. No unrelated stage was rerun for that failure.

macOS native compile/build remains pending exact-head GitHub Verify because this host is Windows and has no native AppKit compiler authority.

## Runtime checkpoint

Runtime truth at this checkpoint:

- PID `14804`
- executable `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`
- runtime was not restarted for FMUX-017.

Historical state references to PID `17860` are stale and superseded by this runtime checkpoint.

## Next exact action

Scoped review -> exact candidate commit -> side-effect guard remote branch/PR -> push exact head -> require three-lane Verify (macOS / Windows x64 / native Windows ARM64). If exact-head Verify passes, write evidence/state-only closure head -> verify closure SHA -> one reviewed PR -> guarded merge -> exact merged-main Verify. FMUX-018 stays blocked until FMUX-017 and its governance closure are MAIN VERIFIED.
