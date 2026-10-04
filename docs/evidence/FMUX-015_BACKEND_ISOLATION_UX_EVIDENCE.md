# FMUX-015 Backend / Isolation UX Evidence

Date: 2026-10-04
Branch: `chatgpt/FMUX-015-backend-isolation-ux`
Base verified main: `f76b4e9a84c428080907859591b4aa4ddc40645c`
Task state: ACTIVE / LOCAL VERIFIED

## Scope

FMUX-015 projects existing FMG-023/FMG-024 execution-backend truth into bounded Windows/macOS presentation surfaces. Presentation is read-only: it does not select an execution backend, mutate Docker configuration, invoke Docker CLI, create containers, or grant additional authority.

## Truth projection

The desktop receives a server-owned snapshot from the already-selected execution backend:
- backend id/version and capabilities;
- workspace/environment/network/resource modes;
- backend availability + health state;
- isolation flag derived from the core `isolation` capability;
- Docker-selected flag and Docker availability state only when Docker is selected;
- bounded evidence metadata allowlist: image digest, workspace mode, network policy, resource policy;
- `presentation_grants_authority=false`.

When host-native is selected, Docker is rendered as `not selected / not probed`; FileMCP does not infer daemon availability. If an isolated backend is selected and its core health is degraded/unavailable, the UI renders that backend state without converting it into an application failure.

## Local runtime truth

Live `pty_list` on the existing FMG026-ready runtime returned:
- backend: `host-native` `1.0.0`;
- workspace mode: `host-contained`;
- environment mode: `mediated`;
- network mode: `host`;
- resource mode: `host-process`;
- `grants_authority=false`;
- no PTY sessions were required or started for this proof.

The previously established Docker live-engine proof remains ENVIRONMENT BLOCKED because the local daemon is unavailable. FMUX-015 does not turn that environment limitation into synthetic Docker availability.

## Local gates

PASS:
- `tests/test_fmux_backend_isolation_contract.ps1`;
- `tests/test_fmux_app_shell_contract.ps1`;
- `tests/test_fmux_presentation_contract.ps1`;
- `tests/test_project_state_contract.ps1`;
- `tests/test_execution_backend_contract.ps1`;
- `tests/test_docker_backend_contract.ps1`;
- `git diff --check`;
- Windows Release build: `dotnet build windows/FileMCP.Windows.sln -c Release --no-restore -warnaserror` -> 0 warnings / 0 errors.

macOS compile/typecheck/build remains PENDING exact-head GitHub Verify because the local host is Windows.

## Scoped review

- No backend selector was added.
- No `ExecutionBackendMode`/Docker configuration mutation exists in presentation code.
- No Docker CLI/process launch exists in the Backend / Isolation UI.
- Backend identity/health comes from the server-owned selected backend, not caller input.
- Sensitive/raw Docker health detail is not projected.
- Presentation does not grant authority.
- Windows and macOS surfaces state Docker `not selected / not probed` when host-native is selected.

## Next gate

Create the exact candidate commit, side-effect-guard remote branch/PR state, push once, then require GitHub Verify SUCCESS on macOS / Windows x64 / native Windows ARM64 before PR closure. Local verification is not DONE.
