# IDEA INBOX

## 2026-09-22 — FileMCP Observability / ChatCode-grade local dashboard

Raw idea captured from discussion:
- Add token in/out/total counters similar to ChatCode.
- Add input/output/total payload data.
- Add task/call/read/write/Git/command/error counters.
- Add time used / uptime.
- Add how many AI chats are currently working, idle, and live.
- Add per-chat/session detail and realtime activity graph.
- Support Today / Yesterday / 7 days / 30 days / custom period.
- Aggregate C/D/E/F while keeping per-drive breakdown.
- Keep one FileMCP desktop app.

Important truth constraint discovered during discussion:
- FileMCP sees MCP traffic, not full ChatGPT conversation/model usage.
- Token figures must therefore be explicitly estimated MCP payload tokens unless authoritative usage is ever supplied upstream.

Audit-side discovery, not yet coded:
- SafePathResolver currently mishandles a drive root such as D:\ when testing descendants because it appends an extra directory separator in the containment prefix. Root list works, nested file-tool paths can be rejected as outside. This is a P0 prerequisite task after design freeze.
