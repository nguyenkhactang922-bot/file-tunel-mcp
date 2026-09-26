# FMG-007 AuthorizedPathSnapshot / Mutation Guard Evidence

Status: DONE / MAIN VERIFIED

Branch: `chatgpt/FMG-007-mutation-guard`
Baseline main: `4ce571a8fd22448701cc6ad135a828c2328d12fe`
Depends: FMG-006 DONE / MAIN VERIFIED.

## Implemented scope

- Added internal `AuthorizedPathSnapshotService` on Windows and macOS; no new MCP tool and no catalog change.
- Snapshot authority is object-identity based, not path-string-only.
- Existing targets bind full root-to-parent ancestor identity chain plus final target identity.
- New targets bind full root-to-parent ancestor identity chain plus expected final-leaf absence.
- Verification reruns containment and no-follow/native identity checks immediately before a future mutation caller may commit. FMG-008 will integrate this primitive into current write/delete tools.
- Windows uses `CreateFileW` with `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` plus `GetFileInformationByHandle`, binding volume serial + file index and rejecting ancestor reparse points/junctions.
- macOS uses `lstat` plus no-follow `open(... O_NOFOLLOW ...)` / `fstat`, binding device + inode and rejecting ancestor symlinks.
- Final link objects may be represented as target identities so a future delete operation can explicitly guard the link object itself; unexpected ancestor links remain fail-closed.
- Root authority is included in the ancestor chain, so replacing the shared-root object at the same string path invalidates the snapshot.

## Acceptance / adversarial coverage

Windows native suite covers:
- unchanged existing target verifies;
- same path with replaced target object is rejected;
- same path with replaced parent object is rejected;
- new-target leaf inserted after authorization is rejected;
- missing parent for a new target fails closed;
- ancestor directory swapped to a junction is rejected;
- shared-root object replaced at the same path is rejected.

macOS native harness contains equivalent checks:
- unchanged target;
- target replacement;
- parent replacement;
- inserted new leaf;
- missing new-target parent;
- ancestor symlink swap;
- shared-root replacement.

## Local evidence

- `tests/test_windows_runtime.ps1`: PASS, 637 assertions including `windows-mutation-guard: ok`;
- `tests/test_mutation_guard_contract.ps1`: PASS;
- `python tests/test_tool_catalog_contract.py`: PASS, tools=20, catalog SHA-256 `d39a11012ad61a6d35ae472c5776d0a8488ded080212f72168505e41e11619c3`;
- `tests/test_tool_surface_parity.ps1`: PASS, canonical=20 with same hash;
- `tests/test_file_version_source_state_contract.ps1`: PASS;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors;
- `tests/test_project_state_contract.ps1`: PASS before state transition;
- Git-for-Windows Bash syntax for macOS build/dev/runtime harness: PASS;
- `git diff --check`: PASS.

## Final main verification

- Candidate exact HEAD: `2319488761c845df7be5010dca0283485a41a8e9`.
- Exact candidate push Verify `36166198999`: SUCCESS.
- PR #11 exact-head Verify `36166975957`: macOS / Windows x64 / Windows ARM64 SUCCESS.
- Scoped security review: PASS, no new blocker.
- Merge main: `ad78b0f75564728c7a4aa5dae218d4e79d697569`.
- Merged-main Verify `36167404567`: macOS / Windows x64 / Windows ARM64 SUCCESS.
- Local merged-main: mutation-guard contract PASS; catalog/parity + FMG-006 prerequisite PASS; Release build 0 warnings / 0 errors; Windows runtime 637 assertions PASS.

Result: FMG-007 DONE / MAIN VERIFIED.

## Final closure

- final candidate head: `2319488761c845df7be5010dca0283485a41a8e9`;
- PR #11 merged as main `ad78b0f75564728c7a4aa5dae218d4e79d697569`;
- exact-head Verify runs `36166198999` and `36166975957`: macOS / Windows x64 / Windows ARM64 SUCCESS;
- merged-main native Verify run `36167404567`: macOS / Windows x64 / Windows ARM64 SUCCESS;
- merged-main local Mutation Guard + catalog/parity/FMG-006 prerequisite contracts: PASS;
- merged-main local Windows runtime: 637 assertions PASS;
- merged-main Release build: 0 warnings / 0 errors;
- FMG-007: DONE / MAIN VERIFIED.
