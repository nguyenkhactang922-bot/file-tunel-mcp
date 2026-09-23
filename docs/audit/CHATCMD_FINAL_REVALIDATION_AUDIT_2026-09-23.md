# ChatCMD Final Revalidation Audit after Cross-Repo Comparison

Status: INDEPENDENT REVALIDATION COMPLETE
Date: 2026-09-23
Repository: https://github.com/int04/ChatCmd
Pinned commit retained: c20e134ad6b60ef12eee7231bcbca56f5252be45
Audit clone: D:\Tools\_audit\ChatCmd
Prior audit: docs/audit/CHATCMD_INDEPENDENT_MULTI_ROUND_INTEGRATION_AUDIT_2026-09-23.md
Purpose: re-evaluate earlier ChatCMD recommendations after Codex, OpenHands, Aider, Cline and Goose evidence.

## Revalidation R1 - canonical catalog remains a strong P0 reference

`crates/chatcmd-mcp/src/tool_catalog.rs` still provides the strongest directly relevant reference for:
- canonicalized tool schemas;
- protocol/catalog version;
- catalog hash;
- instruction hash/version;
- build identity;
- risk/operation/capability flags.

Cross-repo comparison did not reveal a better fit for FileMCP's two-native-runtime drift problem.

Amendment:
FileMCP cannot literally derive both C# and Swift schemas from one Rust router. Final design should use a language-neutral canonical manifest embedded/validated by both runtimes.

## Revalidation R2 - structured command runner remains valid, but durable idempotent registry is not automatically required

ChatCMD `CommandExecutionService` includes:
- explicit executable + argv;
- bounded environment/arguments/output;
- terminal state;
- execution IDs;
- source-state before/after;
- idempotency key and execution registry;
- artifact spillover.

FileMCP already has strong native ProcessRunner implementations. Codex/OpenHands evidence shows execution policy/backend isolation are separable concerns.

Final direction:
- ADD structured `exec_process` over existing ProcessRunner;
- ADD operation/evidence identity;
- DEFER durable command idempotency/registry unless real retry semantics require it;
- never pretend arbitrary side-effecting commands are safely idempotent merely because a key exists.

## Revalidation R3 - versioned editing becomes even more important

ChatCMD source/tests show:
- authenticated/opaque file version tokens;
- expected-version mutation;
- revalidation;
- non-overlapping edits;
- budgets/cancellation;
- atomic staging/publish;
- conflict tests with external writers;
- symlink-swap tests;
- pre/post-commit cancellation semantics.

Codex independently confirms no-follow/path-swap defense. Aider confirms model-friendly edit formats should sit above storage safety.

Final direction is stronger than ADR-0004:

`strong version identity + Mutation Guard + atomic apply_edits`

not merely "add version token".

## Revalidation R4 - shared budgets/cursors remain P0 and must include cooperative cancellation

ChatCMD's resource-budget model remains the strongest reference. Exact FileMCP source now shows search/list loops have hard caps but do not check request cancellation inside traversal.

Final direction:
- common ToolBudget;
- hard server caps;
- caller may only lower;
- usage/truncation reason;
- cursor continuation where useful;
- cancellation checks inside long loops.

## Revalidation R5 - policy is retained but amended by Codex sandbox evidence

ChatCMD approval/policy design is useful for server-owned authority. Codex demonstrates that policy is not isolation.

Final direction:
- server-owned policy profiles remain Phase A;
- execution backend/isolation becomes a separate architecture layer;
- no model self-elevation;
- normal `workspace-auto` operations can be pre-authorized by local config.

## Revalidation R6 - broad task/sub-agent architecture is rejected for FileMCP core

ChatCMD's sub-agent/report/lease/heartbeat architecture is technically substantial. Goose and Cline confirm the amount of session/task/persistence machinery required.

But FileMCP's product boundary and user law put orchestration in ChatGPT, not inside the bridge.

Final direction:
- REMOVE sub-agent runtime from the planned FileMCP core roadmap rather than merely "Phase C";
- a future product-level ADR may add it only if FileMCP is intentionally redefined as an agent runtime.

## Revalidation R7 - PTY stays optional later work

ChatCMD PTY remains useful for interactive CLIs/debuggers, but no cross-repo evidence makes it a prerequisite for deterministic build/test verification.

Final direction: DEFER to later phase after structured exec/evidence/policy.

## Revalidation R8 - ChatCMD persistence cannot be copied broadly

Cline/Goose comparison reinforces FileMCP privacy constraints. FileMCP may adopt metadata-only execution evidence but not broad task/conversation persistence.

## Revalidation R9 - browser/public-token decisions remain rejected

No later audit provided a reason to add ChatGPT DOM automation or public bearer-token MCP URLs to FileMCP. Secure Tunnel + loopback auth remains the narrower fit.

## Final ChatCMD-derived actions

| ChatCMD concept | Final direction for FileMCP |
|---|---|
| canonical catalog/hash/capability flags | ADAPT |
| structured command execution | ADAPT over existing ProcessRunner |
| command durable idempotency registry | DEFER |
| version tokens | ADAPT |
| atomic apply_edits | ADAPT |
| shared budgets/cursors | ADAPT |
| artifact spillover | DEFER |
| project context | ADAPT, separated from repo intelligence |
| policy/approval | ADAPT, sandbox separate |
| persistent PTY | DEFER |
| local task engine | REJECT from core |
| sub-agent runtime | REJECT from core |
| public token URL | REJECT |
| browser DOM bridge | REJECT |

## Independent conclusion

ChatCMD remains the most directly reusable architectural reference for execution correctness, versioned editing, budgets and catalog contracts. Cross-repo audit narrows rather than broadens the adoption: take those primitives, but explicitly exclude ChatCMD's broader agent/task/public-endpoint product layers from FileMCP core.
