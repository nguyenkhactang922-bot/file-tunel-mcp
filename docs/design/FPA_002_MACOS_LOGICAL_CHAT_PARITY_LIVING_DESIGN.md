# FPA-002 - macOS Logical-Chat Parity Living Design

Status: DESIGN COMPLETE - pending freeze

## Idea capture

The whole-repo audit proved that Windows advertises 19 MCP tools while macOS advertises 18. The missing tool is `filemcp_observability_connect`. Windows also exposes the reserved `_filemcp_chat` metadata facade on normal tools; macOS does not.

The product will preserve cross-platform MCP-surface parity rather than narrowing the product claim to Windows-only behavior.

## Scope

Port the logical-chat correlation contract to macOS:

- same opaque handle format;
- same create/resume semantics;
- same bounded capacity and TTL;
- same authority-neutral behavior;
- same `_filemcp_chat` facade on normal tools and skills;
- raw handle never persisted or logged;
- legacy and modern MCP both advertise/call the tool.

Out of scope:

- macOS SQLite observability dashboard;
- OTLP;
- durable session UI;
- tunnel restart/backoff (FPA-003);
- changing filesystem/Git/command authority.

## Current Windows truth

- handle prefix: `chat_`;
- 32 random bytes -> Base64URL without padding -> 43 chars;
- final handle length: 48 chars;
- max known handles: 4096;
- retention: 2 hours;
- storage key: SHA-256 of the raw handle;
- unknown normal-tool correlation is treated as unbound, not an authorization failure;
- unknown handle passed to the connect/resume tool is an error;
- facade metadata is removed before strict tool argument validation.

## macOS topology constraints

Swift sources are compiled explicitly by:

- `build_macos_app.sh`;
- `run_macos_dev.sh`;
- `.github/workflows/verify.yml`;
- several `swiftc` invocations inside `tests/test_swift_runtime.sh`.

A new Swift source file therefore requires all compile lists to be updated in the same task.
