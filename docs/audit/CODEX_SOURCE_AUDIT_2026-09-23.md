# CODEX SOURCE AUDIT - 2026-09-23

Status: COMPLETE SOURCE AUDIT FOR R2
Reference repository: https://github.com/openai/codex.git
Pinned SHA: cb1eea3e98ebc433ab5f9c12ce043e979d1902df
Pinned commit date: 2026-09-23T15:15:58Z
License: Apache-2.0
Audit clone: D:\Tools\_audit\Codex

This audit is source-first and is an input to the final FileMCP cross-repository architecture audit. It is not authorization to implement feature code.

## Executive result

Codex materially strengthens the case for server-owned execution policy, explicit filesystem/network sandbox policy, bounded process lifecycle, project-instruction provenance and immutable permission authority. It does not overturn the FileMCP direction toward a structured executable-plus-argv MCP primitive, optimistic file versioning or atomic expected-version edits.

Several Codex subsystems are deliberately not suitable for direct FileMCP adoption: broad thread/rollout persistence, approval-heavy per-call UX as the default operating mode, account-entitlement plumbing, and a full Codex session/task runtime.

The most important cross-reference result is:

```text
Codex proves sandbox/policy can be a first-class execution boundary.
ChatCMD proves structured process/version/evidence contracts can be first-class coding-agent contracts.
FileMCP should combine selected properties without becoming either product.
```

## Capability card CDX-01 - Filesystem/network sandbox policy

**Capability:** explicit sandbox and permission profile model
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1 - SHIPPED + SOURCE + TEST
**Source paths:**
- codex-rs/protocol/src/protocol.rs
- codex-rs/core/src/tools/sandboxing.rs
- codex-rs/core/src/unified_exec/stdin_approval.rs
- codex-rs/windows-sandbox-rs/
- codex-rs/linux-sandbox/
- codex-rs/core/tests/suite/windows_sandbox.rs
- codex-rs/core/src/tools/sandboxing_tests.rs

**Tests/source proof:**
- SandboxPolicy includes danger-full-access, read-only, external-sandbox and workspace-write.
- Network access is represented separately.
- writable roots carry protected metadata/read-only subpaths.
- denied-read restrictions prevent unsafe unsandboxed escalation.
- Windows sandbox selection and filesystem/network approval behavior have dedicated tests.

**What problem it solves:** reduces the authority of arbitrary model-driven process execution beyond simple path validation at the FileMCP tool layer.

**Trust boundary introduced:** OS sandbox implementation plus server-owned permission profile and optional approval/escalation path.

**Persistent data introduced:** policy/config state, but sandbox enforcement itself need not persist task content.

**Failure modes:**
- platform-specific sandbox setup failures;
- semantic mismatch across Windows/macOS/Linux;
- incorrect escalation can silently widen filesystem/network authority;
- sandbox policy can become confusing when combined with user approvals.

**Cross-platform implications:** high. Codex carries separate platform implementations; FileMCP must not claim a common sandbox until Windows and macOS implementations have equivalent acceptance evidence.

**Performance implications:** process launch/setup overhead and added policy evaluation.

**Migration/compatibility cost:** medium/high if made mandatory; lower if introduced later as optional server-owned execution mode.

**FileMCP equivalent today:** shared-root containment, Git safe mode, command enablement and process-tree cleanup, but no OS-level general command sandbox.

**Gap in FileMCP:** process execution can still use the host authority of the FileMCP user inside the allowed tool/process model.

**Primary final action:** DEFER pending OpenHands comparison, with strong ADAPT candidate status for a future optional sandbox layer.

**Prerequisites:** structured exec_process, server-owned policy profiles, cross-platform sandbox feasibility, no weakening of existing path/Git controls.

**Required FileMCP test evidence:** explicit read/write/network deny tests, metadata path protection, escalation-negative tests, Windows/macOS parity and rollback.

**Open questions:** whether the product should remain host-first with strong policy or add an optional isolated mode; whether sandbox should be mandatory for only selected risk classes.

## Capability card CDX-02 - Approval and escalation policy

