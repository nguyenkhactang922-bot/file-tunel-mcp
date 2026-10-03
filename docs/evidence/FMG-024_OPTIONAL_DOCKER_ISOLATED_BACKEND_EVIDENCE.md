# FMG-024 Optional Docker Isolated Backend Evidence

Date: 2026-10-03
Task: FMG-024
Branch: `chatgpt/FMG-024-docker-backend`
Verified candidate before evidence-only closure: `557ddaa157f5897bf3d5c5be8e6a1f498fbc2200`
State: EXACT-HEAD NATIVE VERIFIED / SCOPED REVIEW PASS / LIVE DOCKER ENVIRONMENT-BLOCKED

## Implemented scope

- Optional, server-owned Docker execution backend for structured process + PTY only.
- HostExecutionBackend remains the default when Docker mode is not locally selected.
- Docker image must be locally configured, allowlisted, and digest-pinned (`@sha256:...`).
- Container creation uses `--pull never`; FileMCP does not silently pull an image.
- Image-provided healthchecks are disabled for the long-lived execution container.
- Exactly one read-write bind mount is created for the authorized FileMCP workspace at `/workspace`.
- Shared-root/SafePathResolver authority is revalidated before creating the bind mount and effective mounts are inspected after container start.
- Non-root identity is mandatory; root identities are rejected.
- Root filesystem is read-only; Linux capabilities are dropped; no-new-privileges is required.
- CPU, memory, and PID limits are mandatory and their effective Docker values are inspected after startup.
- Network is `none` by default. Network-enabled mode requires the separate local open-world execution-backend policy capability.
- Docker daemon/image/mount/network selection is local/server-owned; MCP tool schemas do not expose caller-controlled Docker image, daemon, mount, backend, or network selectors.
- Docker-control environment overrides (`DOCKER_HOST`, context/TLS/config/home-related controls) are rejected from model/request overrides before container side effects.
- Container environment is separately mediated and does not receive the FileMCP host baseline by default.
- Ownership/workspace/backend/lease labels scope lifecycle and orphan cleanup; containers failing ownership checks are not deleted.
- Evidence records server-selected backend identity plus image digest, workspace mode, network policy, and resource policy; raw command/file content is not added to evidence.

## Native verification

GitHub Verify run `37043531330` on exact candidate `557ddaa157f5897bf3d5c5be8e6a1f498fbc2200`: SUCCESS.

- macOS: static warnings-as-errors verification PASS; integration tests PASS; app build PASS; legal resources PASS.
- Windows x64: build PASS; catalog/parity and all advanced contracts PASS; Docker backend contract PASS; full integration PASS; package/build/smoke/resources PASS.
- native Windows ARM64: Docker backend contract PASS; build PASS; smoke/resources/package PASS.
- Canonical MCP catalog remains `1.13.0` / 46 tools with SHA-256 `30ecf017a35db8ebeb6344786576664035f504cae8996a0c4a223df797254364`.

Earlier native remediation history was limited to macOS wiring/syntax defects; Windows x64 and ARM64 stayed green. The final exact-head run is green on all three lanes.

## Negative/adversarial coverage

Covered by the FMG-024 contract/runtime suites and exact-head Verify:

- Docker absent / daemon unreachable behavior;
- unpinned image and selected image outside the local allowlist;
- changed/unmatched local image digest;
- root container identity;
- resource/isolation flag omission contract;
- network-enabled configuration without the separate local capability;
- caller Docker-daemon-control environment override;
- Docker socket/malicious mount exposure through the public tool surface;
- foreign/mismatched ownership labels during orphan cleanup;
- backend evidence identity/metadata binding;
- File/Git tools remaining outside the execution backend.

## Scoped review result

PASS. No P0/P1 finding remains in the frozen FMG-024 scope.

Review specifically confirmed:

- no new public MCP Docker selector or model-chosen daemon/image/mount/network authority;
- no Docker socket mount or privileged container mode;
- `--pull never`, digest verification, one-workspace-bind, non-root/read-only/cap-drop/no-new-privileges/resource-cap/network policy are present and post-start security state is inspected;
- cleanup checks FileMCP/backend/workspace labels and a bounded lease shape before deleting a discovered container;
- Docker control variables are local authority and request-side attempts to override them fail before daemon/container side effects;
- HostExecutionBackend remains the startup/default fallback when Docker mode is not selected;
- no persistence of prompt/chat/command/file bodies or credentials was introduced.

## Docker Desktop / engine semantics and limitations

This task does **not** claim Docker itself is a VM-grade security boundary or a proof against container escape. FileMCP adds bounded Docker configuration and verification on top of the locally installed Docker engine.

Windows and macOS support assumes a Docker-compatible local CLI/engine such as Docker Desktop using Linux containers because the configured execution image/keepalive command uses Linux semantics (`/bin/sh`, `/tmp`, Linux capability/security options). Windows-container mode is not claimed as supported by FMG-024. On Docker Desktop, the actual container engine normally runs inside Docker Desktop's managed Linux VM; workspace bind-mount behavior therefore remains subject to Docker Desktop file-sharing/path translation rules.

The Docker CLI/daemon is external local infrastructure. FileMCP does not install/start Docker Desktop, does not mount the Docker socket into the execution container, and does not claim live Docker success when the local daemon is unavailable. Label-based ownership is lifecycle scoping inside the same local Docker authority, not a cryptographic boundary against another fully privileged local Docker administrator.

## Live Docker proof status

The Windows development host has Docker CLI 29.6.2 installed, but the local Docker daemon endpoint was unavailable during FMG-024 verification. Therefore no live container-engine PASS is claimed here.

Per the frozen task graph, FMG-024 may be CODE/CONTRACT/NATIVE VERIFIED with live Docker explicitly environment-blocked. FMG-025/FMG-026 must preserve this status unless a verification environment with an available Docker engine runs the optional real isolated exec + PTY + network-none proof.

## Closure path

NEXT_EXACT_ACTION: commit/push this evidence/state-only closure, require native Verify on the resulting exact head, then PR/merge, require merged-main Verify, mark FMG-024 DONE / MAIN VERIFIED, and claim FMG-025.


## Final closure

FMG-024 is DONE / MAIN VERIFIED.
- Evidence/state closure head: `d0495da7f0d70e1fc14e93e928ba52a2d9ffee89`.
- Push Verify `37094158297`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- PR #44 Verify `37094506166`: final SUCCESS on all three lanes. Its first Windows x64 integration attempt failed the pre-existing bounded ProcessRunner output assertion, while the same exact head had already passed push Verify; rerunning the failed Windows job on the unchanged head passed, so no unrelated production/test code was modified.
- PR #44 merged as `2bd859a966f9f49075ffc7d0a544154cb5d76498`.
- Merged-main Verify `37095113136`: SUCCESS on macOS / Windows x64 / native Windows ARM64.
- Live Docker container-engine proof remains explicitly environment-blocked because the local daemon was unavailable. No live Docker PASS is claimed.
