# FMG-003 Server-Owned Policy + Migration Evidence

Date: 2026-09-25
Task: FMG-003
Branch: `chatgpt/FMG-003-server-policy`
Status: LOCAL VERIFIED / NATIVE CI PENDING

## Implemented scope

- server-owned policy profiles: `restricted`, `workspace-auto`, `custom`, migration-only `legacy-command-compatible`;
- legacy migration: `EnableCommands=false -> restricted`, `EnableCommands=true -> legacy-command-compatible`;
- legacy profile excluded from normal UI selection;
- canonical policy hash + generation on Windows/macOS;
- effective tool-catalog filtering from canonical risk/effect/capability metadata;
- runtime authorization independent from tool visibility;
- prepared policy snapshots rejected after generation/hash change;
- settings/UI persistence for explicit local profile choice;
- custom shell authorization remains separate from legacy unsafe-Git compatibility;
- policy metadata exposed in MCP discovery/tools list.

## Security / negative proof

- workspace-auto denies `run_command` and external `git_push` while allowing local workspace mutation;
- direct call of hidden denied tool is rejected;
- custom low/read policy denies broader effects;
- custom shell can explicitly authorize shell without weakening Git safe mode;
- migration-only legacy profile is not user-selectable through normal UI;
- repository/model content has no policy mutation tool;
- stale prepared operation is rejected after policy update;
- canonical catalog visibility and runtime authorization both consult ServerPolicy.

## Local Windows verification

- `python tests/test_tool_catalog_contract.py`: PASS, tools=19, canonical hash unchanged.
- `tests/test_tool_surface_parity.ps1`: PASS.
- `tests/test_windows_runtime.ps1`: PASS, 539 assertions.
- Windows server-policy MCP integration: PASS.
- Windows Release solution build with warnings-as-errors: PASS, 0 warnings / 0 errors.
- `git diff --check`: PASS.

## macOS/local-host limitation

The current Windows host does not provide `/bin/bash`/Swift. Attempts to invoke bash reported `/bin/bash` unavailable. This is classified `AUDIT-ENVIRONMENT-BLOCKED`, not PASS or FAIL.

Native Swift wiring is present in:
- `.github/workflows/verify.yml`;
- `build_macos_app.sh`;
- `run_macos_dev.sh`;
- `tests/test_swift_runtime.sh`.

`tests/test_swift_runtime.sh` includes a dedicated ServerPolicy Swift compile/test fixture plus full runtime wiring. Native macOS GitHub Verify on the exact pushed head is mandatory before FMG-003 can be DONE.

## Remaining gate

Commit exact candidate -> push -> PR to fork main -> native Verify macOS + Windows x64 + Windows ARM64 -> scoped review -> merge -> verify merged main -> mark FMG-003 MAIN VERIFIED -> claim next READY task according to dependency graph.