**Capability:** server-owned approval requirement and escalation control
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/protocol/src/protocol.rs
- codex-rs/core/src/tools/sandboxing.rs
- codex-rs/core/tests/suite/exec_policy.rs
- codex-rs/core/src/tools/sandboxing_tests.rs
- codex-rs/core/tests/suite/network_approval.rs

**Tests/source proof:**
- AskForApproval modes include UnlessTrusted, OnRequest, Granular and Never.
- ExecApprovalRequirement is Skip / NeedsApproval / Forbidden.
- granular policy can auto-reject categories instead of prompting.
- denied-read policy survives escalation.
- network approval is evaluated separately.
- tests cover untrusted git status, destructive rm policy, migration and granular denial/prompt behavior.

**What problem it solves:** separates model intent from authority to execute a risky action.

**Trust boundary introduced:** policy owner/reviewer is authoritative; model request is not.

**Persistent data introduced:** rules/config may persist; no need to persist raw command content in FileMCP.

**Failure modes:** approval fatigue, policy drift, overly broad remembered approvals.

**Cross-platform implications:** policy semantics can be common even when enforcement differs.

**Performance implications:** minimal evaluation cost; human prompting can dominate workflow latency.

**Migration/compatibility cost:** medium.

**FileMCP equivalent today:** EnableCommands plus hard safety checks; no risk-class policy profile.

**Gap in FileMCP:** coarse enable/disable cannot distinguish ordinary workspace operations from high-risk execution.

**Primary final action:** ADAPT.

**Target FileMCP direction:** server-owned restricted / workspace-auto / custom profiles; normal pre-authorized workspace operations should not require per-call clicks. The model must never self-elevate.

**Prerequisites:** canonical capability/risk classification and structured execution.

**Required FileMCP test evidence:** model self-elevation rejection, profile downgrade/upgrade rules, destructive/network risk classification, persistence safety and parity.

**Open questions:** exact relationship between optional future OS sandbox and policy profile.

## Capability card CDX-03 - Unified execution lifecycle

**Capability:** bounded process lifecycle with structured internal argv, cancellation, timeout and optional resumable process state
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/core/src/unified_exec/mod.rs
- codex-rs/core/src/unified_exec/oneshot.rs
- codex-rs/core/src/unified_exec/process.rs
- codex-rs/core/src/unified_exec/process_manager.rs
- codex-rs/core/tests/suite/unified_exec.rs
- codex-rs/core/tests/suite/unified_exec_process_events.rs
- codex-rs/core/src/unified_exec/process_tests.rs

**Tests/source proof:**
- internal ExecCommandRequest carries command as Vec<String>.
- max active processes is bounded at 64.
- output is bounded; yield time is clamped.
- one-shot cancellation terminates the exact process handle.
- timeout/cancel/failure terminal states are separated.
- interactive process store exists for long-lived terminal behavior.

**What problem it solves:** robust lifecycle and evidence for process execution.

**Trust boundary introduced:** shared orchestrator combines policy, sandbox and process lifecycle.

**Persistent data introduced:** process/session state during lifetime; Codex broader session model can persist more.

**Failure modes:** process-store leaks, shell interpretation ambiguity at model-facing boundary, policy/sandbox retry complexity.

**Cross-platform implications:** significant but proven in Codex product.

**Performance implications:** bounded memory/output and managed concurrency.

**Migration/compatibility cost:** low for FileMCP because native ProcessRunner already has executable + argv, timeout, bounded output and process-tree/group cleanup.

**FileMCP equivalent today:** ProcessRunner C#/Swift is strong internally; MCP exposes run_command as shell-string compatibility.

**Gap in FileMCP:** no first-class structured MCP tool exposing executable + arguments array and stable structured result.

**Primary final action:** ADD structured exec_process while KEEPING current ProcessRunner and KEEPING run_command for compatibility.

**Prerequisites:** canonical catalog and result envelope.

**Required FileMCP test evidence:** no shell interpretation, argv fidelity, cwd containment, env denylist, timeout/cancel/tree cleanup, output budget, Windows/macOS parity.

**Open questions:** persistent PTY remains separate Phase B.

## Capability card CDX-04 - apply_patch engine

