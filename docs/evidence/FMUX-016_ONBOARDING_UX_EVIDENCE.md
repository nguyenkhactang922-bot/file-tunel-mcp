# FMUX-016 Onboarding UX Evidence

Date: 2026-10-04

## Task / base

- Task: `FMUX-016` Onboarding.
- Branch: `chatgpt/FMUX-016-onboarding`.
- Verified base main: `987c7f836830b55f019a786b0a7b218281d7ef99`.
- Dependency gate: FMUX-004 through FMUX-015 applicable surfaces are DONE / MAIN VERIFIED; FMUX-015 governance state-sync PR #55 merged as the verified base above and merged-main Verify `37215916252` succeeded across macOS / Windows x64 / native Windows ARM64.

## Frozen scope and authority boundary

FMUX-016 covers first-run setup, workspace selection, credential/connect, policy choice, real connection test, and completion handoff to Home.

The implementation adds no runtime/tool authority and creates no parallel credential store, policy authority, backend selector, or synthetic connection truth:

- Workspace configuration reuses the existing Workspaces / Settings controls and the existing shared-root validation.
- Policy choice reuses the existing server-owned local policy profiles.
- Windows credentials continue to use Windows Credential Manager; macOS credentials continue to use Keychain.
- Tunnel IDs and runtime start/connect continue through the existing connection/runtime path.
- `Test connection` starts the already-configured runtime only from an idle/failed state and succeeds only when the actual runtime state reports `Running` (all enabled runtimes on Windows; the configured runtime on macOS).
- Partial/transitioning runtime state is surfaced as truth and is not silently stopped/restarted by onboarding.
- `Finish setup` is enabled only after the real runtime connection test is satisfied, writes only a presentation-level completion marker, and hands off to Home.
- Legacy migration auto-marks onboarding complete only when a pre-existing setup is materially complete: secure saved credential + valid Tunnel ID + existing workspace directory.

## Cross-platform implementation

Windows WPF:

- Setup navigation + `OnboardingTab` with Workspace, Policy, Credential/Tunnel, Connection Test and Finish steps.
- `FileMcpSettings.OnboardingCompleted` is a presentation-only persistence marker serialized by the existing `SettingsStore`.
- Existing `Connect_Click`, validation, Credential Manager and runtime state remain authoritative.

macOS AppKit:

- Setup navigation + `onboarding` tab with the same truthful step model.
- `UserDefaults` key `onboardingCompleted` is presentation-only; the API key remains exclusively in the existing Keychain-backed storage.
- Existing `startTunnel`, configuration validation and `runtime.onStateChange` remain authoritative.

## Local verification

PASS on Windows host after final hardening:

- `tests/test_fmux_onboarding_contract.ps1`
- `tests/test_fmux_app_shell_contract.ps1`
- `tests/test_fmux_presentation_contract.ps1`
- `tests/test_project_state_contract.ps1`
- `git diff --check`
- `dotnet build windows/src/FileMCP.App/FileMCP.App.csproj -c Release --no-restore -warnaserror` -> 0 warnings / 0 errors.

CI wiring:

- `tests/test_fmux_onboarding_contract.ps1` is wired into Windows x64 and native Windows ARM64 Verify lanes.
- macOS native Swift typecheck/integration/build remains the platform authority. Local Windows host has no `swiftc`; this is an environment limitation, not a PASS or FAIL for macOS source. Exact-head GitHub Verify is required before PR.

## Runtime checkpoint

- Existing FileMCP runtime PID `17860` remains `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`.
- Runtime was not restarted for FMUX-016 implementation or local verification.

## Current state

`ACTIVE / LOCAL VERIFIED / EXACT-HEAD NATIVE VERIFY PENDING`.

Next lifecycle: scoped diff review -> exact candidate commit -> side-effect guard -> push exact head -> require macOS / Windows x64 / native Windows ARM64 Verify -> repair only a real failed stage if any -> evidence/state closure -> exact closure-head Verify -> one reviewed PR to `main` -> guarded merge -> verify the exact resulting `main` -> MAIN VERIFIED -> governance state-sync before claiming FMUX-017.
