# V11-009 - PRE-MERGE FINAL ACCEPTANCE EVIDENCE

Date: 2026-09-22
Status: ACTIVE - pre-merge gates complete; PR/merge/main verification pending

## OBS-013 prerequisite

PASS. Real ChatGPT connector exposed `filemcp_observability_connect`; the same opaque handle was resumed on a later user turn, normal FileMCP calls remained bound to the same SHA-256 durable session, and the raw handle was absent from SQLite/WAL/SHM. Exact correlated `AI chats` wording is enabled while unbound traffic remains separate.

## Final review findings

- `origin/main` is already an ancestor of the feature branch; no rebase/merge conflict is required before PR.
- `git diff --check origin/main...HEAD`: PASS.
- secret scan returned no API key/runtime key/tunnel-id matches in tracked source outside vendored/build output.
- NuGet vulnerable-package audit: no vulnerable packages reported.
- NuGet direct outdated audit: no direct updates reported.

## Release automation finding and fix

The first V11-009 package attempt correctly failed because the currently connected `FileMCP-release\FileMCP.exe` was locked by Windows. Killing that bridge from the active ChatGPT session would violate the live execution handoff.

`build_windows_app.ps1` now accepts a validated `-StagingName`, preserving the default `FileMCP-release` while allowing isolated final candidates such as `FileMCP-final`. This permits repeatable packaging without overwriting a running bridge.

The runtime restart integration test also uses an 8-second Windows-host allowance instead of 3 seconds; the production restart budget/backoff semantics are unchanged.

## Pre-merge package candidate

Command: `./build_windows_app.ps1 -Architecture x64 -StagingName FileMCP-final`

Result: PASS.

Archive: `dist/FileMCP-v0.4.0-windows-x64.zip`

SHA-256: `3C23BEE2198543CFE6D3C51FB134E31A82034B15FDDAC1FC9785F44603C17F23`

Packaged smoke PASS:

- WPF startup
- close-to-tray
- tunnel-client version
- native SQLite create/write/read
- optional OTLP provider
- OpenTelemetry redistribution notices

## Exact pre-merge worktree verification

- Release build with `-warnaserror`: PASS, 0 warnings, 0 errors.
- Full Windows runtime suite: PASS, 414 assertions.
- Isolated `FileMCP-final` package: PASS.
- Packaged app smoke: PASS.
- Final gate archive SHA-256: `3C23BEE2198543CFE6D3C51FB134E31A82034B15FDDAC1FC9785F44603C17F23`.
- NuGet vulnerable-package audit: no vulnerable packages reported.
- Direct-package outdated audit: no direct updates reported.

## Remaining V11-009 actions

1. Commit reviewed pre-merge changes.
2. Push branch and create/review PR.
3. Merge to `main`.
4. Checkout/pull `main` and rerun Release build/runtime/package smoke.
5. Record `MAIN VERIFIED` and close V11-009 in a final state-only change.
