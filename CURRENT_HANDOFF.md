# CURRENT HANDOFF

STATUS: BLOCKED ON OBS-013 LIVE CHATGPT CONNECTOR PROOF
BRANCH: chatgpt/OBS-001-observability-foundation
HEAD: fdd7de1
WORKTREE: CLEAN at handoff

## Completed

- FMR-001 PASS.
- OBS-001 through OBS-012 PASS.
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

## Current live blocker

The current ChatGPT conversation still exposes only the 18 legacy FileMCP tools. `filemcp_observability_connect` is not present in this conversation's connector schema.

The currently running FileMCP processes are also from the old deployed path:

`D:\Tools\FileMCP\dist\windows-x64\FileMCP\FileMCP.exe`

Do NOT terminate the currently connected bridge from inside this chat; doing so can sever FileMCP tool access mid-handoff.

## NEXT_EXACT_ACTION

1. On the Windows desktop, exit the old FileMCP instance(s) from the tray.
2. Start the upgraded build: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe` (or the executable extracted from the verified ZIP above).
3. Reconnect/refresh the ChatGPT FileMCP connector; if the existing chat keeps its old registered schema, open a fresh chat after the upgraded bridge is running.
4. Confirm the connector tool registry contains `filemcp_observability_connect`.
5. Call `filemcp_observability_connect` once without an id to obtain a logical chat handle.
6. Perform normal FileMCP calls while propagating that handle in `_filemcp_chat`.
7. Verify the dashboard shows one bound observed session and that durable SQLite identity is SHA-256 only (no raw handle).
8. Mark OBS-013 PASS.
9. CLAIM V11-009: final review -> final package gate -> merge to main -> checkout/pull main -> Release build/runtime tests on main -> MAIN VERIFIED -> DONE.

Do not enable exact AI-chat wording before step 7 proves the real ChatGPT connector propagates the handle reliably.
