# CURRENT HANDOFF

STATUS: IMPLEMENTATION ACTIVE
BRANCH: chatgpt/OBS-001-observability-foundation
COMPLETED: FMR-001 through OBS-007
NEXT TASK: OBS-008 - live logical/unbound session registry/state machine

NEXT_EXACT_ACTION:
Implement live logical/unbound session registry with active <=45s, idle <=30m, stale >30m semantics; persist only hashed logical ids and per-workspace session counters. Wire tool-call attribution from LocalMcpServer without changing permissions. Add state-machine and persistence tests. Exact AI-chat UI label remains feature-gated until OBS-013 live ChatGPT proof.