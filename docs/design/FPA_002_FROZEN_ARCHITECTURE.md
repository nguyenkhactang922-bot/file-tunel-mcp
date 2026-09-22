# FPA-002 - FROZEN ARCHITECTURE

Status: FROZEN
Date: 2026-09-22

## Product decision

FileMCP retains cross-platform MCP tool-surface parity. macOS will implement the same logical-chat facade as Windows.

## Frozen correlation contract

- Prefix: `chat_`.
- Random entropy: 32 bytes from `SecRandomCopyBytes`.
- Encoding: Base64URL, no `=` padding.
- Valid payload length: 43 characters.
- Registry key: lowercase SHA-256 hex of the full raw handle.
- Raw handle is returned to the caller but never stored in the registry.
- Capacity: 4096 hashes.
- TTL: 2 hours from last successful create/resume/resolve touch.
- Synchronization: private `NSLock`.
- Expired entries are lazily removed on connect/resume/resolve/cleanup.
- Capacity pressure evicts least-recently-seen hashes.
- Connect with no ID creates a new handle.
- Connect with a valid known ID resumes and returns `resumed=true`.
- Connect with malformed/unknown ID returns a tool error.
- Normal tool call with known `_filemcp_chat` touches the session.
- Normal tool call with absent/malformed/unknown metadata remains unbound and continues normally.

## Frozen server integration

- Add `LogicalChatCorrelationService` as a process-local member of `LocalMCPServer`.
- `allToolDefinitions()` applies a correlation facade schema to every normal filesystem/Git/command/skill tool.
- Append `filemcp_observability_connect` after normal+skill tool definitions.
- The connect tool is read-only, non-destructive, closed-world.
- Ordinary call path copies arguments to a mutable dictionary, removes `_filemcp_chat`, resolves/touches it, then invokes existing tool/skill code.
- Existing strict argument validation remains unchanged.
- No authority is derived from the correlation result.
- No raw handle appears in logs/errors.

## Frozen file topology

New:
- `macos/LogicalChatCorrelation.swift`.

Must update:
- `build_macos_app.sh`;
- `run_macos_dev.sh`;
- `.github/workflows/verify.yml`;
- relevant `swiftc` commands in `tests/test_swift_runtime.sh`;
- README source tree if it enumerates Swift files.

## Frozen verification

Service tests:
- generated handle format;
- resume;
- malformed handle rejection;
- unknown handle rejection;
- resolve/touch;
- TTL expiration;
- capacity pressure remains <=4096.

MCP tests:
- tools/list contains `filemcp_observability_connect`;
- normal tool input schemas contain `_filemcp_chat`;
- connect returns structuredContent with handle + resumed;
- a normal tool succeeds with a valid handle;
- a normal tool still succeeds with unknown metadata (unbound semantics);
- reserved metadata is not forwarded to strict tool validation;
- legacy and modern paths both work.

Build tests:
- Swift warnings-as-errors typecheck;
- full Swift runtime integration suite;
- macOS app build on GitHub macOS runner.

Any change to authority, durable persistence, handle format, cap or TTL requires a new review/freeze.
