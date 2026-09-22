# FPA-002 - Implementation Task Graph

Architecture: `docs/design/FPA_002_FROZEN_ARCHITECTURE.md`

```text
FPA-002A correlation service
        |
        v
FPA-002B MCP facade/schema integration
        |
        +-------------------+
        v                   v
FPA-002C service tests   FPA-002D protocol/facade tests
        \                   /
         +--------+----------+
                  v
FPA-002E build/dev/CI compile-list parity
                  |
                  v
FPA-002F macOS CI + docs + evidence
```

| Task | Depends | Acceptance |
|---|---|---|
| FPA-002A | freeze | hash-only bounded Swift service, 4096 cap, 2h TTL, secure random, format parity |
| FPA-002B | 002A | connect tool + `_filemcp_chat` facade; metadata stripped before validators; no authority change |
| FPA-002C | 002A | format/resume/invalid/unknown/TTL/cap tests |
| FPA-002D | 002B | legacy+modern tools/list/call facade tests |
| FPA-002E | 002A | every Swift compile list includes new source; source/build contract test or equivalent CI assertion |
| FPA-002F | 002C,002D,002E | macOS warnings-as-errors, integration tests, app build, evidence, README parity |

NEXT IMPLEMENTATION ACTION: CLAIM FPA-002A.
