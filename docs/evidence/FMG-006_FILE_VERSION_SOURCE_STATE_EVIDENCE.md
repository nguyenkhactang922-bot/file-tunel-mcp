# FMG-006 Strong File Version + SourceStateRef Evidence

Status: ACTIVE / LOCAL VERIFIED / NATIVE CI PENDING

Branch: `chatgpt/FMG-006-file-version-source-state`
Baseline main: `ec4f762c811be658cf9d5a82e0300ee7e79ef2ba`
Depends: FMG-001 and FMG-002 DONE / MAIN VERIFIED.

## Implemented scope

- Added strong opaque/authenticated `v1` file-version tokens on Windows and macOS.
- Tokens bind a one-way canonical path fingerprint, native filesystem identity, entry type, size/timestamp state and full content SHA-256.
- Windows native identity uses volume serial + file index from `GetFileInformationByHandle`; macOS uses `st_dev` + `st_ino` from `fstat`. Raw path/native identity/content is not embedded.
- HMAC-SHA-256 signing key is process-local and shared across runtime clones; restart invalidates old authenticated mutation tokens by design.
- `read_file` and `read_file_range` preserve legacy text/content behavior and add `version`, `version_strength=content`, and `size_bytes` structured metadata.
- Canonical tool catalog is version `1.1.0`; tool count remains 20 (FMG-006 adds no new MCP tool).
- Added internal `SourceStateRef` provider version `source-state-v1`.
- Repository scope binds worktree fingerprint, HEAD identity, index fingerprint, tracked-dirty fingerprint, untracked fingerprint, catalog hash and policy generation/hash.
- Narrow relevant-file scope omits global HEAD identity and instead binds scoped HEAD/index/dirty/untracked state plus stable file-version refs so unrelated changes do not create false staleness.
- SourceStateRef persists only metadata/digests/fingerprints; no raw diff, file content, or raw scoped path names.
- SourceStateRef uses stable version fingerprints rather than process-local HMAC tokens, so its freshness identity is not needlessly rotated with the token signing key.
- File hashing for source-state changes is aggregate-bounded to 50 MB; eligible per-file strong version refs remain bounded by the existing 5 MB read limit.

## Negative/acceptance coverage

Windows native tests cover:
- same-size content change with original mtime restored -> stale;
- replacement object with same content/mtime -> target replaced;
- tampered token -> authentication failure;
- token replay on another path -> path/scope mismatch;
- unchanged file -> deterministic token/version fingerprint within process;
- read/read_range expose the same complete-file strong version;
- repository SourceStateRef changes on tracked dirty state;
- narrow SourceStateRef changes on relevant tracked/untracked state;
- narrow SourceStateRef does not change for unrelated tracked/untracked state;
- serialized narrow SourceStateRef contains neither raw source content nor raw scoped path name.

macOS native test harness contains equivalent assertions and is wired into GitHub Verify. Local native execution is environment-blocked on this Windows host because `swiftc` is unavailable; this is neither PASS nor FAIL until native CI runs.

## Local evidence

- `python tests/test_tool_catalog_contract.py`: PASS, tools=20, catalog SHA-256 `d39a11012ad61a6d35ae472c5776d0a8488ded080212f72168505e41e11619c3`;
- `tests/test_tool_surface_parity.ps1`: PASS, canonical=20 with same hash;
- `tests/test_file_version_source_state_contract.ps1`: PASS;
- `tests/test_windows_runtime.ps1`: PASS, 627 assertions including `windows-file-version-source-state: ok`;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors;
- `tests/test_project_state_contract.ps1`: PASS before state transition;
- `git diff --check`: PASS;
- Git-for-Windows Bash syntax for macOS build/dev/runtime harness: PASS.

## Remaining gate

Commit/push exact candidate -> native Verify macOS + Windows x64 + Windows ARM64 -> fix only exact failing stage if any -> scoped security/privacy review -> PR/merge exact green head -> merged-main local + native verification -> mark FMG-006 DONE / MAIN VERIFIED -> only then claim FMG-007.
