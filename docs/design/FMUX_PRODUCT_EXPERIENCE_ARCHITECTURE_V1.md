# FileMCP Product Experience Architecture V1

Status: FROZEN
Date: 2026-09-28
Track: FMUX
Does not modify FMG-001..FMG-026 scope.

## Product promise

FileMCP desktop is the local control center for a coding-agent gateway.

The UI answers five questions immediately:
1. Is FileMCP healthy?
2. What is connected?
3. What workspace and authority are active?
4. What is the agent doing?
5. Can I inspect, stop, verify or recover safely?

## Architecture

```text
FileMCP Core / Runtime / Telemetry / Evidence
                  |
          Presentation Adapters
                  |
        Canonical UX State Model
                  |
      +-----------+-----------+
      |                       |
 Windows WPF              macOS AppKit
 native shell             native shell
 native controls          native controls
```

Rules:
- no duplicate security authority in UI;
- views do not invent runtime state;
- product status comes from canonical core/runtime facts;
- platform adapters may format but not reinterpret safety semantics;
- feature availability is capability-driven;
- unavailable FMG features render as unavailable/coming-capability only in development builds, not fake controls in production.

## Global app shell

Persistent regions:
- primary navigation;
- current workspace context;
- global connection/health indicator;
- content region;
- optional contextual detail pane;
- global status/toast surface.

Navigation:
1. Home
2. Workspaces
3. Activity
4. Changes
5. Repository
6. Terminal
7. Recovery
8. Evidence
9. Connections
10. Settings

Adaptive rule:
- normal desktop: sidebar navigation;
- narrow window: compact sidebar;
- never fall back to a long top-tab strip for full product navigation.

## Canonical product pages

### Home
Purpose: operational confidence, not analytics overload.
Contains:
- global health;
- active workspace;
- active agent/session summary;
- currently running execution;
- latest important event/failure;
- compact usage/activity summary;
- quick actions.

### Workspaces
- configured roots;
- tunnel/connection state;
- policy profile;
- health;
- activity;
- per-workspace detail.

### Activity
Structured event stream for tool calls, commands, Git, edits, PTY and recovery actions.
Raw log remains secondary diagnostics.

### Changes
Unified pending/applied edit view.
Future FMG-017 adapters compile to canonical edits; UI shows preview/result without bypassing core guards.

### Repository
FMG-018/019:
- repository summary;
- map;
- symbol search;
- related files;
- provider/version/completeness state.

### Terminal
FMG-020:
- PTY session list;
- active terminal;
- backend/policy/session status;
- stop/signal/resize affordances.

### Recovery
FMG-016/021/022:
- quarantine items;
- checkpoints;
- restore plans;
- rollback/recovery state.

### Evidence
FMG-011 and final gates:
- passed/failed/stale/blocked/not-run states;
- source-state linkage;
- catalog/policy/backend identity where applicable.

### Connections
- runtime API credential status;
- tunnel configuration;
- per-workspace connection state;
- connectivity diagnostics.

### Settings
Sections:
- General
- Appearance
- Policy & permissions
- Execution
- Git
- Storage & retention
- Advanced

## State ownership

### Source state
Truth from core services.

### Presentation state
Selection, filters, expanded panels, active page, column/splitter positions.

### Ephemeral interaction state
Loading, hover, focus, transient toast.

Never persist:
- prompt/chat content;
- command bodies in telemetry settings;
- file contents;
- secrets;
- bearer tokens.

## Detail-pane model

Use master/detail for:
- activity event;
- workspace;
- evidence record;
- quarantine/checkpoint item;
- repository symbol/result.

Do not open modal dialogs for ordinary inspection.
Dialogs are reserved for:
- destructive/irreversible confirmation;
- credential entry;
- complex restore/permission decisions when inline flow is insufficient.

## Cross-platform parity contract

Must match:
- destination taxonomy;
- status semantics;
- labels for security-critical concepts;
- capability availability;
- action outcome semantics;
- evidence states.

May differ:
- control shape;
- window chrome;
- native toolbar/sidebar implementation;
- keyboard conventions;
- spacing nuances;
- platform-specific system dialogs.

## Non-goals

- embedded coding chat;
- IDE replacement;
- browser automation UI;
- agent marketplace;
- project/task manager;
- flashy animation-first shell;
- full log viewer as primary UX.
