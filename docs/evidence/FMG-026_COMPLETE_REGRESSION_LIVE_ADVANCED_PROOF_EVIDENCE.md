# FMG-026 Complete Regression + Live Advanced Proof Evidence

Status: ACTIVE / PRE-RESTART CHECKPOINT

Branch: `chatgpt/FMG-026-complete-regression`
Base verified main: `59ee366f504160b2132355e3d2dae9ce3b524646`
Depends: FMG-025 DONE / MAIN VERIFIED.

## Frozen acceptance mapping

FMG-026 requires:
- entire original app regression;
- FMG-001..025 regression;
- packaged Windows/macOS/native verification;
- live Secure MCP Tunnel discovery;
- live file/Git/exec/evidence proof;
- live artifact/batch/quarantine/edit/repo-intelligence/PTY/checkpoint proof;
- optional Docker backend proof according to availability rule;
- final docs/state/evidence plus review/merge/main verification.

The existing `.github/workflows/verify.yml` is the authoritative native regression/package gate. It already executes the Windows release/tool-surface/catalog/exec/PTY/backend/Docker/adversarial/file-version/mutation/edit/repository/project-context/evidence/artifact/batch/quarantine/checkpoint/supervisor/connection-health/signing contracts, Windows integration runtime, x64 + arm64 packaging/smoke, native Windows ARM64 verification, and native macOS static/runtime/build/resource verification. FMG-026 therefore does not add a fake duplicate PASS wrapper merely to re-run the same contracts locally.

## Runtime resume check

No FMG-026 build/test process was alive at resume. The durable task checkpoint was the FMG-026 claim/inventory state, so work resumed from inventory rather than restarting FMG-025 or any previously MAIN VERIFIED task.

Existing bridge processes were preserved:
- FileMCP desktop PID `16240`;
- live executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`;
- live executable SHA-256: `69c86f752321ef318c4ddd27dd566a9883a98fea774cd5fc021ec72b92117a7d`;
- tunnel process PID `10896` for `filemcp`;
- tunnel process PID `15204` for `filemcp-e`.

No process was restarted or duplicated during discovery.

## Live tunnel discovery - PASS

Both existing tunnel health endpoints are live without restart:
- `filemcp`: `/healthz` = HTTP 200 `live`; `/readyz` = HTTP 200 `ready`;
- `filemcp-e`: `/healthz` = HTTP 200 `live`; `/readyz` = HTTP 200 `ready`;
- tunnel metrics expose successful `tools/call` forwarding with service status 200.

## Live basic FileMCP proof - PASS

Using one live FileMCP logical-chat correlation handle:
- correlation establishment: PASS;
- live `write_file`: PASS on a dedicated temporary proof file;
- live `read_file`: PASS and returned a strong content version;
- live versioned `apply_edits`: PASS with `committed=true`, `edits_applied=1`;
- reread verified the edited content;
- live `git_status`: PASS and correctly identified the proof file as untracked;
- live `exec_process`: PASS with marker `FMG026_EXEC_LIVE_OK`, exit code 0;
- live `project_context`: PASS, schema `1.0.0`, repository-untrusted context, `grants_authority=false`;
- live `evidence_get` dispatch/error contract: PASS; a syntactically valid nonexistent id reached the handler and returned `Evidence record not found`;
- the temporary proof file was deleted with its expected strong version and the worktree returned clean.

No secret, request body, file content, command payload, prompt text, or auth token is persisted in this evidence.

## Canonical source vs currently discovered live tool surface

Canonical source catalog:
- tool count: `46`;
- SHA-256: `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`.

Current ChatGPT/FileMCP connector discovery exposes only `22` FileMCP functions. The currently undiscovered advanced canonical functions are:
- `batch_stat`, `batch_read`;
- `quarantine_delete`, `quarantine_list`, `quarantine_get`, `quarantine_restore`;
- `apply_search_replace`, `apply_unified_diff`;
- `repo_map`, `symbol_search`, `related_files`;
- `checkpoint_capture`, `checkpoint_list`, `checkpoint_get`, `checkpoint_restore`, `checkpoint_delete`;
- `pty_start`, `pty_read`, `pty_write`, `pty_resize`, `pty_signal`, `pty_stop`, `pty_list`;
- `run_command`.

Therefore the FMG-026 live advanced proof CANNOT yet be truthfully marked PASS on the currently connected desktop/connector. This is a deployment/discovery blocker, not a source contract failure.

## FMG026-ready x64 deployment candidate - PREPARED

A current-source x64 binary was published into a separate staging directory without touching the live bridge:
- directory: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready`;
- executable SHA-256: `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`;
- executable size: `166250417` bytes;
- bundled catalog tool count: `46`;
- bundled catalog SHA-256: `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`;
- bundled catalog hash exactly matches canonical source;
- archive: `D:\Tools\FileMCP\dist\FileMCP-FMG026-ready-windows-x64.zip`;
- archive SHA-256: `db0b0d8e31362d29e5e41554f305c84881b560fd1cdf39cabe976bfd2a0ad9aa`;
- archive size: `75548577` bytes.

