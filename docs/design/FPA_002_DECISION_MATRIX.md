# FPA-002 - Solution Decision Matrix

| Option | Security | Maintainability | Product parity | Scope risk | Decision |
|---|---|---|---|---|---|
| Document observability as Windows-only | Good | Easy | Fails current parity goal | Low | REJECT |
| Inline correlation implementation inside LocalMCPServer.swift | Good | Weak: grows monolith | Good | Low | REJECT |
| Separate LogicalChatCorrelation.swift + server facade | Strong | Strong | Strong | Low/medium | SELECT |
| Port full Windows observability stack to macOS now | Potentially strong | Large change | Strongest | High | DEFER |

## Selected approach

Create `macos/LogicalChatCorrelation.swift` using only Apple/native runtime facilities:

- Foundation;
- Security for cryptographic random bytes;
- CryptoKit SHA-256.

No third-party Swift package is added.

## Why not full observability now

FPA-002 exists to repair the MCP capability contract. Full macOS persistence/dashboard/OTLP would combine multiple architectural initiatives and make verification harder. The facade is designed so future macOS observability can consume the same session hash without changing the ChatGPT-facing contract.
