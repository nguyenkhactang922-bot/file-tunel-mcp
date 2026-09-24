# OPENHANDS SOURCE AUDIT - 2026-09-23

Status: COMPLETE SOURCE AUDIT FOR R3
Canvas reference: OpenHands/OpenHands@1b0dc0b20f224a4e40a31ca1790b51208145bfe5
Canvas commit date: 2026-09-23T15:07:12Z
Canvas license: MIT
Runtime dependency used by Canvas: openhands-agent-server 1.49.4
Runtime source reference: OpenHands/software-agent-sdk@v1.49.4
Runtime pinned SHA: e7cc8c27b2b234fc1c104825ad20dddf1c01fa31
Runtime commit date: 2026-09-22T20:47:14+07:00
Runtime license: MIT
Audit clones:
- D:\Tools\_audit\OpenHands
- D:\Tools\_audit\OpenHandsSDK

This audit follows the runtime dependency to its exact source version. The current OpenHands/OpenHands repository is Agent Canvas and explicitly does not execute agent actions or implement sandboxing itself.

## Executive result

OpenHands proves that host-local and isolated execution can coexist behind one workspace abstraction, but it also demonstrates how much operational/security machinery a real isolated runtime needs. FileMCP should not make Docker/remote runtime a Phase A dependency.

The correct comparison is:

- FileMCP host execution is intentionally narrow and local.
- OpenHands LocalWorkspace also executes directly on the host and is not a sandbox.
- OpenHands production-style Docker runtime adds per-conversation containers, private credentials, bounded resources, carefully scoped mounts, loopback port mediation and no-new-privileges.
- Even that Docker runtime does not by itself represent a deny-by-default outbound network sandbox.
- Therefore isolation is a separate execution backend, not a replacement for server-owned policy or network permission semantics.

## Capability card OH-01 - Workspace abstraction

**Capability:** common local/remote workspace abstraction for command/file/Git operations
**Evidence:** S1 - source + tests
**Source:**
- openhands-sdk/openhands/sdk/workspace/base.py
- openhands-sdk/openhands/sdk/workspace/local.py
- openhands-sdk/openhands/sdk/workspace/remote/base.py
- tests/sdk/workspace/
- tests/workspace/

**Observed behavior:**
- BaseWorkspace defines command, file transfer, Git changes/diff and lifecycle pause/resume.
- LocalWorkspace executes directly on the host using a shared command utility.
- RemoteWorkspace performs equivalent operations through Agent Server.
- container/cloud/apptainer implementations subclass or compose the remote workspace model.

**Problem solved:** execution location can vary without rewriting agent logic.

**Trust boundary:** the concrete workspace implementation is the authority boundary.

**Persistent data:** remote implementations may persist runtime/workspace state; local need not.

**Failure modes:** semantic drift between local and remote, different path conventions, remote retries, resource lifecycle.

**FileMCP equivalent:** Windows/macOS native tool implementations plus workspace key; no execution-backend abstraction.

**Gap:** FileMCP cannot redirect process/file execution to an isolated backend without introducing a new architecture layer.

**Final action:** DEFER an execution-backend abstraction until after Phase A. Do not introduce it merely to imitate OpenHands.

**Reason:** FileMCP's product is a local bridge; abstracting every tool now would add migration risk before there is an approved second backend.

## Capability card OH-02 - Hardened per-conversation Docker runtime

**Capability:** isolated per-conversation Agent Server container
**Evidence:** S1
**Source:**
- openhands-agent-server/openhands/agent_server/docker_runtime/registry.py
- provisioning.py
- mediation.py
- proxy.py
- routers.py
- tests/agent_server/docker_runtime/
- openhands-agent-server/openhands/agent_server/config.py

