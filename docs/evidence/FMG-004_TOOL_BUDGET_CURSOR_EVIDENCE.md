# FMG-004 ToolBudget / Cancellation / Cursor Core Evidence

Date: 2026-09-25
Task: FMG-004
Branch: `chatgpt/FMG-004-toolbudget-cursor`
Status: DONE / MAIN VERIFIED

## Implemented scope

- common server-owned ToolBudget caps on Windows/macOS;
- caller-lower-only budget metadata `io.filemcp/budget`;
- cooperative cancellation/deadline checks inside bounded list/search loops;
- usage/truncation metadata integrated into the FMG-002 structured result envelope;
- budget support intentionally limited to `list_files`, `search_content`, and `search_filenames`;
- budget metadata on unsupported tools fails closed;
- authenticated HMAC-SHA256 cursor core on Windows/macOS;
- cursor binding to tool/options/root/generation/position/expiry;
- process-local random cursor keys provide restart invalidation;
- cursor metadata remains fail-closed until later cursor-consuming tools explicitly opt in.

## Negative/security proof

- caller cannot raise server caps;
- unknown budget fields rejected;
- cancellation and timeout mark bounded truncation;
- budgeted scans stop before exceeding caller byte/file/output limits;
- tampered cursor rejected;
- tool/options/root/generation mismatches rejected;
- expired and oversized cursors rejected;
- cursor from a restarted process key rejected;
- unsupported cursor metadata rejected at MCP dispatch;
- policy authorization remains before and after metadata preparation;
- canonical tool catalog hash remains unchanged.

## Local verification

- `python tests/test_tool_catalog_contract.py`: PASS, tools=19, canonical hash unchanged.
- project-state-contract: PASS.
- tool-surface-parity: PASS.
- macos-supervisor-contract: PASS.
- http-connection-bounds-contract: PASS.
- dynamic-health-discovery-contract: PASS.
- windows-arm64-assurance-contract: PASS.
- windows-single-instance-contract: PASS.
- windows-release-contract: PASS.
- Git Bash syntax for Swift/build scripts: PASS.
- Windows Release build `-warnaserror`: PASS, 0 warnings / 0 errors.
- Windows runtime suite: PASS, 573 assertions.
- `git diff --check`: PASS.

## Native acceptance still required

Before FMG-004 can be DONE / MAIN VERIFIED:
1. commit/push exact candidate;
2. native Verify must succeed on macOS, Windows x64 and Windows ARM64;
3. scoped review exact head;
4. merge candidate PR to fork main;
5. rerun native Verify on merged main;
6. rerun local merged-main Windows build/runtime;
7. update state and only then claim FMG-005.

## Final closure

- final candidate head: `6e90b2c049e9a85ac408853c9e593a76d8617f54`;
- PR #7 merged to fork `main` as `9e65230a672cac533f74d6b007f2f08ce83d8687`;
- final exact-head Verify runs `36113893848` and `36113898863`: macOS SUCCESS, Windows x64 SUCCESS, Windows ARM64 SUCCESS;
- merged-main native Verify run `36114335810`: macOS SUCCESS, Windows x64 SUCCESS, Windows ARM64 SUCCESS;
- merged-main local Windows runtime: 576 assertions PASS;
- merged-main Release build: 0 warnings / 0 errors;
- FMG-004: DONE / MAIN VERIFIED.
