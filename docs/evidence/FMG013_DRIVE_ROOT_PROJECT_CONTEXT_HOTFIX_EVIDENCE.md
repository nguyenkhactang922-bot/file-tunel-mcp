# Drive-root Project Context Hotfix Evidence

Status: LOCAL VERIFIED / NATIVE CI PENDING
Date: 2026-10-02
Branch: `chatgpt/FMG013-drive-root-project-context`
Code candidate before evidence-only commit: `416f823e44d227e477262c1fcce867d3169aebc1`
Base main: `f3e4254c5a32d48d95b28372d0eff56880aeb5f5`

## Problem

When FileMCP shared-root authority is an absolute Windows drive root such as `D:\`, `ProjectContextService.Hierarchy` trimmed the trailing root separator before calling `Path.GetRelativePath`.

That transforms an absolute drive root into drive-relative form (`D:` -> `D:` without the separator), allowing relative-path resolution to depend on the process working directory and causing valid project_context scopes to be rejected as escaping the shared root.

## Repair

- Preserve filesystem roots exactly as returned by `Path.GetFullPath`.
- Do not trim the separator from Windows drive roots.
- Add a Windows runtime regression that constructs `SafePathResolver` at the actual drive root and captures a nested project path.

No policy, containment, Git, credential, telemetry, or authority semantics were widened.

## Local verification

PASS:
- `git diff --check fork/main...HEAD`;
- `tests/test_project_context_contract.ps1`: PASS at catalog 1.13.0 / 46 tools;
- Windows test-project build: PASS, 0 warnings / 0 errors using existing restored assets;
- Windows core runtime: PASS, 956 assertions;
- `windows-project-context: ok`;
- live FileMCP `project_context(path="Tools/FileMCP")` succeeds under the D:\ shared-root connector instead of reporting "scope escaped the shared root";
- live FileMCP runtime PID 16240 remains active from the already-swapped local binary.

## Environment note

A standalone `dotnet restore` invocation on this host emitted a local NuGet `Value cannot be null (path1)` error. The exact test-project build with `--no-restore` succeeded with 0 warnings/errors and the 956-assertion runtime passed. Clean-environment restore/build remains an exact-head CI acceptance requirement before merge.

## Next exact action

Push this branch, require exact-head native Verify, perform scoped review, open/merge PR only on green exact head, then require merged-main Verify. Do not weaken ProjectContext containment checks to make the drive-root case pass.
