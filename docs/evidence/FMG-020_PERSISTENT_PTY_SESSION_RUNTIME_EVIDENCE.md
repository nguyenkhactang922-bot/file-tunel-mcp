# FMG-020 Persistent PTY Session Runtime Evidence

Status: WINDOWS PTY TARGETED VERIFIED / MACOS PARITY PENDING

Branch: `chatgpt/FMG-020-persistent-pty`

## Windows native checkpoint

Implemented:
- canonical catalog `1.11.0` / 41 tools with `pty_start/read/write/resize/signal/stop/list`;
- Windows ConPTY host via `CreatePseudoConsole` + `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE`;
- `STARTF_USESTDHANDLES` launch contract so attached clients receive ConPTY terminal stdio instead of redirected parent stdio;
- per-workspace opaque session IDs and in-memory registry;
- existing `ExecProcessEnvironmentAuthority` reuse;
- policy reauthorization on session actions;
- bounded RAM ring with byte cursors;
- optional short-lived authenticated `PTY_OUTPUT` ContentRef spillover;
- idle TTL and hard max lifetime;
- native resize and Ctrl-C signal;
- owned process-tree cleanup via kill-on-close Job Object;
- restart explicitly never fakes session resume.

## Windows acceptance

PASS:
- Release build: 0 warnings / 0 errors;
- `windows-pty-only-tests: ok (23 assertions)`;
- ConPTY child has live `CONIN$` + `CONOUT$` console devices;
- ConPTY output reaches the FileMCP ring buffer rather than parent redirected stdout;
- interactive write/read round-trip;
- resize applies native ConPTY dimensions;
- Ctrl-C preserves interactive shell semantics;
- tampered session ID rejected;
- invalid resize rejected;
- list is workspace-scoped and reports restart-resume unsupported;
- new LocalTools registry does not fake-resume old sessions;
- policy revocation after start blocks subsequent PTY action;
- `pty_stop` kills owned descendant process tree;
- bounded ring evicts old output;
- overflow spills to `PTY_OUTPUT` only when enabled;
- spill refs are deleted at session end;
- future cursor rejected;
- idle TTL terminates inactive session;
- hard max lifetime terminates session.

## ConPTY routing defect found and fixed

Initial targeted proof showed the process was attached to a pseudo-console (`CONIN$/CONOUT$` existed) but managed stdout still followed the parent redirected stream, leaving the FileMCP PTY ring empty.

Remediation:
- match the Windows Terminal ConPTY launch contract by setting `STARTUPINFO.dwFlags = STARTF_USESTDHANDLES` while leaving `hStdInput/hStdOutput/hStdError` zero;
- this prevents preservation of redirected parent stdio and lets the pseudo-console provide terminal standard handles.

After remediation the native PTY gate passes all 23 assertions.

## Remaining gate

1. implement macOS POSIX PTY/forkpty-equivalent host and session parity;
2. wire all seven tools into macOS LocalTools;
3. add native Swift PTY acceptance;
4. add cross-platform FMG-020 contract and compile-list wiring;
5. affected local gates + full Windows regression;
6. exact-head native Verify macOS / Windows x64 / Windows ARM64;
7. scoped review -> PR/merge -> merged-main Verify;
8. mark FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.

## FMG-020 macOS parity local checkpoint - 2026-09-29

State: LOCAL CROSS-PLATFORM VERIFIED / NATIVE CI PENDING.

Windows checkpoint remains PASS and was not rerun:
- native ConPTY implementation;
- `windows-pty-only-tests: ok (23 assertions)`;
- Release build 0 warnings / 0 errors.

New macOS implementation:
- real POSIX PTY via `forkpty`;
- process-group ownership validation before group signaling;
- native `TIOCSWINSZ` resize;
- Ctrl-C terminal byte semantics and terminate signal;
- workspace-scoped opaque sessions, bounded ring/cursors, idle/max TTL, optional `PTY_OUTPUT` spill/delete;
- LocalTools parity for `pty_start/read/write/resize/signal/stop/list`;
- server shutdown stops owned PTY sessions;
- native Swift acceptance covers actual TTY, write/read, resize, Ctrl-C, session tamper, restart-no-resume, policy revoke, child-tree cleanup, output flood/spill, future cursor, idle TTL and hard lifetime.

Local affected-stage proof:
- project-state contract PASS;
- catalog contract PASS: 1.11.0 / 41 tools / SHA-256 `d997f8c9ea814876e48ba83f888355b75aad4c0215fc92eca9397f457a42cdbc`;
- persistent-PTY cross-platform contract PASS;
- Swift runtime shell syntax PASS;
- macOS build shell syntax PASS;
- `git diff --check` PASS.

NEXT_EXACT_ACTION: commit/push this exact FMG-020 candidate, require native Verify on macOS / Windows x64 / Windows ARM64, fix only failing lane/stage if any, then scoped review -> PR/merge -> merged-main Verify -> FMG-020 DONE / MAIN VERIFIED -> claim FMG-021.

## FMG-020 exact-head Verify remediation - 2026-09-29

