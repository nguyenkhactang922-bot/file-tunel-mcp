# FMG-023 Execution Backend Interface Evidence

Date: 2026-10-02
Task: FMG-023
Branch: chatgpt/FMG-023-execution-backend
State at this document revision: LOCAL VERIFIED / NATIVE CI PENDING

## Scope implemented

- Internal IExecutionBackend / ExecutionBackend protocol for structured process + PTY only.
- HostExecutionBackend remains the default and wraps the existing ProcessRunner + PersistentPty implementation.
- Explicit server-owned backend id/version/capabilities plus workspace/environment/network/resource mode metadata.
- Relative workspace cwd and request environment overrides are handed to the selected backend; HostExecutionBackend reuses SafePathResolver and ExecProcessEnvironmentAuthority.
- Backend health/capability checks fail closed before process/PTY dispatch.
- StopAll cleanup routes through the selected backend.
- File and Git MCP tools remain host-native and are not moved behind the backend interface.
- Evidence records freeze and persist server-owned backend identity for execution-backed tools.
- Public MCP catalog remains unchanged at v1.13.0 / 46 tools. There is no caller-controlled backend_id selector.
- Descriptor modes are bounded identifiers rather than hard-coded host-only values, preserving the frozen FMG-024 Docker dependency without implementing Docker in FMG-023.

## Local verification

PASS:
- Windows solution Release build with warnings-as-errors and --no-restore: 0 warnings / 0 errors.
- Full Windows runtime suite: 975 assertions PASS.
- FMG-023 targeted execution-backend suite: 19 assertions PASS.
- Existing PTY-only suite: 23 assertions PASS before the final descriptor-extensibility repair; full 975-assertion regression later re-proved PTY behavior unchanged.
- canonical tool catalog contract: 46 tools, SHA-256 30ecf017a35db8ebeb6344786576664035f504cae8996a0c4a223df797254364.
- cross-platform tool-surface parity: PASS.
- exec_process contract: PASS.
- persistent PTY contract: PASS.
- metadata evidence contract: PASS.
- execution-backend contract: PASS.
- git diff --check: PASS.

The first local solution build without --no-restore failed in NuGet restore with Value cannot be null (path1). No dependency changed in FMG-023; the same solution then built successfully with the already-restored lock/assets using --no-restore. Native GitHub Verify remains authoritative for clean restore/build on Windows and macOS.

## Negative/adversarial coverage

PASS:
- unavailable backend rejects before process dispatch and produces no process side effect;
- required capability mismatch rejects before dispatch;
- degraded lifecycle state fails closed;
- malformed process result normalization is rejected;
- malformed backend identity is rejected;
- model-supplied backend_id argument is rejected by canonical schema/argument validation;
- filesystem call remains outside execution backend;
- HostExecutionBackend remains available after fake backend failure cases;
- future isolated workspace/network/resource mode identifiers validate through the generic interface contract without weakening HostExecutionBackend defaults.

## Scoped review

PASS:
- no new public MCP tool or caller backend selector;
- no shared-root/path authority weakening;
- no Git authority moved behind the execution backend;
- no raw command/tool/file content added to telemetry/evidence;
- no local LLM/runtime dependency;
- no Docker behavior implemented early;
- backend identity in evidence comes from FileMCP-selected backend, not model input;
- current host behavior is preserved except routing and additive result metadata.

## Pending closure evidence

Before FMG-023 can be DONE / MAIN VERIFIED:
1. commit/push the exact candidate;
2. require native GitHub Verify SUCCESS on macOS, Windows x64 and native Windows ARM64;
3. perform exact-head scoped review;
4. PR/merge;
5. require merged-main native Verify SUCCESS.


## Exact-head native verification and scoped review

Candidate: fe05746759592d3ef3354e92b4969b9f246fdb41
GitHub Verify run: 36996922253
Result: SUCCESS on macOS, Windows x64 and native Windows ARM64.

Notable native proof:
- macOS warnings-as-errors typecheck: PASS;
- macOS full integration tests: PASS;
- macOS app build/resources: PASS;
- Windows x64 full integration/build/smoke/resources: PASS;
- native Windows ARM64 contract/build/smoke/resources: PASS;
- execution-backend interface contract: PASS on both Windows lanes;
- canonical catalog remained 1.13.0 / 46 tools.

Exact-head scoped review: PASS.
No P0/P1 finding remains in FMG-023 scope. The backend abstraction is process+PTY only, HostExecutionBackend remains default, file/Git authority remains host-native, backend selection/identity is server-owned, and the generic descriptor-mode repair leaves FMG-024 isolated backend implementation possible without weakening current host defaults.

NEXT_EXACT_ACTION: commit this evidence/state-only closure, push, require Verify on the evidence-only head, then PR/merge and merged-main Verify.


## MAIN VERIFIED closure

PR: #43
PR head: ba5cf3ebdf91a7c3eb34263948d7a99729ba6d6f
PR Verify: 36998198466 SUCCESS on macOS / Windows x64 / native Windows ARM64.
Merge commit: d71fbc08e9e08f65c59ce5e05649e0dc629f7935
Merged-main Verify: 36998939456 SUCCESS on macOS / Windows x64 / native Windows ARM64.

Final status: FMG-023 DONE / MAIN VERIFIED.
