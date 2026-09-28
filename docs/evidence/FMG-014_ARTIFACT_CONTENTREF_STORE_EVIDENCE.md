# FMG-014 — Ephemeral Artifact / ContentRef Store Evidence

Status: LOCAL VERIFIED / CROSS-PLATFORM CI PENDING

Branch: `chatgpt/FMG-014-artifact-contentref-store`

## Frozen scope

Implemented only the FMG-014 advanced service frozen by ADR-0006:

- content-addressed local blob store outside the repository;
- independent metadata index;
- opaque authenticated `cr1` ContentRef;
- binding to installation identity, workspace authority, blob digest, content class, reference id, expiry and optional lease expiry;
- explicit `TOOL_OUTPUT`, `PTY_OUTPUT`, `CHECKPOINT`, `QUARANTINE` classes;
- per-item / per-workspace / global quotas;
- TTL garbage collection;
- current-user-only Windows ACL and macOS POSIX permissions;
- streaming write/read paths;
- no artifact bytes in telemetry/evidence stores.

## Implementation

Windows:
- `windows/src/FileMCP.Core/ArtifactContentStore.cs`

macOS:
- `macos/ArtifactContentStore.swift`

Cross-platform contract:
- `tests/test_artifact_contentref_contract.ps1`

Native tests:
- Windows integration: `windows/tests/FileMCP.Core.Tests/Program.cs`
- macOS integration: `tests/test_swift_runtime.sh`

Build/Verify wiring:
- `build_macos_app.sh`
- `.github/workflows/verify.yml`

## Security / authority contract

- ContentRef is not a filesystem path and there is no path-to-ref API.
- ContentRef authentication uses HMAC-SHA256 over the bound capability payload.
- Store installation identity/key is local and protected by artifact-root permissions.
- Resolution rejects wrong workspace, wrong installation/authentication, expired ref, expired lease, denied content class and metadata mismatch.
- Blob integrity is revalidated from size + SHA-256 before resolution/copy.
- Artifact root can be explicitly checked against a workspace/repository root and fails closed when nested inside it.
- Windows root/blob/index permissions are current-user-only ACL.
- macOS root/blob/index permissions are owner-only POSIX `0700/0600`.
- Artifact storage remains independent from evidence/telemetry content stores.

## Failure / negative coverage

Covered in native tests:
- ContentRef tamper;
- cross-workspace replay;
- cross-installation/authentication mismatch;
- current content-class policy denial;
- ref expiry;
- lease expiry independent from ref TTL;
- metadata/blob binding mismatch;
- digest/size corruption;
- per-item/workspace/global quota refusal;
- quota failure leaves no partial durable artifact;
- simulated disk-full/index-commit failure rolls back newly published blob;
- concurrent put of identical bytes deduplicates one content-addressed blob;
- concurrent/final delete removes the final unreferenced blob;
- artifact-root-inside-repository rejection;
- permission regression check;
- TTL GC removes expired refs/orphan blobs;
- evidence-store separation.

## Local verification

PASS on Windows:
- `./tests/test_artifact_contentref_contract.ps1`
  - result: `artifact-contentref-contract: ok`
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror`
  - result: PASS, 0 warnings, 0 errors
- `dotnet run --project windows/tests/FileMCP.Core.Tests/FileMCP.Core.Tests.csproj -c Release`
  - result: PASS
  - `windows-artifact-contentref-store: ok`
  - total: `windows-core-tests: ok (776 assertions)`

Local Windows host does not provide macOS `swiftc`; exact-head native macOS compile/integration proof is therefore intentionally delegated to the existing macOS Verify lane.

## Remaining gate

1. commit local verified candidate;
2. merge latest `fork/main` without losing FMUX state;
3. push exact candidate head;
4. require native Verify SUCCESS on macOS + Windows x64 + Windows ARM64;
5. scoped review;
6. PR/merge;
7. merged-main Verify SUCCESS on all three native lanes;
8. mark FMG-014 DONE / MAIN VERIFIED;
9. claim FMG-015 only after step 8.


## Post-main-sync local verification

Synced foundation/UI main through `7e8590a` (FMUX-003 merged) without dropping FMG-014 scope.

PASS after sync:
- project-state contract;
- FMUX app-shell contract;
- FMUX canonical feedback-components contract;
- FMG-014 artifact ContentRef contract;
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror`: 0 warnings / 0 errors;
- Windows core integration: `windows-artifact-contentref-store: ok`, 776 assertions.

NEXT: finalize merge commit, push exact head, require native macOS + Windows x64 + Windows ARM64 Verify.