**Capability:** model-oriented multi-hunk patch parser and mutation engine
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/apply-patch/src/lib.rs
- codex-rs/apply-patch/src/parser.rs
- codex-rs/apply-patch/src/file_update.rs
- codex-rs/apply-patch/src/streaming_parser.rs
- codex-rs/apply-patch/tests/suite/tool.rs

**Tests/source proof:**
- add/delete/update/move and multi-hunk parsing;
- overlap and malformed-patch tests;
- CRLF and trailing-newline behavior;
- binary/UTF-8 failure cases;
- explicit applied delta tracking;
- explicit tests show partial changes can remain after later failure.

**What problem it solves:** ergonomic model-driven patch application.

**Trust boundary introduced:** patch parser plus filesystem abstraction/sandbox.

**Persistent data introduced:** none inherently.

**Failure modes:** partial multi-file side effects; no stale-read expected-version precondition; move can write destination before source removal fails.

**Cross-platform implications:** patch text semantics are portable, filesystem mutation details are not.

**Performance implications:** efficient relative to whole-file model rewriting for many edits.

**Migration/compatibility cost:** medium if used as primary FileMCP editing primitive.

**FileMCP equivalent today:** whole-file write_file, no apply_edits.

**Gap in FileMCP:** no version-checked targeted editing.

**Primary final action:** DEFER Codex-style patch syntax as an optional higher layer; ADD the stronger lower-level versioned atomic apply_edits contract first.

**Prerequisites:** file version tokens, expected-version mutation and atomic text update semantics.

**Required FileMCP test evidence:** stale version rejection, non-overlap, dry-run, atomic commit/fault injection, newline/BOM behavior and reparse containment.

**Open questions:** whether a later model-friendly patch parser should compile down to apply_edits.

## Capability card CDX-05 - Project instruction discovery and provenance

**Capability:** hierarchical AGENTS.md discovery with provenance and byte budget
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/core/src/agents_md.rs
- codex-rs/core/src/agents_md_tests.rs
- codex-rs/core/src/agents_md_manager.rs
- codex-rs/codex-home/src/instructions/

**Tests/source proof:**
- project root marker discovery;
- root-to-cwd hierarchical AGENTS loading;
- AGENTS.override.md;
- bounded project_doc_max_bytes;
- provenance with source path, environment id and cwd;
- multi-environment path convention tests;
- untrusted active project suppresses project-owned AGENTS instructions.

**What problem it solves:** gives coding agents bounded, scoped and attributable repository instructions.

**Trust boundary introduced:** repository content influences behavior but is explicitly separate from authority.

**Persistent data introduced:** none required if digest/provenance is generated on demand.

**Failure modes:** malicious project instructions, stale instructions after file change, oversized instruction trees.

**Cross-platform implications:** path/provenance must preserve Windows/macOS semantics.

**Performance implications:** bounded filesystem discovery; Codex explicitly limits concurrent ancestor probes.

**Migration/compatibility cost:** low/medium.

**FileMCP equivalent today:** CodexSkillRegistry plus ChatGPT manually reads AGENTS/project state; no canonical project-context digest.

**Gap in FileMCP:** no server-owned scoped instruction provenance/hash/freshness contract.

**Primary final action:** ADD/ADAPT a bounded project_context capability.

**Target FileMCP direction:** root-to-cwd discovery, provenance, effective digest, byte/range budget, explicit no-authority statement. Restricted/untrusted profile should suppress or clearly demote repository-owned instructions.

**Prerequisites:** file version/budget contracts.

**Required FileMCP test evidence:** nested scope, provenance, freshness hash, untrusted profile behavior, no authority elevation, Windows/macOS path parity.

**Open questions:** whether symbol/repository map is additionally required; Aider audit decides.

## Capability card CDX-06 - Session/rollout persistence and resume

**Capability:** durable conversation/thread history, rollouts, cold resume and recovery
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/app-server/tests/suite/v2/thread_resume.rs
- codex-rs/app-server-daemon/src/thread_recovery.rs
- codex-rs/core/src/agent/control_tests.rs
- codex-rs/state/
- codex-rs/rollout/

**Tests/source proof:**
- paginated and legacy resume;
- ownership checks;
- persisted turn settings;
- cold-resume child/thread inheritance tests;
- rollout flush/checkpoint behavior.

