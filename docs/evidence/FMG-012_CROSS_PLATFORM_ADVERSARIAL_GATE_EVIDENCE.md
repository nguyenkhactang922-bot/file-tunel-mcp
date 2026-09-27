# FMG-012 Cross-Platform Adversarial Contract Gate Evidence

Status: ACTIVE / LOCAL VERIFIED / FINAL-HEAD NATIVE CI PENDING

Branch: `chatgpt/FMG-012-cross-platform-gate`
Baseline main: `ddc8b27839469dcc5a6ff36bb531cf0b3dda87aa`
Depends: FMG-001 through FMG-011 DONE / MAIN VERIFIED.

## Gate scope

FMG-012 adds no product feature. It verifies the complete Phase A foundation contract across catalog/schema parity, adversarial security/failure semantics, Windows runtime/build/package evidence, and native macOS/Windows x64/Windows ARM64 CI. Any code change would require a concrete failing stage.

## Local contract/adversarial evidence

PASS:
- canonical tool catalog contract: 23 tools, catalog SHA-256 `8c5365afc0ae89e417c144ba77bbdc6a068e3fdbeefd92d674a62e1647c69d91`;
- tool-surface parity;
- project-state authority contract;
- structured exec_process contract;
- strong file version + SourceStateRef contract;
- Mutation Guard contract;
- existing mutation hardening contract;
- atomic versioned apply_edits contract;
- project-context provenance/digest contract;
- metadata-only evidence/freshness contract;
- dynamic health discovery;
- HTTP connection bounds;
- macOS supervisor contract;
- release secret provisioning;
- release signing contract;
- Windows ARM64 assurance contract;
- Windows release contract;
- Windows single-instance contract.

## Windows runtime/build evidence

- `tests/test_windows_runtime.ps1`: PASS, 750 assertions.
- `dotnet build windows/FileMCP.Windows.sln -c Release -warnaserror --nologo`: PASS, 0 warnings / 0 errors.
- x64 package built successfully in isolated staging `FileMCP-FMG012-x64`; ZIP SHA-256 `1F41305267ACA571160856B6CDABECDC6DE35253C51152B0ECAD304D9B7CCD66`.
- ARM64 package built successfully in isolated staging `FileMCP-FMG012-arm64`; ZIP SHA-256 `787DA403C59B2D1750CC96F6806D54F756CE1BC7D24C4D3430A09AA4CB320BDD`.
- x64 package static integrity PASS; packaged canonical catalog hash `98ba484931717cc7ee8efbce83941afc33aa5fbaddb6b667882100a423bfacee`; packaged tunnel-client version `0.0.12+881c9a8fed7cccbe6607cd419863bbca506b8215`.
- ARM64 package static integrity PASS; packaged canonical catalog hash matches source; required executable/license/notice payloads present.

## Local packaged GUI smoke classification

Full local `tests/test_windows_app.ps1` is ENVIRONMENT-BLOCKED, not FAIL: the active FileMCP desktop instance at `D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe` is the live MCP bridge for this ChatGPT session and owns fixed desktop singleton `FileMCP.Desktop.v1`. Killing it would destroy the execution bridge and violate resume/source-of-truth rules. Packaging was therefore built in separate staging directories; native GitHub Windows jobs provide authoritative isolated app-smoke evidence.

## Native CI evidence

Claim-head `68af212b67889a10f2584b670748fb32ce352e0d` Verify run `36297166252`: SUCCESS on macOS, Windows x64 and Windows ARM64.

Because this evidence/state document is a new final candidate commit, merge still requires native Verify on the exact final FMG-012 head after this document is pushed.

## Remaining gate

Commit/push exact evidence candidate -> require exact-head Verify macOS + Windows x64 + Windows ARM64 -> scoped review -> PR/merge only green exact head -> merged-main local/native confirmation -> mark FMG-012 DONE / MAIN VERIFIED -> then claim FMG-013.
