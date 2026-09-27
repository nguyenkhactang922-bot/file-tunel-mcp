# FMG-013 Foundation Full Regression + Live MCP Proof Evidence

Status: BLOCKED / LIVE DEPLOYMENT STALE

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
- live process PID: `13896`;
- live executable: `D:\Tools\FileMCP\dist\windows-x64\FileMCP-release\FileMCP.exe`;
- live executable timestamp: `2026-09-22T14:26:46.4876055+07:00`;
- live executable size: `165431146`;
- live executable SHA-256: `7689540f1ff4cc080064eb1ccaf33a5b4a8b1a736b2f10b52988505e6e7c2807`;
- ChatGPT connector tool registry visible in this session: 19 FileMCP tools;
- expected current canonical source registry: 23 tools.

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
