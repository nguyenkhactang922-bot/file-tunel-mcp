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
