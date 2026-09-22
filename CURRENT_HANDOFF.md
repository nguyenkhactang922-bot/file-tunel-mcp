# CURRENT HANDOFF

STATUS: V11-009 ACTIVE — FINAL REVIEW / PACKAGE / MERGE / MAIN VERIFICATION
BRANCH: chatgpt/OBS-001-observability-foundation
HEAD: 3033084
WORKTREE: CLEAN at handoff

## Completed

- FMR-001 PASS.
- OBS-001 through OBS-013 PASS.
- V11-001 through V11-008 PASS.
- Observability V1.1 OSS strengthening implementation and independent hardening are complete.

## Latest verified build

- Release ZIP: `dist/FileMCP-v0.4.0-windows-x64.zip`
- SHA-256: `5B511CC07ADC85D19F5F1C5B1E6CBFC0903FEF0AF8A0F8CFEBF8BFEB577DC44E`
- Release build: PASS, 0 warnings / 0 errors
- Full Windows runtime suite: PASS, 414 assertions
- Packaged WPF startup: PASS
- Close-to-tray: PASS
- Packaged tunnel-client: PASS
- Packaged native SQLite create/write/read: PASS
- Packaged optional OTLP provider: PASS
- Packaged OpenTelemetry license/notices: PASS
- NuGet vulnerability audit: PASS, no vulnerable packages reported
- Direct-package outdated audit: PASS, no direct updates reported

## V1.1 hardening result

The independent V11-008 audit found and fixed one real leak-class bug: connect-only logical sessions could become stale without ever becoming evictable because they had no workspace row. The fixed build passed:

- 24h-style correlation churn
- 24h-style connect-only session churn
- capacity pressure
- bulk SQLite retention (12k expired minute rows + 4k expired hour rows)
- 10k restart-storm decisions
- OTLP collector outage isolation
- raw OTLP protobuf privacy scan
- durable SQLite/WAL privacy regression
- full runtime/package regression

## OBS-013 historical blocker (RESOLVED)

The current ChatGPT conversation still exposes only the 18 legacy FileMCP tools. `filemcp_observability_connect` is not present in this conversation's connector schema.

The currently running FileMCP processes are also from the old deployed path:

`D:\Tools\FileMCP\dist\windows-x64\FileMCP\FileMCP.exe`

Do NOT terminate the currently connected bridge from inside this chat; doing so can sever FileMCP tool access mid-handoff.

## NEXT_EXACT_ACTION

V11-009 is ACTIVE: final review -> final package gate -> push branch -> PR/review -> merge main -> checkout/pull main -> Release build/runtime tests on main -> MAIN VERIFIED -> DONE.


LIVE DESKTOP RECONNECT CHECK (2026-09-22):
- Old FileMCP processes are gone.
- Exactly one upgraded process is running: D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe (PID 3352 at verification time).
- Its bundled tunnel-client is running as its child process.
- The upgraded process owns 127.0.0.1:8008.
- Verified release ZIP SHA-256 remains 5B511CC07ADC85D19F5F1C5B1E6CBFC0903FEF0AF8A0F8CFEBF8BFEB577DC44E.
- This existing ChatGPT conversation still exposes the old 18-tool FileMCP connector schema; filemcp_observability_connect is not present.
- NEXT_EXACT_ACTION: open a fresh ChatGPT conversation while the upgraded FileMCP-release process is running, confirm filemcp_observability_connect appears, then execute OBS-013 live proof. No code/audit work should be repeated.

OBS-013 LIVE PROOF STAGE A (2026-09-22):
- Fresh ChatGPT connector schema now exposes 19 tools including filemcp_observability_connect.
- Real ChatGPT handle creation/resume and _filemcp_chat propagation through read_file/git_status/run_command PASS.
- Durable bound session hash verified; raw handle absent from DB/WAL/SHM.
- Remaining frozen-spec gate: one subsequent user turn must reuse the same handle and remain bound to the same durable session before OBS-013 can be marked PASS / exact AI-chat wording enabled.

OBS-013 PASS (cross-turn live ChatGPT proof complete):
- Same logical handle resumed successfully on a later user turn.
- Normal FileMCP call remained bound to the same durable SHA-256 session.
- Raw handle remained absent from DB/WAL/SHM.
- Exact correlated AI-chat wording is now enabled; unbound traffic remains separate and is never counted as a chat.
- NEXT_EXACT_ACTION: V11-009 final review/package/PR/merge/main verification.

FINAL PRE-MERGE PACKAGE CANDIDATE:
- Built using isolated staging `FileMCP-final` so the currently connected release bridge is not overwritten.
- ZIP SHA-256: 3C23BEE2198543CFE6D3C51FB134E31A82034B15FDDAC1FC9785F44603C17F23.
- Packaged WPF/SQLite/tunnel-client/OTLP/notices smoke: PASS.

UPSTREAM MERGE PERMISSION BLOCKER:
- PR #2 is open, clean and mergeable.
- `nguyenkhactang922-bot` has READ permission on `dongttfd/file-tunel-mcp`; push returned 403 and merge API is unavailable.
- Local merged-main candidate is VERIFIED: build 0/0, 414 assertions, package/app smoke PASS.
- NEXT_EXACT_ACTION: merge PR #2 using an upstream account with WRITE/MAINTAIN permission, then checkout/pull `main` and rerun main gates before marking V11-009 PASS / MAIN VERIFIED.
