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