**What problem it solves:** makes Codex a durable session/agent product.

**Trust boundary introduced:** durable session history becomes execution input.

**Persistent data introduced:** substantial conversation/thread/rollout content and metadata.

**Failure modes:** stale replay, privacy expansion, ownership/version complexity, migration complexity.

**Cross-platform implications:** storage and ownership semantics.

**Performance implications:** database/rollout persistence overhead.

**Migration/compatibility cost:** high and product-changing.

**FileMCP equivalent today:** ChatGPT owns orchestration; FileMCP persists privacy-minimal observability metadata only; repo state files capture project lifecycle.

**Gap in FileMCP:** no local general conversation/task recovery engine.

**Primary final action:** REJECT broad Codex rollout/session persistence for current FileMCP architecture. DEFER a much smaller metadata-only checkpoint/recovery layer pending Cline audit.

**Prerequisites:** separate privacy/security decision if any content persistence is proposed.

**Required FileMCP test evidence:** ownership/freshness and restart tests for metadata-only state if later approved.

**Open questions:** what minimal checkpoint model, if any, Cline comparison justifies.

## Capability card CDX-07 - Immutable MCP permission authority

**Capability:** MCP tool metadata/capabilities are descriptive while permission authority is captured server-side
**Reference repo:** OpenAI Codex
**Pinned SHA:** cb1eea3e98ebc433ab5f9c12ce043e979d1902df
**Evidence classification:** S1
**Source paths:**
- codex-rs/codex-mcp/src/binding.rs
- codex-rs/codex-mcp/src/trusted_access.rs
- codex-rs/codex-mcp/src/client_capabilities.rs
- corresponding *_tests.rs files

**Tests/source proof:**
- prepared MCP binding captures immutable config/permission profile;
- trusted-access metadata is attached only for tightly constrained host-owned/read-only/stdio cases;
- entitlement response bounded and account identity revalidated;
- caller-supplied trusted metadata is replaced with fresh verified result.

**What problem it solves:** prevents model/tool metadata from being treated as authorization.

**Trust boundary introduced:** host/server-owned config and verified account context.

**Persistent data introduced:** none required for the FileMCP-adapted concept.

**Failure modes:** accidental coupling between descriptive annotations and authority.

**Cross-platform implications:** common policy semantics.

**Performance implications:** negligible for local catalog authority.

**Migration/compatibility cost:** low.

**FileMCP equivalent today:** hard runtime/path/Git checks are already server-owned; future catalog classification does not yet have a formal authority-separation contract.

**Gap in FileMCP:** CCI-001 catalog risk/effect metadata could be misread later as permission itself unless this invariant is explicit.

**Primary final action:** ADAPT the invariant, not Codex account-entitlement implementation.

**Prerequisites:** canonical catalog and policy profile design.

**Required FileMCP test evidence:** forged metadata cannot increase authority; catalog annotations cannot alter active profile; prepared operation uses server-owned policy snapshot.

**Open questions:** exact immutable operation-context shape.

## Cross-reference decisions after Codex

Codex CONFIRMS:
- server-owned policy profiles;
- separate filesystem/network authority;
- strict no-self-elevation;
- bounded structured internal process lifecycle;
- project-context provenance/budget;
- keeping tool metadata descriptive rather than authoritative.

Codex CHALLENGES:
- a host-only execution architecture may be insufficient for future high-risk process execution; optional OS sandbox remains OPEN and must be compared against OpenHands isolation before ADR-0005.

Codex DOES NOT OVERTURN:
- structured exec_process as a new FileMCP MCP boundary;
- optimistic file version tokens;
- atomic expected-version apply_edits;
- privacy-minimal evidence.

Codex REJECTS BY COMPARISON:
- copying broad task/thread persistence into FileMCP;
- treating Codex apply_patch as atomic multi-file mutation;
- defaulting FileMCP to approval prompts for ordinary pre-authorized workspace work.

## Round-2 conclusion

R2 Codex audit is COMPLETE. The next comparative question is OpenHands: whether FileMCP should remain host-first with strong policy and optional OS sandbox, or introduce an optional container/remote isolated runtime abstraction.
