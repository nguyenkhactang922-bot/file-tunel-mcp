# FMG-013 Foundation Full Regression + Live MCP Proof Evidence

Status: BLOCKED / CHATGPT CONNECTOR DISCOVERY STALE

Branch: `chatgpt/FMG-013-full-regression-live-proof`
Baseline main: `d3a3670f6fb60ab75d8471b3d982c811337fa951`
Depends: FMG-012 DONE / MAIN VERIFIED.

## Foundation regression status

The underlying source foundation is verified:
- FMG-012 merged-main local contracts/runtime/Release proof PASS; Windows runtime 750 assertions; Release build 0 warnings / 0 errors.
- FMG-012 merged-main native Verify `36297870457`: SUCCESS on macOS / Windows x64 / Windows ARM64.
- FMG-013 claim-head Verify `36298103299` on `6dc2b32d99339cfcc70188925f026d1aacc55add`: SUCCESS on macOS / Windows x64 / Windows ARM64.
- Current source canonical catalog: version `1.6.0`, 23 tools, SHA-256 `98ba484931717cc7ee8efbce83941afc33aa5fbaddb6b667882100a423bfacee`.

## Live connector proof - BLOCKER

The FileMCP desktop currently serving this ChatGPT session is not the latest product binary:
- live process PID: `11960`;
- live executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe`;
- live executable timestamp: `2026-09-22T14:26:46.4876055+07:00`;
- live executable size: `165431146`;
- live executable SHA-256: `7689540f1ff4cc080064eb1ccaf33a5b4a8b1a736b2f10b52988505e6e7c2807`;
- ChatGPT connector tool registry visible in this session: 19 FileMCP tools;
- expected current canonical source registry: 23 tools;
- live blocker re-verified on 2026-09-28: PID `11960`, same old executable/hash, connector still exposes exactly 19 FileMCP tools.

Missing from the currently connected live registry relative to source are the newer foundation tools/capabilities such as `exec_process`, `apply_edits`, `project_context`, and `evidence_get`. Therefore FMG-013 cannot truthfully claim live MCP parity while this old desktop process remains the active connector.

This is a deployment/runtime-state blocker, not a source-code regression.

## Latest ready build

A fresh x64 build from the current source has been prepared without touching the live bridge:
- ready directory: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready`;
- ready executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`;
- ready executable SHA-256: `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`;
- ready packaged catalog SHA-256: `98ba484931717cc7ee8efbce83941afc33aa5fbaddb6b667882100a423bfacee`;
- ready catalog matches source canonical catalog.

The live process cannot be safely killed/restarted from the same FileMCP MCP session because it is the execution bridge carrying the operation itself. Doing so would intentionally sever the source-of-truth control channel before post-restart verification.

## Required resume checkpoint

1. Exit the currently running FileMCP desktop instance normally.
2. Launch `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`.
3. Reconnect/resume ChatGPT/FileMCP.
4. Resume FMG-013 from this checkpoint; do not rerun completed regression gates.
5. Verify live connector advertises the current 23-tool catalog / current catalog hash and exercise the live MCP/correlation proof.
6. If live parity passes, update this evidence to PASS, perform exact-head native Verify/review/merge/main verification, then mark FMG-013 FOUNDATION MAIN VERIFIED.

FMG-014 remains BLOCKED until this live connector proof passes.


## Post-restart live checkpoint - 2026-09-28

FMG-013 remains BLOCKED, but the blocker has narrowed from stale desktop deployment to stale ChatGPT connector discovery.

Verified after reconnect attempt:
- active FileMCP PID: `10688`;
- active executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`;
- active executable SHA-256: `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`;
- ready executable SHA-256: identical;
- Git branch: `chatgpt/FMG-013-full-regression-live-proof`;
- Git HEAD at checkpoint: `8111869c8389959151b4ce4bf8fc7700aadb39f5`;
- working tree before this evidence update: clean;
- current ChatGPT/FileMCP registry exposed to this chat: 19 tools.

Conclusion:
- the desktop/runtime replacement step is PASS;
- the current ChatGPT connector schema is still stale and has not rediscovered the 23-tool catalog;
- do not rerun foundation regression;
- do not claim FMG-013 PASS and do not claim FMG-014;
- NEXT_EXACT_ACTION is LIVE MCP PROOF ONLY after ChatGPT connector rediscovery/reconnection exposes the current 23-tool registry, then verify catalog version/hash and live correlation behavior.


## Live correlation sub-proof - 2026-09-28

PASS on the active FMG-013-ready desktop runtime:
- `filemcp_observability_connect` resumed the existing opaque handle with `resumed=true`;
- a bound `read_file_range` call using the same `_filemcp_chat` handle succeeded against `Tools/FileMCP/AGENTS.md`;
- no restart or regression rerun was needed.

Remaining FMG-013 blocker is now only connector catalog rediscovery/parity: this chat still exposes 19 tools instead of the canonical 23, so catalog version/hash plus the four newly added live tool registrations cannot yet be proven through ChatGPT.


## Reconnect verification - 2026-09-28

A fresh FileMCP logical-chat correlation was established and resumed successfully; a bound read using the same correlation handle PASSed.

Current live runtime evidence:
- FileMCP PID `10688` still runs `D:\Tools\FileMCP\dist\windows-x64\FileMCP-FMG013-ready\FileMCP.exe`;
- executable SHA-256 remains `cc91cc9d16c1c0d95363bc83e5ae3ea2edf45058817182d08736181e68f23d10`;
- tunnel-client D workspace started at `2026-09-28T14:15:45+07:00`;
- `/healthz` = `live`;
- `/readyz` = `ready`;
- tunnel `main` channel reports `probe_status=ok`;
- MCP route is direct to `127.0.0.1:8008`;
- raw HTTP logging is disabled;
- tunnel metrics confirm control-plane commands are being forwarded to the MCP server with successful service status `200`.

The fresh ChatGPT session still exposes exactly 19 FileMCP tools. The four canonical foundation tools absent from the ChatGPT registry remain `exec_process`, `apply_edits`, `project_context`, and `evidence_get`.

A process-memory attempt to recover the transient local-auth token for a direct local `tools/list` probe was blocked by the safety layer and was not bypassed. No token was printed or persisted.

Conclusion: desktop deployment, tunnel liveness/readiness, control-plane forwarding, and logical correlation are verified. The only remaining FMG-013 acceptance blocker is ChatGPT connector catalog/schema rediscovery from 19 to the canonical 23 tools, followed by live catalog version/hash proof.


## Connector rediscovery diagnosis - 2026-09-28

Additional root-cause checks:
- active policy profile is `legacy-command-compatible`;
- source policy implementation allows all tool definitions for that profile, so 19/23 is not caused by policy filtering;
- tunnel runtime is healthy and continues forwarding live `tools/call` traffic successfully;
- tunnel metrics and operator logs show no `tools/list` discovery request reaching the new runtime since its current startup;
- no available ChatGPT/plugin management action in this session exposes a safe connector-schema refresh/rediscovery operation.

Interpretation: the remaining 19/23 mismatch is consistent with stale connector/control-plane discovery state outside the FileMCP runtime. This is still a hard FMG-013 acceptance blocker because the required live 23-tool catalog/hash proof has not occurred.
