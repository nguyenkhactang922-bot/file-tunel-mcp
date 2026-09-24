# OpenHands Runtime Architecture Audit for FileMCP

Status: INDEPENDENT SOURCE AUDIT COMPLETE
Date: 2026-09-23
Primary repository: https://github.com/OpenHands/OpenHands
Pinned primary commit: 1b0dc0b20f224a4e40a31ca1790b51208145bfe5
Canonical runtime dependency: https://github.com/OpenHands/software-agent-sdk
Pinned runtime commit: 5b36cacccc2bbe6f8fbce9e1d3ff4b0a3dcddadb
Audit clones:
- D:\Tools\_audit\OpenHands
- D:\Tools\_audit\OpenHandsSDK
Purpose: challenge FileMCP host-execution assumptions using an isolation-first reference.

## Repository architecture correction

The current OpenHands/OpenHands repository is Agent Canvas/frontend-oriented. Its own `docs/architecture.md` states that action execution and sandbox isolation belong to Agent Server/runtime rather than Canvas. The source-level runtime audit therefore follows the canonical `OpenHands/software-agent-sdk` dependency instead of pretending the frontend repository still contains the old runtime architecture.

This correction is itself an audit finding: repository names/history cannot substitute for current source truth.

## Finding O1 - workspace is an abstraction, isolation is a backend choice

Source evidence:
`openhands-sdk/openhands/sdk/workspace/base.py` defines `BaseWorkspace` as the execution/file/Git contract. Concrete implementations can provide local, remote or sandboxed behavior.

Impact:
FileMCP can obtain future isolation without changing the MCP-level exec/file contract if an execution/workspace backend seam is designed now.

## Finding O2 - DockerWorkspace provides materially stronger process containment but has operational cost

Source evidence:
`openhands-workspace/openhands/workspace/docker/workspace.py`:
- starts a dedicated Agent Server container;
- checks Docker availability;
- maps explicit volumes;
- maps ports;
- waits for health;
- can pause/resume/stop;
- depends on image/platform selection;
- has explicit cleanup lifecycle.

Agent Server Docker runtime source additionally uses:
- per-conversation runtime identity;
- isolated persistence/workspace mounts;
- memory/CPU/PID limits when configured;
- dropped Linux capabilities;
- `no-new-privileges`;
- lifecycle/idle eviction.

Benefits:
- stronger blast-radius reduction;
- explicit resource controls;
- restartable/replaceable runtime boundary;
- less direct authority over host filesystem beyond mounts.

Costs:
- Docker/Desktop dependency;
- image startup/pull cost;
- volume/path translation;
- Linux-container semantics on Windows/macOS;
- toolchain mismatch with host developer environment;
- credential forwarding/mount decisions;
- extra networking/health/lifecycle state.

## Finding O3 - host-local execution still exists as a legitimate mode

The SDK/Agent Server architecture includes local workspace/runtime options. The existence of Docker support therefore does not prove that all agent execution must be containerized.

Impact:
Mandatory Docker is not justified for FileMCP's local developer bridge goal.

## Finding O4 - isolation must own lifecycle, not only command launch

Container runtime code tracks start, health, sessions, idle eviction, stop/delete and persisted identity. This shows that "add Docker around exec_process" is not a sufficient architecture. An isolated backend is a lifecycle subsystem.

FileMCP impact:
If isolation is implemented later it needs:
- backend identity;
- workspace mapping contract;
- resource policy;
- network policy;
- health/start/stop lifecycle;
- cleanup after FileMCP crash/restart;
- evidence that records which backend executed the command.

This is too large to silently insert into Phase A.

## Finding O5 - sandbox boundary does not replace semantic Git/file rules

A container only confines the process to mounted resources. It does not decide whether an agent should run Git hooks, use repository credentials, overwrite stale edits, or follow unsafe Git config. FileMCP's existing semantic protections remain necessary.

## FileMCP actions after OpenHands audit

| Capability | Preliminary action | Reason |
|---|---|---|
| host execution | KEEP as default | high developer fidelity; already mature in FileMCP |
| execution backend interface | ADD | isolates contract from future runtime choice |
| Docker/isolated backend | DEFER to later phase | valuable but operationally large and optional |
| mandatory container runtime | REJECT | incompatible with lightweight always-available local bridge goal |
| resource-limit contract | ADAPT | useful for future backend and current process budgets |
| runtime health/lifecycle semantics | ADAPT selectively | needed only for persistent/isolated backends, not every one-shot exec |
| FileMCP Git/path safety | KEEP + HARDEN | remains necessary inside or outside containers |

## Independent conclusion

OpenHands changes the design from a binary "sandbox or no sandbox" question to a cleaner architecture:

`stable FileMCP tool contract -> execution backend -> Host backend now / Optional isolated backend later`.

The final architecture should reserve this seam but should not make Docker a prerequisite for normal FileMCP operation.

## Exact dependency revalidation correction

The independent pass above originally inspected software-agent-sdk at `5b36cac...`. A subsequent source-first dependency check of the pinned Agent Canvas snapshot found `config/defaults.json` pins `openhands-agent-server` **1.49.4**. The canonical runtime source was therefore re-pinned to exact tag `v1.49.4`, SHA `e7cc8c27b2b234fc1c104825ad20dddf1c01fa31`, and the runtime/isolation conclusions were revalidated there.

Final evidence authority for R3 is `docs/audit/OPENHANDS_SOURCE_AUDIT_2026-09-23.md`; this independent artifact remains useful as a separate review round but its original SDK SHA is superseded for the final matrix.