Publish used existing restored assets with `--no-restore`; this avoids falsely changing source to compensate for FileMCP `exec_process` minimal-environment NuGet restore behavior. Native CI remains authoritative for clean restore/build/package verification.

Local packaged-app GUI smoke is intentionally NOT run while PID `16240` owns the global `FileMCP.Desktop.v1` single-instance coordinator. Killing/restarting the active bridge merely to make the smoke pass would violate the resume/anti-duplicate rules. Native CI provides the independent packaged smoke environment.

## Optional Docker live proof - ENVIRONMENT BLOCKED

Docker CLI is present, but the Docker engine pipe is absent and `docker version` cannot connect to the daemon. Per the frozen FMG-024/FMG-026 availability rule, contract verification remains valid but live isolated-Docker execution must remain explicitly `ENVIRONMENT BLOCKED`; no fake live Docker PASS is claimed.

## Current checkpoint

PASS so far:
- FMG-025 dependency and merged-main verification;
- FMG-026 inventory/proof mapping;
- live Secure MCP Tunnel health/readiness;
- live basic file/Git/exec/project-context/evidence dispatch proof;
- current-source FMG026-ready x64 package preparation with canonical 46-tool catalog;
- optional Docker availability classification.

BLOCKED pending deployment/connector rediscovery:
- live artifact/batch/quarantine/edit-adapter/repo-intelligence/PTY/checkpoint proof on the canonical 46-tool connector surface.

NEXT_EXACT_ACTION: commit/push this checkpoint on the exact FMG-026 head and require the normal native Verify workflow as the full regression/package gate. Repair only a real failed stage. After exact-head native Verify is green, preserve that PASS; then the active FileMCP desktop must be replaced by `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe` and ChatGPT connector discovery must expose the canonical 46-tool surface. Resume LIVE ADVANCED PROOF ONLY from that checkpoint; do not rerun the already-green native regression. After live advanced proof passes, update evidence/state, push the closure head, review/PR/merge, require merged-main Verify, and only then create/mark `COMPLETE_UPGRADE_MAIN_VERIFIED` evidence and FMG-026 DONE.


## Exact-head native full regression checkpoint - 2026-10-03

PASS on exact branch head `21d0c6ed05a749be363b108a7a965a7f0deaef9e`:
- push Verify run `37109212534`: SUCCESS;
- macOS native static verification: PASS;
- macOS native integration runtime: PASS;
- macOS app build + bundled-resource verification: PASS;
- Windows x64 complete contract matrix FMG-001..025: PASS;
- Windows x64 integration runtime: PASS;
- Windows x64 + arm64 release builds: PASS;
- Windows packaged app smoke: PASS;
- native Windows ARM64 complete advanced contract matrix: PASS;
- native Windows ARM64 release build/package/smoke/resources: PASS.

This full regression/package checkpoint is now frozen PASS and MUST NOT be rerun merely because the FileMCP desktop is replaced/reconnected for the remaining live advanced proof.

Remaining blocker only:
- the active desktop/connector still exposes 22/46 tools;
- replace the active desktop with `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe` and reconnect ChatGPT/FileMCP until connector discovery exposes all 46 canonical tools;
- then resume LIVE ADVANCED PROOF ONLY for artifact/batch/quarantine/edit-adapter/repo-intelligence/PTY/checkpoint surfaces.

Do not mark FMG-026 DONE and do not create `COMPLETE_UPGRADE_MAIN_VERIFIED` evidence until the live advanced proof and final merge/main verification both pass.


## Live advanced proof after FMG026-ready runtime swap - 2026-10-03

Status: **LIVE ADVANCED PROOF PASS / GITHUB CLOSURE PENDING**.

Runtime and transport truth:
- active desktop PID `17860` is `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG026-ready\FileMCP.exe`;
- executable SHA-256 is `07330f6a9af2609d4cd96b80c18503066953f2dc3152d91a1c46ffdfb998be23`;
- `filemcp` and `filemcp-e` tunnel clients are children of this runtime and both report `/healthz=live` and `/readyz=ready`;
- local MCP endpoints are `127.0.0.1:8008/mcp` and `127.0.0.1:8010/mcp`;
- canonical catalog remains `1.13.0` / `46` tools / SHA-256 `429cc8cef94900f034798e10e9beac28aaadbb23b6fd5458611fb335a71c239c`;
- active local policy is custom/high with every effect allowed and open-world execution allowed, but `CustomPolicyAllowShell=false`; therefore the effective policy-filtered surface is intentionally `45/46`, with only compatibility shell tool `run_command` hidden. No shell authority was enabled merely to increase the visible count.

Live advanced surface proof used one opaque FileMCP logical-chat correlation handle and a dedicated temporary fixture outside the Git repository. No secret, prompt text, command payload, file payload, auth token, or bearer credential is persisted in this evidence.

### Batch + Artifact / ContentRef - PASS

- `batch_stat`: `3/3` fixture files completed, `partial=false`.
- `batch_read`: small file delivered inline; bounded read of a `1248`-byte file with `max_bytes=64` and `allow_content_ref=true` returned a real authenticated ContentRef.
- spilled blob identity: `sha256:72577538da4aa02f35769e123f0fcf7c0e8a592c334ca63e0b8df50437538316`.

