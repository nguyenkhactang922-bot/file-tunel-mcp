# FMG-011 Frozen Task Graph

| Task | Action | Acceptance |
|---|---|---|
| FMG-011-A | evidence protocol, IDs, known criteria, operation-ID sharing | unit/contract tests |
| FMG-011-B | Windows separate bounded EvidenceStore | retention/quota/restart/storage failure |
| FMG-011-C | macOS bounded EvidenceStore | native semantic parity |
| FMG-011-D | EvidenceService freshness via SourceStateRef + project context + policy/catalog | fresh/stale adversarial tests |
| FMG-011-E | integrate reserved metadata around tool execution/exec_process | false-PASS and required-mode tests |
| FMG-011-F | evidence_get + canonical catalog/parity | catalog/schema parity |
| FMG-011-G | privacy, corruption, quota, restart hardening | adversarial PASS |
| FMG-011-H | full local/native CI + scoped review | exact green head |
| FMG-011-I | PR merge + merged-main Verify | FMG-011 MAIN VERIFIED; FMG-012 READY |

Dependency: A -> B/C -> D -> E/F -> G -> H -> I.

## Current execution status

- FMG-011-A: PASS
- FMG-011-B: PASS
- FMG-011-C: PASS
- FMG-011-D: PASS
- FMG-011-E: PASS
- FMG-011-F: PASS
- FMG-011-G: PASS
- FMG-011-H: PASS - exact-head Verify 36295961603
- FMG-011-I: PASS - PR #17 merged; main ddc8b278 verified by run 36296831946

FMG-011 COMPLETE: authority transferred to FMG-012.
