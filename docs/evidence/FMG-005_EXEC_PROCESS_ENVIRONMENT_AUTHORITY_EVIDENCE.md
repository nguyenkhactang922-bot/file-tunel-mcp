# FMG-005 Structured exec_process + Environment Authority Evidence

Status: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING

Branch: `chatgpt/FMG-005-exec-process`

Dependencies: FMG-002, FMG-003 and FMG-004 are DONE / MAIN VERIFIED.

## Implemented scope

- Added canonical `exec_process` as the 20th FileMCP tool.
- `exec_process` launches an executable directly with an argv array; FileMCP adds no implicit shell interpolation.
- `cwd` is resolved through the existing shared-root containment boundary.
- Existing native `ProcessRunner` remains the execution engine on Windows and macOS; `run_command` remains the explicit high-risk shell compatibility path.
- Process results now expose terminal state inputs needed by `exec_process`: exit code, timeout, cancellation, stdout/stderr truncation and omitted-byte counts.
- Process-tree/job/process-group cleanup is preserved for timeout, cancellation and normal parent exit.
- `exec_process` is canonical risk=`high`, effect=`execute`, capabilities=`process.exec` + `network.open_world`.
- Restricted and workspace-auto policies deny direct process execution; legacy-command-compatible preserves the pre-existing trusted execution authority; custom policy can permit direct exec without granting shell authority when execute/high/open-world are explicitly allowed.

## Environment authority

Default arbitrary host-environment inheritance is disabled for `exec_process`.

The child environment is built from:
1. a documented minimal platform baseline;
2. locally configured allowlist names/glob patterns;
3. bounded request overrides only when the requested name matches local authority.

Security rules:
- allowlist is empty by default beyond the server-supplied baseline;
- secret-like host variables are never forwarded through wildcard patterns;
- secret-like variables require an exact local allowlist entry;
- request overrides cannot replace even baseline variables unless local allowlist authority explicitly permits the name;
- invalid/NUL environment names/values fail closed;
- allowlist patterns, override count/value size/total size, forwarded variable count/value size and total environment size are bounded;
- Windows/macOS desktop settings expose the local allowlist without persisting secret values.

Current hard bounds:
- allowlist patterns: 32;
- request overrides: 32;
- request value: 8,192 characters;
- total request override characters: 16,384;
- forwarded variables: 64;
- forwarded value: 16,384 characters;
- total child environment: 32,000 characters;
- argv entries: 256;
- total argv characters: 32,768;
- per-stream process output limit: caller-lowerable up to 100,000 bytes;
- timeout: 1..120 seconds.

## Compatibility

- `run_command` is retained and documented as the high-risk shell compatibility tool.
- Existing `run_command` host-environment behavior is unchanged in FMG-005.
- Existing Git safe-mode, path containment, local-auth and Secure MCP Tunnel boundaries are unchanged.

## Local evidence

Exact worktree local proofs before commit:
- `tests/test_windows_runtime.ps1`: PASS, 609 assertions, including `windows-exec-process: ok`;
- `tests/test_tool_catalog_contract.py`: PASS, canonical tools=20, SHA-256 `d03c6cd0c4d6582a89e408078e5f4053039f7178d172614256d510f86c137895`;
- `tests/test_tool_surface_parity.ps1`: PASS, canonical=20 with the same catalog hash;
- `tests/test_exec_process_contract.ps1`: PASS;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors;
- `tests/test_project_state_contract.ps1`: PASS;
- `git diff --check`: PASS.

Windows behavioral coverage includes:
- direct argv literal preservation/no FileMCP shell interpolation;
- contained cwd and escape rejection;
- nonzero exit remains process outcome rather than MCP transport failure;
- timeout;
- cooperative cancellation and descendant cleanup;
- bounded stdout/stderr and omitted-byte evidence;
- NUL argv rejection;
- forbidden environment override;
- baseline override denial without local authority;
- wildcard suppression of secret-like host variables;
- exact secret-like allowlist authority;
- wildcard environment fan-out bounds;
- total argv bounds.

macOS native test coverage is wired into `tests/test_swift_runtime.sh` and GitHub Verify for:
- direct argv;
- cwd containment/escape;
- nonzero exit;
- timeout;
- process cancellation and descendant cleanup;
- output exhaustion/truncation;
- NUL argv;
- total argv bound;
- environment allow/deny;
- secret wildcard suppression;
- environment fan-out bounds;
- policy exposure/denial parity.

Local native Swift execution is environment-blocked on this Windows host because `/bin/bash`/Swift are unavailable. This is not classified PASS or FAIL; native macOS GitHub Verify is mandatory before merge.

## Remaining gate

Commit the exact candidate -> push -> PR -> require native Verify macOS + Windows x64 + Windows ARM64 -> scoped review -> merge only the exact green head -> verify merged main -> mark FMG-005 DONE / MAIN VERIFIED -> claim next READY task. Do not start FMG-006 before FMG-005 MAIN VERIFIED.
