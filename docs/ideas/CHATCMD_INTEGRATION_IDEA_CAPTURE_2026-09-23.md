# ChatCMD Integration Idea Capture

Status: CAPTURED - DESIGN TRACK ONLY
Date: 2026-09-23
Target repository: FileMCP
External reference: https://github.com/int04/ChatCmd
Pinned ChatCMD audit commit: c20e134ad6b60ef12eee7231bcbca56f5252be45
FileMCP baseline when this design track started: 7b24d1124e59103f7acad8f8c9a81271efb4fb0e

## User intent

Evaluate ChatCMD independently and critically to determine which ideas or subsystems could materially improve FileMCP. Do not assume that a feature is good merely because ChatCMD implements it. Do not merge or rewrite FileMCP around ChatCMD. Record the findings and a safe integration path in the FileMCP repository before any feature implementation.

FPA-004 remains a separate release-scope matter and is not part of this integration design track.

## Non-negotiable FileMCP invariants

Any future integration must preserve all existing FileMCP boundaries:

- MCP listeners remain loopback-only.
- OpenAI Secure MCP Tunnel remains the preferred remote access path.
- Runtime auth tokens remain in Credential Manager / Keychain or transient process environment.
- Shared-root containment and reparse/symlink defenses may only become stronger.
- Git safe mode, disabled hooks/signing in safe mode, environment sanitation, and external metadata containment may only become stronger.
- Observability remains metadata/counter oriented. Prompt/chat text, tool arguments, commands, file contents, Git messages, cookies and bearer credentials must not be persisted by default.
- Cross-platform Windows/macOS parity remains an acceptance requirement for common tools.
- Existing run_command compatibility may remain, but a new safer structured execution primitive may coexist with it.
- No browser DOM automation, cookie extraction or unofficial ChatGPT-session control is required for FileMCP.
- No public token-in-URL endpoint is required for FileMCP.

## Design question

Which ChatCMD capabilities should FileMCP:

1. adopt as a concept and reimplement natively;
2. adopt only after prerequisite foundations exist;
3. keep as optional future work;
4. explicitly reject because they weaken FileMCP's trust model, privacy contract or maintainability?

## Required design outputs

This track is complete only when the repository contains:

- an independent multi-round audit;
- exact ChatCMD-source to FileMCP-source mapping;
- a solution/decision matrix;
- a frozen architecture decision;
- a dependency/task graph with acceptance evidence;
- explicit rejection decisions for unsafe or unsuitable ChatCMD subsystems.

Idea capture is not permission to code.
