# ChatGPT Web / FileMCP execution law

ChatGPT Web is the main coding/design agent. FileMCP is the local execution bridge.

## Design gate
IDEA -> CAPTURE -> LIVING DESIGN -> DEEP DIVE -> INDEPENDENT REVIEW -> SOLUTION MATRIX -> ARCHITECTURE FREEZE -> TASK GRAPH.
No feature code before this gate is complete.

## Implementation gate
CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> REVIEW -> MERGE -> DONE -> NEXT READY TASK.

Before every task confirm git root/branch/HEAD/status and read AGENTS.md, CURRENT_HANDOFF.md, PROJECT_STATE.md, and tasks/TASK_QUEUE.md. Resume NEXT_EXACT_ACTION rather than restarting work.

## Complete current-scope freeze law

Default operating mode is **complete-scope-first**:

CURRENT PRODUCT INTENT
-> CAPTURE ALL KNOWN REQUIREMENTS
-> LIVING DESIGN
-> DEEP DIVE BY SUBSYSTEM
-> CONTINUOUS DESIGN UPDATES
-> INDEPENDENT MULTI-ROUND REVIEW / RED-TEAM
-> TECHNOLOGY / SOLUTION COMPARISON
-> RESOLVE KNOWN LATER-PHASE ITEMS
-> ARCHITECTURE FREEZE
-> COMPLETE DEPENDENCY GRAPH
-> COMPLETE TASK SPLIT
-> ONLY THEN START FEATURE CODE.

Before the first implementation task:
- enumerate all capabilities/phases already known to be part of the currently desired upgrade;
- resolve each to BUILD, REJECT, or explicitly OUT-OF-SCOPE;
- do not leave an in-scope known capability as a vague `DEFER` merely to postpone design until after coding an earlier phase;
- freeze cross-phase dependencies so an intermediate milestone does not become a surprise architecture restart;
- define the final completion gate for the whole current scope, not only the first implementation phase.

This law does **not** claim that unknown future product ideas can be designed in advance. New requirements discovered later are handled by a new capture/review/ADR cycle. But known current-scope work must be designed and task-split before implementation begins.

No feature code before this complete current-scope gate is complete.
