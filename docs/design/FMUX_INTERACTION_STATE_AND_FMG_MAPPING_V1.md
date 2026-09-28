# FMUX Interaction, State and FMG Mapping V1

Status: FROZEN
Date: 2026-09-28

## Canonical status model

| UX state | Meaning | Typical action |
|---|---|---|
| healthy | subsystem fully operational | inspect |
| connected | transport/session connected | disconnect/inspect |
| starting | startup in progress | wait/cancel if supported |
| running | active execution/session | inspect/stop |
| stopping | termination in progress | wait |
| stopped | intentionally inactive | start |
| degraded | operational with impaired capability | inspect remediation |
| warning | attention needed, operation may continue | inspect |
| blocked | dependency/policy prevents progress | resolve blocker |
| failed | operation failed | inspect/retry exact safe stage |
| stale | evidence/state no longer matches source | refresh/reverify |
| verifying | verification running | inspect |
| passed | verified success | inspect evidence |
| cancelled | user/system cancellation | inspect/retry |
| expired | TTL/reference/session expired | recreate |
| unavailable | capability not present | explain |

## Loading and refresh

Every data surface identifies one of:
- first-load;
- refreshing with existing data;
- empty;
- partial;
- error;
- stale.

Do not blank a populated page during background refresh.

## Notifications

Toast:
- transient completion/info.

Inline notice:
- page-specific blocker/warning.

Persistent status:
- connection, policy, health, backend identity.

Dialog:
- only when interaction must be resolved before continuing.

## Error contract

Every user-facing error should carry:
- concise title;
- what failed;
- scope affected;
- whether state changed;
- safe next action;
- optional technical detail/reveal;
- correlation/evidence reference when available.

No raw exception string as the only UX.

## FMG capability mapping

### Existing foundation FMG-001..013
- tool catalog -> capability display/diagnostics;
- structured result -> Activity detail model;
- policy -> Policy & permissions;
- budgets/cursor -> truncation/partial state;
- exec_process -> Activity/Terminal process detail;
- strong file version -> Changes/Recovery version context;
- mutation guard -> protected mutation state;
- apply_edits -> Changes;
- project context -> workspace/context detail;
- evidence -> Evidence;
- foundation live proof -> diagnostics/about verification.

### FMG-014
Artifact/ContentRef:
- large output reference card;
- artifact detail metadata;
- lifecycle/expiry;
- copy/open where safe;
- no arbitrary-path semantics.

### FMG-015
Batch read/stat:
- grouped activity;
- per-entry state;
- partial/cancelled summary.

### FMG-016
Quarantine:
- Recovery > Quarantine;
- delete preview;
- restore conflict state.

### FMG-017
Edit adapters:
- Changes > Preview;
- unified canonical edit output;
- ambiguity/error explanation.

### FMG-018/019
Repository intelligence:
- Repository page;
- map/search/related files;
- provider completeness prominently shown.

### FMG-020
Persistent PTY:
- Terminal;
- session lifecycle;
- live output;
- backend/policy state.

### FMG-021/022
Checkpoint:
- Recovery > Checkpoints;
- capture metadata;
- restore plan;
- rollback state;
- partial_recovery_required surfaced as high-severity persistent state.

### FMG-023/024
Execution backend:
- backend selector only if local policy allows;
- backend identity;
- Docker isolation/resource/network state;
- unavailable Docker must not look like app failure.

### FMG-025/026
Verification:
- Evidence final gate;
- product verification summary;
- no green state without real evidence.

## Security UX invariants

- root path visible before destructive mutation;
- policy escalation never occurs because of a UI convenience action;
- secret values never shown after secure storage;
- “connected” does not imply unrestricted authority;
- backend isolation claims are factual and capability-derived;
- stale evidence cannot display as passed without stale marker.