**Source-backed hardening:**
- each runtime has independent API key and encryption key;
- provisioning manifests encrypt secrets;
- persistence/runtime roots reject symlinks and enforce direct-child containment;
- dedicated per-conversation workspace, persistence and conversation mounts;
- container runs as host uid/gid rather than root by default;
- --cap-drop ALL;
- --security-opt no-new-privileges;
- published Agent Server port is 127.0.0.1 ephemeral only;
- Docker port binding is verified to actually be loopback;
- default limits: 4g memory, 2 CPUs, 512 PIDs;
- environment is sanitized and only a specific allowlist is injected;
- profile/secret mediation limits which secrets cross runtime boundary;
- stale containers are cleaned and startup health is bounded.

**Important non-property:** the inspected command does not set --network none or a deny-by-default egress policy. It adds host.docker.internal and uses Docker default networking unless deployment changes it.

**Problem solved:** stronger filesystem/process isolation and per-run resource separation.

**Trust boundary:** Docker daemon plus container image and outer Agent Server mediator.

**Persistent data:** runtime identity, encrypted secret material, mounted workspace/conversation/persistence directories.

**Failure modes:** Docker daemon compromise, image supply chain, mount mistakes, network egress, cross-platform Docker Desktop semantics, cleanup leaks.

**Cross-platform:** Docker Desktop differs on Windows/macOS; Agent Server implementation is primarily Linux container runtime.

**Performance:** startup/image/resource overhead is large relative to FileMCP native process launch.

**FileMCP equivalent:** none; FileMCP stays on host but constrains paths/Git/process lifetime.

**Final action:** DEFER as an optional later isolated execution backend, not Phase A and not mandatory.

**If later approved, minimum acceptance:** loopback-only mediation, cap-drop/no-new-privileges, user mapping, resource caps, scoped mounts with symlink/reparse checks, sanitized env, independent credentials, explicit outbound-network policy, image pinning/provenance, lifecycle cleanup and native Windows/macOS host tests.

## Capability card OH-03 - Generic DockerWorkspace warning

**Capability:** user-configurable Docker workspace
**Evidence:** S1
**Source:**
- openhands-workspace/openhands/workspace/docker/workspace.py
- tests/workspace/test_docker_workspace.py

**Observed behavior:**
- arbitrary user-provided volume list;
- optional named network;
- optional GPU;
- port mapping and health checks;
- container pause/resume;
- no mandatory CPU/memory/PID/cap-drop/no-new-privileges policy in this generic class.

**Why this matters:** "run in Docker" is not itself an adequate security design.

**Final action:** REJECT copying generic DockerWorkspace directly into FileMCP. Any later container backend must follow the hardened Agent Server runtime contract instead.

## Capability card OH-04 - Terminal / PTY / long-running process behavior

**Capability:** terminal sessions, tmux-backed PTY, soft timeouts and long-running interaction
**Evidence:** S1
**Source:**
- openhands-tools/openhands/tools/terminal/
- tests/tools/terminal/
- tests/agent_server/stress/test_long_running_command.py

**Observed behavior:**
- terminal interface has subprocess, Windows and tmux variants;
- terminal sessions preserve interactive state;
- timeout policy prevents foreground timeout from exceeding 90% of runtime idle TTL;
- long-running operations can return control and continue/poll rather than blocking the whole runtime;
- tests cover Windows terminal, tmux pane pool, resets, timeout policy and terminal session semantics.

**Problem solved:** interactive installers/dev servers and commands that outlive one request.

**FileMCP equivalent:** one-shot ProcessRunner plus shell run_command; no persistent PTY.

**Final action:** DEFER to Phase B. Codex and OpenHands both validate the use case, but it is not required to unlock safe Phase A structured exec/versioned editing.

**Prerequisites:** exec_process result identity, bounded process registry, explicit lifecycle/expiry and policy integration.

## Capability card OH-05 - Event log, persistence and recovery

**Capability:** durable event-sourced conversation state with resume/fork/rehydration
**Evidence:** S1
**Source:**
- openhands-sdk/openhands/sdk/conversation/event_store.py
- conversation/impl/local_conversation.py
- conversation/state.py
- openhands-agent-server conversation service
- tests for eviction, recovery, fork/resume, persistence and event concurrency

