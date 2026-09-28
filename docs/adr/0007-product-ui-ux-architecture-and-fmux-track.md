# ADR-0007 — Product UI/UX Architecture and FMUX Track

Status: ACCEPTED
Date: 2026-09-28

## Context

FileMCP has substantial runtime/gateway capability, but its desktop UI evolved as configuration/observability surfaces. The complete FMG program introduces capabilities that require a coherent product experience.

## Decision

Create a separate FMUX product-experience track.

FMG-001..026 scope and completion law remain unchanged.

Keep:
- Windows: WPF/.NET desktop stack.
- macOS: native AppKit stack.

Do not perform a framework rewrite solely for appearance.

Introduce:
- canonical product information architecture;
- presentation adapter/view-model boundary;
- semantic design tokens;
- reusable component/status system;
- platform-native app shell/navigation;
- structured Activity/Changes/Evidence/Recovery/Repository/Terminal surfaces;
- cross-platform semantic parity with native visual behavior.

## Why

A rewrite would add migration and security risk without solving the primary problem: missing product architecture.

WPF and AppKit can deliver a premium native desktop experience when presentation architecture, tokens, components and state semantics are formalized.

## Consequences

Positive:
- protects validated core/runtime behavior;
- incremental delivery;
- native desktop behavior;
- avoids duplicate cross-platform runtime layer;
- FMG future features have predefined UX homes.

Costs:
- two platform view implementations remain;
- shared semantics require disciplined contracts;
- some visual primitives must be implemented twice.

## Rejected alternatives

### Electron/Tauri rewrite
Rejected for current scope. Adds a new UI/runtime boundary and migration burden without a required product capability.

### MAUI/Avalonia rewrite
Rejected for current scope. Cross-platform convergence does not justify rewriting validated native integrations.

### WinUI 3 Windows-only migration
Rejected for current scope. Fluent visual principles can be implemented on WPF without replacing the Windows runtime shell.

### Cosmetic-only reskin
Rejected. Does not solve information architecture, state semantics, maintainability or FMG-014..026 scalability.

## Completion

FMUX design gate is complete only when:
- audit;
- frozen architecture/specs;
- dependency graph;
- complete task graph;
- repair re-audit;
are committed.

FMUX implementation begins at FMUX-001 only after that gate.