### Quarantine delete/list/get/restore - PASS

A versioned fixture file completed the full transaction:
- dry-run source/version validation PASS;
- authenticated quarantine creation PASS;
- metadata `list` and `get` PASS;
- manifest hash `sha256:e22512310052af93326d8d9eb79e527ca962510de26a39c8215e97939b287ff0`;
- restore to the original path PASS.

### Model-friendly edit adapters - PASS

On a versioned fixture:
- `apply_search_replace` committed one unambiguous edit (`alpha` -> `ALPHA`);
- `apply_unified_diff` committed one validated hunk (`beta` -> `BETA`);
- reread verified the final `ALPHA / BETA / gamma` content.

### Repository intelligence query facade - PASS on bounded live Git fixture

A disposable two-file C# Git fixture was initialized and staged under the live workspace:
- `repo_map`: PASS, `2/2` files, provider `lexical-symbols` `1.0.0`, `grants_authority=false`, `raw_source_persisted=false`;
- source state identity: `sha256:6cacef9af0d8fab1395414b2ebe75bf9e1550f0078777e71d127ec66f5874629`;
- `symbol_search("Program")`: PASS with one exact type result at `Program.cs:3`;
- `related_files("Program.cs")`: PASS with a valid empty-result envelope.

Nuance: the first `repo_map` request against the full FileMCP repository reached the live handler but returned an upstream `502` while the corresponding large-repository intelligence cache did not yet exist. Source inspection confirms an uncached first request must build a bounded full generation before cache publication. The bounded live Git fixture proves the runtime query facade itself is operational; the existing FMG-018/FMG-019 repository-intelligence contract/runtime suites remain covered by frozen full regression Verify `37109212534`. No production repair is claimed or introduced from the one large-repository transport timeout.

### Workspace checkpoint capture/restore/delete - PASS

On the disposable Git fixture:
- `checkpoint_capture`: PASS with two staged files, independent staged/worktree hashes and manifest hash `sha256:275374b689e4450979ac2988010c652d9e494285a5f7b37ca1fde8493eab27de`;
- `checkpoint_list` / `checkpoint_get`: PASS;
- controlled worktree drift + one untracked file was introduced;
- restore dry-run returned `state=planned`, `path_count=3`;
- transactional restore returned `state=restored`, `recovered_incomplete=false`, `cleanup_pending=false`;
- post-restore Git state returned to only the original two staged files, original bytes were verified, and the untracked drift file was removed;
- `checkpoint_delete`: PASS.

### Native PTY - PASS

Windows ConPTY live proof:
- `pty_start`: PASS with `actual_pty=true`, `pty_backend=windows-conpty`, `grants_authority=false`;
- `pty_list`: PASS;
- `pty_resize`: PASS;
- `pty_write` + `pty_read`: PASS with marker `FMG026_PTY_OK`;
- `pty_signal(ctrl_c)`: PASS;
- `pty_stop`: PASS and final list recorded the session as stopped.

### Fixture cleanup - PASS

The proof fixture was fully removed from the shared root. Direct recursive deletion was blocked by the external safety layer after a successful dry-run, so cleanup used the safer authenticated quarantine path. A read-only Git object created by Git was the only failed cleanup substage; its read-only attribute was cleared on the disposable fixture only, then the retry quarantined the remaining tree successfully. Final `Test-Path D:\.fmg026-live-proof` = `False`.

### Final local FMG-026 acceptance checkpoint

PASS and preserved:
- native complete regression/package Verify `37109212534` on macOS / Windows x64 / native Windows ARM64 (do not rerun merely for closure);
- Secure MCP Tunnel live/readiness proof;
- prior basic live file/Git/direct-exec/project-context/evidence proof;
- live artifact/ContentRef + batch proof;
- live quarantine transaction proof;
- live edit-adapter proof;
- live repository-intelligence facade proof on a bounded Git fixture;
- live checkpoint transaction proof;
- live native Windows ConPTY proof;
- proof-fixture cleanup;
- canonical catalog identity and correct policy-filtered `45/46` effective surface, with `run_command` intentionally hidden because shell authority is disabled.

Optional Docker live engine proof remains **ENVIRONMENT BLOCKED** because the local Docker daemon is unavailable; the frozen availability rule permits this explicit limitation and no fake Docker PASS is claimed.

FMG-026 is **not DONE yet**. `COMPLETE_UPGRADE_MAIN_VERIFIED` must not be recorded until the closure candidate is committed, pushed to the writable GitHub remote, exact-head required checks are green, the reviewed head is merged to `main`, and the resulting `main` passes its required merged-main verification.

NEXT_EXACT_ACTION: review closure-only diff and state contract -> commit exact closure candidate -> inspect real remote branch/PR state before side effects -> push exact candidate -> require exact-head GitHub Verify/checks -> review/create exactly one PR to `main` -> merge the exact reviewed head -> verify resulting `main` -> record `COMPLETE_UPGRADE_MAIN_VERIFIED` / FMG-026 DONE only from real post-merge evidence.
