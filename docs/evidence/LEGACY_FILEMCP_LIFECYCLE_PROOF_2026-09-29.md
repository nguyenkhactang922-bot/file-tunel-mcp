# Legacy FileMCP Lifecycle-Proof Preservation - 2026-09-29

Canonical project root: `D:\Tools\FileMCP`

Former standalone repository:
- local path: `D:\FileMCP-Lifecycle-Proof-20260922`
- origin: `https://github.com/nguyenkhactang922-bot/filemcp-lifecycle-proof-20260922.git`
- final branch: `main`
- final merge commit: `17ea9ac9f259090ff9d51d9883a5067c57e584b2`
- feature commit: `ed51617` (`feat: prove full FileMCP lifecycle`)
- baseline commit recorded by its evidence: `34dfe65a1a693d37af8c04b100e79b9e4c2cfeda`
- PR history: merge commit message records PR #1 from `filemcp/full-lifecycle-proof`

The repository was intentionally a tiny isolated lifecycle proof, not product code:
- `src/math.js`: add/multiply toy functions;
- `test/math.test.js`: two Node tests;
- `scripts/build.mjs`: copies the source and records SHA-256;
- `proof/feature-evidence.txt`: captured test/build/diff evidence.

Preserved proof facts:
- source SHA-256: `71d022af1b739402ef39375d8a14c78e94ae791b06dd103810d5d04f6b6f4e25`
- dist SHA-256: `71d022af1b739402ef39375d8a14c78e94ae791b06dd103810d5d04f6b6f4e25`
- test exit: `0`
- build exit: `0`
- git diff check exit: `0`
- 2/2 Node tests passed.

Preservation decision:
- **do not merge the toy JavaScript source into FileMCP**;
- keep only this provenance/evidence record because the canonical FileMCP repository now
  has materially stronger real lifecycle evidence: native cross-platform Verify runs,
  production build/package gates, PR review/merge history, merged-main verification and
  task-specific evidence under `docs/evidence/`.

The standalone lifecycle-proof repository was clean at deletion time. Its useful
evidence is now captured here; keeping a second FileMCP-named project root would violate
the canonical single-root rule without adding product capability.