**Observed behavior:**
- EventLog persists individual typed events;
- process/thread-safe lock and count marker;
- rebuilds stale in-memory index from disk;
- supports parent-linked branch/fork traversal;
- persisted conversations can be evicted from memory and rehydrated;
- remote/runtime state can be reprovisioned and resumed.

**Problem solved:** durable agent session/task product.

**Trust/persistence cost:** large. Conversation events, user/model/tool history and execution state become durable inputs.

**FileMCP equivalent:** privacy-minimal telemetry plus explicit project state Markdown; ChatGPT is orchestrator.

**Final action:** REJECT OpenHands event-sourced conversation persistence in FileMCP core. KEEP OPEN only a minimal metadata checkpoint/freshness layer that never stores prompts/tool bodies/file content unless a separate privacy ADR approves it.

**Reason:** recovery benefit is real, but OpenHands persistence is for an agent runtime product, not a narrow local execution bridge.

## Capability card OH-06 - Local task/subagent execution

**Capability:** task manager and delegate tool spawning child agent conversations
**Evidence:** S1
**Source:**
- openhands-tools/openhands/tools/task/manager.py
- task/impl.py
- delegate/impl.py
- openhands-sdk/openhands/sdk/subagent/
- tests/tools/task/
- parent/child conversation tests

**Observed behavior:**
- TaskManager starts/resumes child LocalConversation tasks;
- DelegateExecutor can spawn bounded child agents (default max_children 5);
- subagents inherit or override confirmation policy;
- subagents can persist under parent persistence directory;
- parallel delegation uses local threads and aggregates results/metrics.

**Problem solved:** in-runtime multi-agent delegation.

**Trust/persistence cost:** high: nested agent authority, child persistence, parallel execution, model cost and confirmation behavior.

**FileMCP equivalent:** none by design; ChatGPT Web is the main coding agent/orchestrator.

**Final action:** REJECT for FileMCP core / Phase A. A later local task engine would require a separate ADR proving why ChatGPT-side orchestration is insufficient. Do not copy subagent runtime now.

## Capability card OH-07 - Secret and request mediation across isolation boundary

**Capability:** outer trusted service materializes/filters config and secrets before isolated runtime start
**Evidence:** S1
**Source:**
- docker_runtime/mediation.py
- docker_runtime/provisioning.py
- tests/agent_server/docker_runtime/test_mediation.py
- test_provisioning.py

**Observed behavior:**
- secret sources are resolved before crossing boundary;
- profile allowed-secret set filters request secrets;
- isolated runtime gets a distinct encryption/API key;
- stored identity uses encryption and file-mode/symlink checks;
- request is serialized using runtime-specific cipher.

**FileMCP implication:** if an isolated backend is ever added, the host FileMCP process must mediate capability/config/secrets explicitly. Never pass the whole host environment or Credential Manager context into a child sandbox.

**Final action:** ADAPT as a future isolated-backend invariant, not current Phase A code.

## Architecture decision after OpenHands

OpenHands changes the sandbox decision from a binary "sandbox or no sandbox" into a layered choice:

```text
Phase A:
host-native FileMCP
+ existing path/Git/process hardening
+ server-owned policy profile
+ structured exec_process
+ no mandatory container

Later optional isolation:
execution-backend interface
-> hardened container/remote implementation
-> explicit network policy
-> mediated secrets
-> bounded lifecycle/resource caps
```

Therefore:

- mandatory Docker/container sandbox: REJECT for current Phase A;
- optional isolated execution backend: DEFER, source-backed candidate;
- host-native OS sandbox: still possible as a smaller optional hardening layer, but must not be confused with container isolation;
- network permission remains a separate policy dimension;
- persistent PTY: DEFER Phase B;
- local task/subagent engine: REJECT/DEFER behind a separate future ADR;
- broad conversation/event persistence: REJECT;
- minimal metadata checkpoint/recovery: remains OPEN for Cline comparison.

## Round-3 conclusion

R3 OpenHands audit is COMPLETE. The next unresolved major architecture question is large-repository context/editing efficiency; Aider is audited next.
