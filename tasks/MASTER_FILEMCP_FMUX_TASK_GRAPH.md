# MASTER FileMCP FMUX Task Graph

Status: FROZEN COMPLETE IMPLEMENTATION PLAN
Date: 2026-09-28
Authority:
- docs/adr/0007-product-ui-ux-architecture-and-fmux-track.md
- docs/audit/FMUX_INDEPENDENT_MULTI_ROUND_UI_UX_AUDIT_2026-09-28.md
- docs/audit/FMUX_FINAL_REPAIR_REAUDIT_2026-09-28.md
- docs/design/FMUX_PRODUCT_EXPERIENCE_ARCHITECTURE_V1.md
- docs/design/FMUX_DESIGN_SYSTEM_AND_COMPONENT_SPEC_V1.md
- docs/design/FMUX_INTERACTION_STATE_AND_FMG_MAPPING_V1.md
- docs/design/FMUX_DEPENDENCY_GRAPH_V1.md
- docs/design/FMUX_DECISION_MATRIX_V1.md

## Completion law

FMG-026 remains the engine/backend complete-upgrade gate.
FMUX-020 is the product-experience final gate.

Complete product target:
FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED
+
FMUX-020 PRODUCT_UI_UX_MAIN_VERIFIED.

Each FMUX task follows:
CLAIM -> ANALYZE -> PLAN -> CODE -> TEST -> EVIDENCE -> VERIFY -> COMMIT -> REVIEW -> MERGE -> MAIN VERIFIED -> NEXT READY TASK.

Accessibility, security truthfulness, theme behavior and no-fake-state rules apply to every task.

## FMUX-001 â€” Presentation Foundation

State: DONE / MAIN VERIFIED
Depends: ADR-0007 / FMUX design gate PASS.

Scope:
- Windows semantic resource dictionaries/tokens;
- canonical presentation status enum/model;
- page/navigation contract;
- common formatting/status mapping;
- macOS semantic token/status equivalents;
- testable presentation primitives;
- no product-page redesign yet.

Acceptance:
- no runtime/security semantics duplicated;
- no new hard-coded product palette in feature views;
- status mapping is deterministic;
- Windows Release build passes;
- core/runtime regression remains green;
- macOS source/build contract remains valid;
- legacy UI remains functional.

## FMUX-002 â€” App Shell + Navigation

State: DONE / MAIN VERIFIED
Depends: FMUX-001 MAIN VERIFIED.

Scope:
- labeled sidebar shell;
- content host;
- workspace/global health context;
- compact mode;
- persistent Settings placement;
- Windows/macOS semantic parity.

Acceptance:
- keyboard navigable;
- no top-tab primary IA;
- shell can host old pages during incremental migration;
- navigation state preserved.

## FMUX-003 â€” Canonical Status / Feedback Components

State: DONE / MAIN VERIFIED
Depends: FMUX-001.

Scope:
- StatusBadge;
- InlineNotice;
- EmptyState;
- PageHeader;
- loading/refresh/error/stale patterns;
- notification policy.

## FMUX-004 â€” Home

State: ACTIVE / CLAIMED
Depends: FMUX-002, FMUX-003.

Scope:
- global health;
- active workspace;
- running work;
- important recent event;
- compact usage/activity;
- quick actions.

## FMUX-005 â€” Workspaces

State: BLOCKED
Depends: FMUX-002, FMUX-003.

Scope:
- workspace list/cards;
- connection/health/policy;
- detail pane;
- multi-drive parity.

## FMUX-006 â€” Connections

State: BLOCKED
Depends: FMUX-002, FMUX-003.

Scope:
- runtime credential status;
- tunnel configuration;
- connectivity diagnostics;
- safe save/connect/disconnect flows.

## FMUX-007 â€” Settings / Policy

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-003.

Scope:
- structured settings categories;
- policy explanation;
- advanced progressive disclosure;
- execution/Git/storage/appearance sections.

## FMUX-008 â€” Structured Activity

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-002, FMG-005, FMG-011.

Scope:
- structured event timeline;
- filtering;
- master/detail;
- bounded/virtualized live collection;
- raw logs moved to diagnostics.

## FMUX-009 â€” Changes

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-009.

Scope:
- edit preview/result;
- file/version context;
- diff/code surface;
- stale/conflict states.
FMG-017 integration extends adapters when available.

## FMUX-010 â€” Evidence

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-011.

Scope:
- evidence state list/detail;
- passed/failed/stale/blocked/not-run/unknown/N/A;
- source/policy/catalog linkage.

## FMUX-011 â€” Repository Intelligence

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-018, FMG-019.

Scope:
- repository summary;
- repo map;
- symbol search;
- related files;
- provider/completeness state.

## FMUX-012 â€” Terminal / PTY

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-020.

Scope:
- session list;
- active terminal;
- bounded output;
- stop/signal/resize;
- backend/policy state.

## FMUX-013 â€” Recovery

State: BLOCKED
Depends: FMUX-002, FMUX-003, FMG-016, FMG-021, FMG-022.

Scope:
- quarantine;
- checkpoints;
- restore plan;
- rollback;
- partial-recovery states.

## FMUX-014 â€” Artifact / Batch UX

State: BLOCKED
Depends: FMUX-003, FMG-014, FMG-015.

Scope:
- ContentRef metadata;
- expiry/quota;
- large-output inspection;
- batch grouped/partial results.

## FMUX-015 â€” Backend / Isolation UX

State: BLOCKED
Depends: FMUX-003, FMG-023, FMG-024.

Scope:
- backend identity/status;
- host vs isolated execution;
- Docker availability;
- image/network/resource policy facts.

## FMUX-016 â€” Onboarding

State: BLOCKED
Depends: FMUX-004 through FMUX-015 applicable implemented surfaces.

Scope:
- first-run setup;
- workspace selection;
- credential/connect;
- policy choice;
- connection test;
- completion handoff to Home.

## FMUX-017 â€” Accessibility / Keyboard / Theme Enforcement

State: BLOCKED
Depends: FMUX-001 through FMUX-016 implemented surfaces.

Scope:
- focus order;
- keyboard navigation;
- accessible names;
- contrast;
- high contrast/system appearance;
- reduced motion;
- scaling/reflow.

## FMUX-018 â€” Performance + Visual Consistency Gate

State: BLOCKED
Depends: FMUX-017.

Scope:
- live-list performance;
- bounded rendering;
- token drift scan;
- layout consistency;
- startup/render regressions.

## FMUX-019 â€” Cross-Platform UX Adversarial Gate

State: BLOCKED
Depends: FMUX-018.

Scope:
- Windows/macOS parity;
- error/empty/stale/offline states;
- keyboard-only task completion;
- feature gating;
- security-language audit;
- regression of legacy/core behaviors.

## FMUX-020 â€” Product UI/UX Main Verification

State: BLOCKED
Depends: FMUX-019 and FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED.

Scope:
- clean build/package;
- complete end-to-end product flows;
- live core-to-UI state proof;
- final screenshot/manual visual QA evidence;
- final documentation/state sync.

Acceptance:
- PRODUCT_UI_UX_MAIN_VERIFIED evidence exists;
- no fake controls/states;
- cross-platform semantic parity PASS;
- core FMG regression PASS;
- current handoff/state/task graph mark FMUX complete.

## Initial next action

Claim FMUX-001 only.
Do not begin FMUX-002 before FMUX-001 MAIN VERIFIED.