Exact-head `72383d140e8d9c5bc256783119a58945e417cfaf`, Verify run `36597408414`:
- Windows ARM64: SUCCESS.
- Windows x64: FAIL only at stale canonical-tool count assertions after catalog 1.11.0 / 41 tools.
- macOS: static/typecheck/catalog and pre-PTY runtime stages PASS; FAIL at native forkpty TTY assertion `forkpty child must observe terminal stdin/stdout`.

Remediation currently local:
- Windows test expectations updated to 36 non-shell local tools / 37 full local tools, with full runtime semantics unchanged.
- macOS `PosixPtyHost` now allocates stable heap-backed argv/envp pointer arrays before `forkpty`; child `execve` no longer enters Swift Array buffer closures after fork. This is a fork-safety/lifetime fix, not a PTY authority redesign.
- native PTY assertion now includes observed output in failure diagnostics.

Affected local proof:
- canonical catalog contract PASS: 1.11.0 / 41 tools / SHA-256 `d997f8c9ea814876e48ba83f888355b75aad4c0215fc92eca9397f457a42cdbc`;
- persistent-PTY contract PASS;
- Windows full core runtime PASS: 899 assertions;
- Windows PTY-only PASS: 23 assertions;
- project-state contract PASS;
- Swift runtime shell syntax PASS;
- macOS build shell syntax PASS;
- `git diff --check` PASS.

Native macOS forkpty proof remains pending and must be established by the next exact-head native Verify. Do not claim FMG-020 MAIN VERIFIED until macOS + Windows x64 + Windows ARM64 all pass on the same exact head, then PR/review/merge and merged-main Verify succeed.
NEXT_EXACT_ACTION: inspect latest `fork/main`, remote FMG-020 branch and PR state before side effects; if no duplicate/newer head exists, commit/push this exact remediation candidate and require a new exact-head native Verify.

## FMG-020 macOS diagnostic checkpoint

Exact-head `cbfb623735ff437bcb358b81073ea2359c7689ae`, Verify run `36599800550`:
- Windows x64: SUCCESS.
- Windows ARM64: SUCCESS.
- macOS Static verification: SUCCESS.
- macOS Integration: FAIL at native forkpty TTY assertion with empty captured output.

Because the failure does not yet distinguish child launch/exit from master-reader failure, the next change is test-diagnostic only: the assertion now reports the PTY session state and metadata (including exit code when terminal) from `pty_list`. No PTY runtime authority or product semantics are changed by this diagnostic.
NEXT_EXACT_ACTION: commit/push the diagnostic-only head, run native Verify, inspect only macOS integration evidence, then fix the proven macOS PTY defect.

## FMG-020 macOS native-launch remediation

Diagnostic head `5940a2da21ba2da29bdb3968847f05a10256fc7d`, Verify run `36600521628`, proved the native PTY child remained alive for the full timeout with `state=running`, `exit_code=null`, and `end_cursor=0`. This rules out an immediate exec failure and shows the raw `forkpty` child path was stuck before producing output.

Remediation replaces only the macOS launch primitive:
- allocate a real PTY with `openpty`;
- launch with `posix_spawn`, so no Swift runtime code executes in the child after a raw fork;
- use spawn file actions for cwd and slave-to-stdin/stdout/stderr binding;
- create a dedicated child process group with `POSIX_SPAWN_SETPGROUP`;
- use process-group SIGINT for `ctrl_c` and SIGTERM for terminate, preserving bounded owned-group signaling;
- backend truth label is now `macos-posix-openpty-spawn`.

Unchanged: workspace scope, opaque session IDs, policy reauthorization, ring/cursor semantics, TTL/hard lifetime, PTY_OUTPUT spill/delete, restart-no-resume, evidence/telemetry privacy, and the seven MCP tool contracts.

Local affected proof: persistent-PTY contract PASS; Swift runtime shell syntax PASS; macOS build shell syntax PASS; `git diff --check` PASS. Native typecheck/integration remains pending on macOS CI.
NEXT_EXACT_ACTION: verify remote/main state, commit/push this exact macOS launcher remediation, then require exact-head native Verify on macOS / Windows x64 / Windows ARM64.

## FMG-020 macOS PTY raw-FD remediation

Exact-head `c8b0d2a263110570789787d8734cb5694d4f2c59`, Verify run `36601440168`, proved the new `openpty + posix_spawn` launcher passes macOS static/typecheck but integration still returns an owned live session with `state=running`, `exit_code=null`, and `end_cursor=0`.

The next remediation is isolated to the PTY master I/O layer:
- replace Foundation `FileHandle` reads/writes with raw `Darwin.read/write` loops;
- retry `EINTR`;
- treat PTY-master `EIO` as a transient slave-lifecycle condition while the owned child is still running, instead of silently terminating the reader;
- preserve bounded partial-write handling;
- resize/close now use the same raw descriptors;
- native failure diagnostics include the descendant PID-file state, which distinguishes fixture execution from an output-reader failure.

Unchanged: `openpty + posix_spawn` launch topology, process-group ownership, workspace/session scope, policy reauthorization, ring/cursor/TTL/spill semantics, restart-no-resume, and PTY evidence/telemetry privacy.

Local affected proof already PASS: persistent-PTY contract; Swift runtime shell syntax; `git diff --check`.
NEXT_EXACT_ACTION: verify remote/main/PR state, commit/push the raw-FD remediation, require exact-head native Verify, then inspect only any failing lane/stage.
