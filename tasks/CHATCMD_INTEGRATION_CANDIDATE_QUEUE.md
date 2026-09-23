# ChatCMD-Inspired FileMCP Integration Candidate Queue

Status: DESIGN-FROZEN - NOT YET ACTIVE IMPLEMENTATION
Architecture authority: docs/adr/0004-chatcmd-inspired-execution-foundation.md
Audit authority: docs/audit/CHATCMD_INDEPENDENT_MULTI_ROUND_INTEGRATION_AUDIT_2026-09-23.md
Source map: docs/design/CHATCMD_SOURCE_TO_FILEMCP_MAPPING_V1.md
Decision matrix: docs/design/CHATCMD_INTEGRATION_DECISION_MATRIX_V1.md

This queue is intentionally separate from the current V11/FPA final-product queue. It must not replace the existing authoritative release action until project authority starts this future integration program.

| ID | State | Depends | Scope | Required acceptance evidence |
|---|---|---|---|---|
| CCI-001 | READY-DESIGN | ADR-0004 | Canonical catalog/version/hash/capability manifest | Windows + macOS advertised schema equality; stable hash tests; package/live catalog smoke |
| CCI-002 | BLOCKED | CCI-001 | Unified result envelope | schema fixtures; compatibility tests; truncation/usage/warning cases |
| CCI-003 | BLOCKED | CCI-001,CCI-002 | Structured exec_process | argv no-shell tests; env denylist; timeout/cancel/process-tree tests; Win/mac parity |
| CCI-004 | BLOCKED | CCI-001 | File version tokens + versioned stat/read | stale token rejection; metadata/content strength tests; symlink/reparse safety; Win/mac parity |
| CCI-005 | BLOCKED | CCI-002,CCI-004 | Atomic versioned apply_edits | overlap rejection; dry-run; concurrent writer conflict; fault injection; BOM/newline tests |
| CCI-006 | BLOCKED | CCI-002 | Shared budget/cursor contract | hard-cap tests; caller-lower-only tests; cursor tamper/staleness tests; cooperative cancellation |
| CCI-007 | BLOCKED | CCI-002,CCI-003,CCI-004,CCI-006 | Metadata-only execution evidence | privacy regression; execution ownership; fresh/stale/unknown verification cases; restart handling |
| CCI-008 | BLOCKED | CCI-004,CCI-006 | Bounded project_context + digest | AGENTS/rules provenance tests; nested scope; version/range continuation; explicit no-authority test |
| CCI-009 | BLOCKED | CCI-001,CCI-003,CCI-005,CCI-007,CCI-008 | Server-owned policy profiles | model self-elevation negative tests; risk classification; workspace-auto regression; config persistence safety |
| CCI-010 | BLOCKED | CCI-001..CCI-009 | Phase A independent adversarial regression | Windows Release 0 warnings; runtime suite; macOS Verify; native x64/ARM64 Verify; live MCP/catalog proof; privacy/security audit |

## Phase B candidates - not claimed

| ID | Depends | Candidate |
|---|---|---|
| CCI-B01 | CCI-002,CCI-006 | Batch read/stat |
| CCI-B02 | CCI-002,CCI-006,CCI-007 | Ephemeral large-output artifact/content-ref layer |
| CCI-B03 | CCI-004,CCI-005,CCI-006,CCI-009 | Quarantine delete/restore |
| CCI-B04 | CCI-003,CCI-006,CCI-007,CCI-009 | Persistent PTY |
| CCI-B05 | profiling evidence + CCI-006 | Optional repository path index |

Phase B must receive a focused design review before claim if its implementation materially changes persistence, trust boundaries or UI.

## Phase C - forbidden without a new ADR

- task engine beyond metadata/evidence;
- sub-agent orchestration;
- nested sub-agent delegation;
- inherited approval grants;
- global sub-agent concurrency;
- lease/heartbeat/watchdog;
- durable child reports.

## Dependency graph

CCI-001 Catalog
   |\
   | +----------------------+
   v                        v
CCI-002 Result          CCI-004 Version
   |\                       |
   | +--> CCI-003 Exec      +--> CCI-005 Apply Edits
   |          |                      |
   +--> CCI-006 Budget --------------+
              |                       |
              +--> CCI-008 Context    |
CCI-003 ------+                       |
CCI-004 ------+--> CCI-007 Evidence <-+
                         |
CCI-008 -----------------+--> CCI-009 Policy
                              |
                              v
                         CCI-010 FINAL
                    independent regression

## Implementation lifecycle per task

CLAIM
-> confirm exact branch/HEAD/worktree
-> read ADR-0004 + source mapping + queue
-> ANALYZE exact current source
-> PLAN minimal change
-> CODE Windows + macOS contract as required
-> TEST
-> capture EVIDENCE
-> VERIFY independently
-> COMMIT
-> REVIEW
-> MERGE
-> MAIN VERIFIED
-> update state
-> claim next READY task

## Stop conditions

Do not begin feature code if:
- main has unreviewed unrelated changes;
- catalog/source mapping changed materially without ADR review;
- a task would weaken AGENTS.md security/privacy rules;
- Windows/macOS parity is not designed for a common tool;
- a task silently introduces raw-content persistence;
- a ChatCMD plan is being treated as shipped source without verification.

## First implementation action when project authority starts this program

Claim CCI-001 only. Do not parallelize dependent implementation before the canonical catalog contract is proven.
