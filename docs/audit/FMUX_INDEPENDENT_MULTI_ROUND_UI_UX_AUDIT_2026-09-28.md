# FMUX Independent Multi-Round UI/UX Audit

Status: COMPLETE / DESIGN INPUT
Date: 2026-09-28
Project: FileMCP
Scope rule: FMG-001..FMG-026 remains unchanged. FMUX is a separate product-experience track.

## Executive finding

FileMCP is technically capable but presents itself as a utility/configuration window rather than a cohesive coding-agent gateway product.

The current Windows UI is concentrated in a large WPF MainWindow with top tabs, local styles, hard-coded layout/color values, and direct code-behind coupling. The current macOS UI is concentrated in FileMCPApp.swift with AppKit views constructed imperatively and top tabs. Both platforms expose functionality, but neither has a formal information architecture, design token layer, reusable product component system, consistent status semantics, or a forward-compatible surface for FMG-014..026 capabilities.

The correct modernization is NOT a runtime/framework rewrite. Preserve WPF and AppKit, introduce a presentation architecture and shared UX contract, and use platform-native components/behavior.

## Evidence from current repository

### Windows
- Main UI: `windows/src/FileMCP.App/MainWindow.xaml`.
- Top-level TabControl: Overview / Connection / Settings / Logs.
- Visual resources are local to MainWindow instead of a product design-system resource layer.
- Overview mixes operational telemetry, workspaces, sessions and chart content in one long page.
- Hard-coded colors exist in XAML for chart/log/detail surfaces.
- One MainWindow contains configuration, connection control, observability, logs, and session detail.
- Code-behind owns substantial view state and behavior.

### macOS
- Main UI: `macos/FileMCPApp.swift`.
- MainViewController builds Connection / Settings / Logs with NSTabView.
- Layout is created imperatively with NSStackView/constraints.
- Presentation and runtime behavior are tightly co-located.
- The desktop product surface is narrower than Windows and has no unified cross-platform information architecture.

## Round 1 — Product intent audit

Product identity must be: **Local Coding-Agent Gateway Control Center**, not “tunnel configuration utility”.

Primary user goals:
1. Know whether FileMCP is healthy and connected.
2. Know which workspace(s) are exposed and under what policy.
3. Understand what an AI agent is doing now.
4. Inspect edits, commands, evidence and failures.
5. Recover safely using quarantine/checkpoints.
6. Inspect repository intelligence.
7. Manage PTY/process/backend sessions.
8. Configure advanced policy without accidental privilege expansion.

Finding: current tabs map to implementation areas, not user goals.

## Round 2 — Information architecture audit

Current top tabs do not scale to FMG-014..026.

Required first-class destinations:
- Home
- Workspaces
- Activity
- Changes
- Repository
- Terminal
- Recovery
- Evidence
- Connections
- Settings

The primary navigation must remain short and scannable. Capability-specific secondary pages can live inside destination-level subnavigation or detail panes.

## Round 3 — Visual hierarchy audit

Problems:
- Multiple equally weighted cards and metrics reduce prioritization.
- Weak distinction between global state, workspace state and session state.
- Status is often text-only.
- Configuration fields dominate when the product should emphasize operational health and action.
- No formal semantic color/state system.
- No standardized typography/spacing/corner/elevation scale.

Required:
- semantic tokens, not arbitrary literals;
- restrained density;
- strong page title + contextual status;
- status badge/chip vocabulary;
- compact metric cards only for actionable/high-value data;
- detail drawers/panes for secondary information.

## Round 4 — Interaction/state audit

FileMCP has many runtime states but the UI lacks one canonical presentation state machine.

Required status vocabulary:
- healthy
- connected
- starting
- running
- stopping
- stopped
- degraded
- warning
- blocked
- failed
- stale
- verifying
- passed
- cancelled
- expired
- unavailable

Each state requires:
- semantic meaning;
- icon;
- color role;
- label;
- optional remediation action;
- accessibility name;
- persistence behavior.

No important state may rely on color alone.

## Round 5 — Safety/trust UX audit

Security boundaries must become visible without becoming noisy.

Required:
- current workspace root;
- current policy profile;
- elevated/high-risk capability indicator;
- backend identity;
- network mode where relevant;
- stale/evidence state;
- destructive actions use preview + explicit confirmation only where needed;
- restore/quarantine/checkpoint actions show target and expected-version context.

UX must never suggest that FileMCP has authority it does not possess.

## Round 6 — Accessibility/platform audit

Windows and macOS should share product semantics, not pixel-identical UI.

Required baseline:
- keyboard-first navigation;
- visible focus;
- logical focus order;
- accessible names/descriptions;
- text and non-text contrast meeting WCAG AA expectations;
- no hover-only essential actions;
- text scaling/reflow without clipped critical controls;
- reduced-motion respect;
- system theme/high-contrast compatibility where platform allows.

## Round 7 — FMG future-capability fit audit

FMUX must reserve UX contracts for:
- FMG-014 Artifact/ContentRef -> Artifact inspector / large-output references.
- FMG-015 Batch read/stat -> grouped activity results.
- FMG-016 Quarantine -> Recovery center.
- FMG-017 Edit adapters -> Changes/preview flow.
- FMG-018/019 Repo intelligence -> Repository map/search.
- FMG-020 PTY -> Terminal sessions.
- FMG-021/022 Checkpoints -> Recovery timeline/restore.
- FMG-023 backend interface -> backend identity/status.
- FMG-024 Docker backend -> isolated execution status and network/resource policy.
- FMG-025/026 -> product verification/evidence state.

Finding: waiting until FMG features land would force repeated UI re-architecture. Define the UX contracts now while keeping implementation feature-gated.

## Round 8 — Maintainability/red-team audit

Rejected approaches:
- another monolithic MainWindow;
- copy/paste style literals between pages;
- view directly invoking every runtime service;
- UI-specific duplicate definitions of FMG policy/security semantics;
- framework rewrite solely for visual modernization;
- “dashboard of everything” with dozens of cards;
- raw logs as the primary activity UX;
- hiding dangerous state behind advanced settings;
- fake live state derived from optimistic button state.

Required architecture:
Runtime/Core state -> presentation adapters/view models -> canonical UX state -> platform-native views.

## Benchmark synthesis

Patterns accepted:
- Fluent-style short, goal-oriented navigation and coherent grouping.
- Platform-native controls and familiar desktop behavior.
- Cards for bite-sized actionable summaries, not as a universal layout primitive.
- Clear hierarchy, whitespace and consistent token scales.
- Native macOS control behavior and platform conventions.

Patterns rejected:
- web-dashboard aesthetic transplanted directly into desktop;
- decorative glass/blur as core hierarchy;
- excessive animations;
- icon-only primary navigation;
- universal cross-platform pixel matching.

## Final audit verdict

The current UI should NOT receive cosmetic-only polish.

PASS condition for FMUX design gate:
1. product experience architecture frozen;
2. information architecture frozen;
3. design token/component contract frozen;
4. interaction/status/error contract frozen;
5. FMG-014..026 surface mapping frozen;
6. implementation dependency graph frozen;
7. task graph frozen;
8. independent repair re-audit finds no P0/P1 design blocker.

Only then may FMUX-001 implementation begin.
