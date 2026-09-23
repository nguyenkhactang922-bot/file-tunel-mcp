# IDEA CAPTURE & DESIGN LAW

Status: LOCKED PROCESS LAW

Every new feature or architectural change follows this order exactly:

IDEA -> CAPTURE IMMEDIATELY -> CONTINUE DISCUSSION -> LIVING DRAFT -> DEEP DIVE BY SUBSYSTEM -> CONTINUOUS DESIGN UPDATES -> INDEPENDENT MULTI-ROUND REVIEW -> TECHNOLOGY/SOLUTION COMPARISON -> ARCHITECTURE FREEZE -> DEPENDENCY/TASK SPLIT -> CODE.

Rules:
- An idea is saved immediately without interrupting the conversation flow.
- Idea capture is not approval to code.
- The living design may change freely until frozen.
- Independent audit findings must be written separately from the design they critique.
- Competing technologies/approaches must be compared before architecture freeze when the choice changes reliability, security, persistence, performance, or UX.
- Frozen architecture changes require a new ADR/review round; code must not silently redesign it.
- Tasks must include dependencies and acceptance evidence before implementation starts.
- No feature code before the architecture and task graph for that feature are frozen.

## COMPLETE CURRENT-SCOPE FREEZE GATE

For a project/upgrade that already has multiple known phases, subsystems, or later capabilities, the design gate applies to the **whole currently approved scope**, not only the first feature or first phase.

Required sequence:

IDEA / PRODUCT INTENT
-> CAPTURE ALL KNOWN IN-SCOPE REQUIREMENTS
-> LIVING DESIGN
-> DEEP DIVE EACH SUBSYSTEM
-> CONTINUOUS DESIGN UPDATES
-> INDEPENDENT MULTI-ROUND AUDIT / RED-TEAM
-> COMPARE COMPETING TECHNOLOGIES / SOLUTIONS
-> REPAIR FINDINGS
-> RE-AUDIT
-> RESOLVE EVERY KNOWN IN-SCOPE ITEM TO BUILD / REJECT / OUT-OF-SCOPE
-> CHECK CROSS-SUBSYSTEM DEPENDENCIES
-> ARCHITECTURE FREEZE
-> COMPLETE TASK GRAPH
-> DEFINE FINAL WHOLE-SCOPE COMPLETION GATE
-> CODE.

Additional rules:
- Do not code an early phase while intentionally leaving a known later in-scope phase to be designed afterward.
- `DEFER` may remain only when product authority explicitly decides the capability is outside the current implementation scope or when a real external evidence blocker prevents a safe decision; the reason and re-entry condition must be written.
- If the user requires complete-scope-first execution, known in-scope `DEFER` items must be converted before coding to BUILD, REJECT, or OUT-OF-SCOPE.
- Task graphs must include cross-phase dependencies and the final whole-scope verification task.
- Intermediate `MAIN VERIFIED` milestones do not redefine project completion when later tasks are already frozen in the same current scope.
- New future requirements that were genuinely unknown at freeze time require a new ADR/review cycle; this is not a license to postpone known design work.
