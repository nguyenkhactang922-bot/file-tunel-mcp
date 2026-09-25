# FMG-005 Structured exec_process + Environment Authority Candidate Evidence

Status: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING
Branch: chatgpt/FMG-005-exec-process
Baseline main: 9e65230a672cac533f74d6b007f2f08ce83d8687

## Implemented

- canonical exec_process tool added; canonical catalog now contains 20 tools;
- executable + argv direct process launch with no FileMCP implicit shell interpolation;
- contained cwd enforced by existing path resolver;
- minimal platform environment baseline;
- local environment allowlist with wildcard pass-through and exact-entry secret protection;
- bounded request environment overrides;
- Windows and macOS settings/UI path for local allowlist configuration;
- policy filtering and second authorization immediately before side effect;
- process timeout, FMG-004 cooperative budget cancellation, child cleanup and output bounds;
- structured terminal_state / exit_code / stdout / stderr / truncation metadata;
- run_command preserved and documented as high-risk shell compatibility path;
- Windows/macOS schema validators support bounded array/object arguments for the structured tool;
- macOS compile wiring includes ExecProcessEnvironmentAuthority.swift in build/dev/CI/runtime/server paths.

## Negative/adversarial proof

Windows focused LocalTools proof covers:
- literal argv / no FileMCP shell interpolation;
- cwd containment and escape rejection;
- forbidden environment override;
- wildcard secret-like host variable suppression;
- exact secret-like local authority;
- NUL argv rejection;
- process timeout;
- FMG-004 budget cancellation;
- direct cancellation + descendant cleanup;
- stdout/stderr truncation and omitted-byte metadata;
- nonzero exit returned as successful MCP tool result with exit_code.

macOS native test harness now covers:
- ProcessRunner timeout + descendant cleanup;
- ProcessRunner cooperative cancellation + descendant cleanup;
- environment authority wildcard secret suppression / exact secret allowlist / forbidden override;
- restricted-policy hidden exec_process versus legacy full policy exposure;
- literal argv, cwd containment/escape, nonzero exit, timeout, FMG-004 budget cancellation, output exhaustion, NUL argv, forbidden and allowed request environment overrides.

## Local gates

- python tests/test_tool_catalog_contract.py: PASS, tools=20, sha256=d03c6cd0c4d6582a89e408078e5f4053039f7178d172614256d510f86c137895
- tests/test_tool_surface_parity.ps1: PASS, canonical=20
- tests/test_exec_process_contract.ps1: PASS
- tests/test_project_state_contract.ps1: PASS
- Git Bash syntax for macOS build/dev/runtime scripts: PASS
- dotnet Release build -warnaserror: PASS, 0 warnings / 0 errors
- tests/test_windows_runtime.ps1: PASS, 609 assertions
- git diff --check: PASS
- diff secret/private-key marker scan: no matches

## Remaining acceptance

Native GitHub Verify must succeed on the exact candidate head for:
- verify-macos;
- verify-windows;
- verify-windows-arm64.

After exact-head native success: scoped review, merge to fork main, rerun merged-main Verify, then mark FMG-005 DONE / MAIN VERIFIED. FMG-006 must not start before that.
