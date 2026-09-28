# FMUX Design System and Component Spec V1

Status: FROZEN
Date: 2026-09-28

## Design principles

1. Operational clarity over decoration.
2. Native on each desktop platform.
3. One semantic system across platforms.
4. Dense enough for technical work, never cramped.
5. Progressive disclosure for advanced controls.
6. Safety state is visible and understandable.
7. Motion supports causality; it never delays work.

## Token layers

Token names are semantic. Platform resources map them to native brushes/colors/fonts.

### Color roles
- Surface.App
- Surface.Sidebar
- Surface.Card
- Surface.Raised
- Surface.Code
- Border.Subtle
- Border.Strong
- Text.Primary
- Text.Secondary
- Text.Disabled
- Accent.Primary
- Status.Info
- Status.Success
- Status.Warning
- Status.Danger
- Status.Neutral

No feature view may introduce arbitrary product color literals except charts/data series registered in the chart palette.

### Spacing
Base scale:
- 4
- 8
- 12
- 16
- 24
- 32
- 48

### Radius
- Small: 4
- Medium: 8
- Large: 12

Platform adapters may round to native visual metrics.

### Typography roles
- Display
- PageTitle
- SectionTitle
- Body
- BodyStrong
- Caption
- Mono

Use system UI font. Use platform monospace for code/log/terminal.

## Core components

### AppNavigation
- labeled icons;
- selected state;
- compact mode;
- keyboard accessible;
- stable order.

### PageHeader
- title;
- optional description;
- contextual status;
- primary action max 1;
- overflow for secondary actions.

### StatusBadge
Mandatory semantic mapping:
- neutral
- info
- success
- warning
- danger
- stale

Text label required. Color never carries meaning alone.

### MetricCard
Use only for top-level high-value metrics.
No more than 4 in one row.

### WorkspaceCard / WorkspaceRow
Shows:
- name/root;
- connection;
- policy;
- health;
- activity;
- direct inspect action.

### ActivityRow
Shows:
- time;
- action/tool;
- workspace;
- state;
- duration;
- optional agent/session correlation;
- opens detail pane.

### EvidenceBadge / EvidenceRow
States:
- passed
- failed
- not-run
- unknown
- stale
- blocked
- N/A

### EmptyState
Must explain:
- what the page is;
- why there is no content;
- what next action exists.

### InlineNotice
Info/warning/error/success.
Used for actionable contextual messages.

### SplitDetailPane
Master/detail inspection without navigation loss.

### FormSection
Title + description + aligned fields + validation.
Advanced fields must use progressive disclosure.

### DestructiveAction
Danger styling only for destructive actions.
Must not make common stop/disconnect operations look equivalent to data destruction.

### CodeSurface
For:
- logs;
- terminal;
- diff;
- raw evidence/details.
Must support copy and text selection.

## Interaction standards

- primary buttons represent one primary action per local region;
- disable only when action truly cannot run; otherwise allow and explain validation;
- loading preserves layout width;
- cancel/stop visible for long-running operations;
- failures show next action when known;
- background refresh must not steal focus;
- avoid auto-scrolling if the user has moved away from live tail.

## Dark/light/high-contrast

Windows:
- system theme default;
- explicit app preference may be added;
- preserve Windows high contrast.

macOS:
- follow system appearance by default;
- native semantic NSColor mapping.

No separate hand-authored page palettes.

## Iconography

Use native/system-compatible icon set with consistent semantic names:
- home
- workspace
- activity
- changes
- repository
- terminal
- recovery
- evidence
- connection
- settings
- success
- warning
- error
- stale
- stop
- refresh
- more

Never use emoji as product icons.

## Accessibility acceptance

- all controls keyboard reachable;
- visible focus;
- semantic accessible name;
- tooltip does not replace accessible label;
- contrast meets target;
- minimum useful target size follows platform convention;
- no essential content only on hover;
- live regions/announcements limited to important state changes.
