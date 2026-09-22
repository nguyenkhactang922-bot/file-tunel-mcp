# FPA-002 - Independent Design Review

Status: PASS WITH REQUIRED GUARDS

## Review round 1 - security

The logical-chat handle must never grant filesystem, Git, command, tunnel or credential authority. Tool execution must remain governed only by the existing shared-root, command-enable and Git-safe-mode controls.

Required guard: `_filemcp_chat` is metadata-only and is stripped before ordinary tool/skill validation.

## Review round 2 - privacy

Raw handles must not be logged or written to disk. Internal membership state stores SHA-256 only. Error text may say invalid/unknown handle but must not echo the handle.

## Review round 3 - resource bounds

A pure dictionary without TTL/cap would regress V11-001 lessons. macOS must use the same 4096-entry / 2-hour contract.

Because macOS has no V11 maintenance worker, expiration cannot rely on periodic cleanup. Lazy expiration must occur on connect/resume and resolve paths.

## Review round 4 - concurrency

Network workers are concurrent. The Swift correlation service must protect dictionary/counters with one private lock. Simplicity is preferred over lock-free complexity for a 4096-entry metadata map.

## Review round 5 - API parity

Appending only the connect tool is insufficient. Every operational/skill tool schema must expose optional `_filemcp_chat`, and the server must remove it before calling existing strict validators.

## Review round 6 - build parity

A new source file can silently pass local editing but fail CI if a `swiftc` list is missed. All build/dev/test/CI compile lists are part of the acceptance surface.

## Review conclusion

Proceed only with:

- separate Swift correlation service;
- bounded hash-only in-memory registry;
- exact server facade parity;
- explicit build-list regression;
- macOS runtime tests for create/resume/expiry/cap/facade stripping.
