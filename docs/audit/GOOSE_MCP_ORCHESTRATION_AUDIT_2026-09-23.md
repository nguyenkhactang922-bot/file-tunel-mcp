# Goose MCP Composition and Orchestration Audit for FileMCP

Status: INDEPENDENT SOURCE AUDIT COMPLETE
Date: 2026-09-23
Repository: https://github.com/aaif-goose/goose
Pinned commit: e678c3b64a1dfd3c262a6a2019f158d33d5dcab0
Audit clone: D:\Tools\_audit\Goose
Purpose: challenge ADR-0004 on MCP composition, extension filtering, recipes and sub-agent orchestration.

## Finding G1 - extension/tool composition is source-backed and mature enough to study

Source evidence:
- `crates/goose/src/agents/extension.rs` defines stdio, built-in, platform and streamable-HTTP extension configs;
- each extension can carry `available_tools` as an allowlist;
- `is_tool_available()` filters extension tools;
- `crates/goose-agent/src/tool.rs` detects duplicate tool names across providers and routes calls to the owning provider;
- ACP/custom request types preserve extension/tool configuration;
- tests cover extension config/tool filtering paths.

Value:
Goose demonstrates that a client/agent can safely compose multiple MCP/tool providers when it owns provider lifecycle, namespacing/filtering and secrets.

FileMCP product-fit question:
FileMCP is itself a focused MCP server. ChatGPT can already connect to multiple tools/connectors. Turning FileMCP into an MCP-of-MCP gateway would make it own:
- external server lifecycle;
- extension credentials;
- name conflicts;
- remote transports;
- OAuth/headers;
- provider health/retry;
- another policy surface.

Decision impact:
Do **not** make MCP composition part of FileMCP core. FileMCP should expose a precise catalog and coexist with other MCP servers. A separate future gateway product/ADR can revisit composition if a concrete user problem appears.

## Finding G2 - tool filtering belongs to authority/capability design even without composition

Goose `available_tools` shows the utility of advertising/exposing only a permitted subset of capabilities for a session/configuration.

FileMCP can reuse the concept without becoming an extension host:
- canonical catalog contains all supported tools/capabilities;
- active local policy computes effective availability;
- runtime authorization still independently enforces policy;
- hiding a tool is UX/capability minimization, not the only security check.

## Finding G3 - sub-agents are a substantial agent-runtime subsystem

Source evidence:
- `crates/goose/src/agents/subagent_handler.rs` constructs a separate Agent with its own provider/model/session/config;
- configured extensions are attached to the child;
- child has max-turns/cancellation;
- child conversation is accumulated and final output extracted;
- tool notifications carry sub-agent identity;
- `platform_extensions/summon.rs` provides delegation/background task lifecycle and task source discovery.

This is not a small MCP utility. It owns model calls, conversation history, child sessions, cancellation and tool authority.

## Finding G4 - Goose sub-agent persistence/content model conflicts with FileMCP's role

Goose is itself an agent. FileMCP's user-defined operating law is the opposite separation:

- ChatGPT Web = MAIN CODING AGENT / orchestrator;
- FileMCP = local execution bridge.

Adding Goose-like child agents inside FileMCP would duplicate orchestration, require model/provider/session content, and expand privacy/persistence boundaries.

Decision impact:
REJECT local sub-agent runtime from the current FileMCP master architecture. If the product goal changes later, require a new ADR/product boundary rather than treating it as a deferred implementation detail.

## Finding G5 - recipes are useful conceptually but FileMCP already has a lighter mechanism

Goose recipes package reusable workflow instructions/extensions. FileMCP already exposes Codex project skills from `.agents/skills` and the user's repository laws/state files drive the lifecycle.

Decision:
- KEEP FileMCP skill mechanism;
- ADAPT only provenance/hash/project-context behavior;
- do not add a second recipe engine unless a distinct executable-workflow requirement appears.

## Finding G6 - extension credentials reinforce separation of config from secret values

Goose resolves environment/secret keys separately from serialized extension configuration for sensitive fields. This is consistent with FileMCP's stronger existing Credential Manager/process-env rule.

Decision:
KEEP FileMCP secret boundary; no reason to import Goose config storage.

## FileMCP actions after Goose audit

| Capability | Preliminary action | Reason |
|---|---|---|
| canonical catalog/capability filtering | ADAPT | tool visibility can reflect local policy while authorization stays server-side |
| external MCP composition | REJECT from core | unnecessary provider/secret/lifecycle complexity |
| extension tool allowlists | ADAPT conceptually | useful for effective catalog filtering |
| Codex skills | KEEP + HARDEN | lighter than recipes; add provenance/hash |
| Goose recipes | REJECT as duplicate core subsystem | no distinct need beyond current skills/orchestration |
| local sub-agent runtime | REJECT | violates FileMCP bridge boundary and user orchestration law |
| child/background agent task state | REJECT from core | would require content/session persistence |

## Independent conclusion

Goose validates catalog filtering and provider composition as useful agent concepts, but it strengthens the case for **not** turning FileMCP into an agent platform. The master architecture should remain a hardened execution gateway with policy-filtered capabilities and leave multi-agent/MCP orchestration to ChatGPT or a separate future product layer.

## Evidence classification and final action

Pinned SHA: `e678c3b64a1dfd3c262a6a2019f158d33d5dcab0`
Pinned commit date: 2026-09-23T20:49:34Z
License: Apache-2.0
Overall evidence: **S1 - SHIPPED + SOURCE + TEST** for extension configuration/filtering and source-backed subagent orchestration inspected here.

Primary source paths:
- `crates/goose/src/agents/extension.rs`
- `crates/goose-agent/src/tool.rs`
- `crates/goose/src/agents/subagent_handler.rs`
- `crates/goose/src/agents/platform_extensions/summon.rs`
- related unit/integration tests under the same crates.

Additional verified properties:
- extension types include stdio, builtin, platform and streamable HTTP;
- `available_tools` is an explicit tool allowlist;
- streamable HTTP resolves OAuth client secret by key/env rather than storing the sensitive value inline;
- subagent/delegate runtime owns provider/model/session, max turns, cancellation, notifications and task result state;
- working directory is constrained relative to the parent session in delegate semantics;
- background task lifecycle includes wait/peek/cancel/result collection.

Final FileMCP actions:
- catalog/effective tool visibility filtered by server-owned policy: **ADAPT**;
- external MCP/extension composition inside FileMCP core: **REJECT**;
- Goose recipes as a second core workflow system: **REJECT**;
- local child-agent/subagent runtime: **REJECT** from current product boundary;
- FileMCP Codex skills: **KEEP + HARDEN** with provenance/hash/project-context behavior;
- existing secret boundary: **KEEP**.

Acceptance invariant for effective catalog filtering: hidden/visible tool metadata can reduce discoverability but can never be the sole authorization mechanism. Runtime policy must independently reject forbidden execution even if a caller forges a tool name/schema.
