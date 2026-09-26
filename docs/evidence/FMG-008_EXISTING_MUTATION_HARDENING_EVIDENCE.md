# FMG-008 Existing Mutation Hardening Evidence

Status: DONE / MAIN VERIFIED

Branch: `chatgpt/FMG-008-existing-mutation-hardening`
Baseline main: `ad78b0f75564728c7a4aa5dae218d4e79d697569`
Depends: FMG-007 and FMG-003 DONE / MAIN VERIFIED.

## Implemented scope

- Hardened existing `write_file`, `delete_file`, and `delete_directory`; no replacement mutation engine was introduced.
- Canonical catalog advanced to `1.2.0` while tool count remains 20.
- `write_file` accepts optional `expected_version` for stale-write protection and preserves legacy create/overwrite/append calls when omitted.
- `delete_file` accepts optional `expected_version` for regular-file deletion plus `dry_run`.
- `delete_directory` adds `dry_run` without inventing a whole-tree file-version token.
- All three mutation tools now enter the shared cancellation/budget execution context.
- Existing and new write targets capture FMG-007 AuthorizedPathSnapshot state; final Mutation Guard verification runs immediately before publish/delete.
- Prepared server policy is reauthorized immediately before commit; policy generation/hash changes invalidate the prepared side effect.
- Cancellation is checked before staging/commit boundaries and again immediately before the final side effect.
- `write_file` append now stages through a sibling temporary file and atomic same-volume replacement instead of in-place append, preserving final-commit guard semantics.
- Expected version is checked before preparation and rechecked immediately before commit.
- Root deletion, symlink/reparse semantics, SafePathResolver containment, and existing policy risk/effect classes remain unchanged.

## Acceptance / negative coverage

Windows native suite covers:
- legacy write/overwrite/append without expected_version;
- stale expected-version overwrite rejection with newer content preserved;
- fresh expected-version overwrite success;
- stale expected-version delete rejection;
- delete_file dry-run;
- delete_directory dry-run and legacy recursive delete;
- target object swap after staging rejected by final Mutation Guard;
- delete-race replacement object not deleted;
- cancellation triggered exactly at pre-commit preserves original;
- policy generation removal exactly at pre-commit preserves original.

macOS native harness contains equivalent assertions and prints `swift-existing-mutation-hardening: ok`.

## Candidate verification history

- Production candidate `1230a333a797c913266c33e6cc7283253c46397a` exposed two verification-only issues in Verify run `36211043147`: macOS access-control compile failure and an FMG-005 contract that incorrectly hard-coded the complete budgeted-tool list.
- Follow-up `acdaacf0f99202436c44e8ee4f1595ceaf291d7e` fixed those verification issues and added FMG-008 native/contract coverage; Verify run `36211340078` SUCCESS on macOS / Windows x64 / Windows ARM64.
- Final whitespace-only candidate `35ef237a0f4d32f0940491b9163a0dcbea7e6c61` passed `git diff --check`; exact-head Verify run `36211599491` SUCCESS and PR #12 Verify run `36211866496` SUCCESS on all three platform jobs.

## Local evidence

- `dotnet run --project windows/tests/FileMCP.Core.Tests/FileMCP.Core.Tests.csproj -c Release`: PASS, 655 assertions including `windows-existing-mutation-hardening: ok`;
- `tests/test_existing_mutation_hardening_contract.ps1`: PASS;
- `tests/test_exec_process_contract.ps1`: PASS after compatibility hardening;
- `tests/test_mutation_guard_contract.ps1`: PASS;
- `tests/test_file_version_source_state_contract.ps1`: PASS;
- `python tests/test_tool_catalog_contract.py`: PASS, tools=20, catalog SHA-256 `06f729d69e720833aae975ed4fbc58e3741c0102830d557460d4ca0367e809bf`;
- `tests/test_tool_surface_parity.ps1`: PASS with same hash;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors;
- Bash syntax for macOS build/dev/runtime harness: PASS;
- `git diff --check`: PASS.

## Final main verification

- PR #12 merged exact green candidate `35ef237a0f4d32f0940491b9163a0dcbea7e6c61`.
- Merge main: `8a58a223814505518e581ebe79856846555cb4b4`.
- Merged-main Verify run `36212103370`: SUCCESS on macOS / Windows x64 / Windows ARM64.
- Local merged-main: FMG-005/FM??G-006/FM??G-007/FM??G-008 contracts PASS; catalog/parity PASS; Release build 0 warnings / 0 errors; Windows core 655 assertions PASS.
- Scoped review: PASS; no ServerPolicy, SafePathResolver, or AuthorizedPathSnapshot primitive weakening.

Result: FMG-008 DONE / MAIN VERIFIED.
