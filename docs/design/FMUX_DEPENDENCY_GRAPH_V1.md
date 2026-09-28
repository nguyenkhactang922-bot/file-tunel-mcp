# FMUX Dependency Graph V1

Status: FROZEN
Date: 2026-09-28

## Design gate

Audit -> contradiction repair -> architecture freeze -> component/state freeze -> FMG mapping -> dependency graph -> task graph -> implementation.

## Implementation dependencies

```text
FMUX-001 Presentation Foundation
  +-> FMUX-002 App Shell & Navigation
  +-> FMUX-003 Canonical Status / Feedback Components

FMUX-002 + 003 -> FMUX-004 Home
FMUX-002 + 003 -> FMUX-005 Workspaces
FMUX-002 + 003 -> FMUX-006 Connections
FMUX-002 + 003 -> FMUX-007 Settings / Policy

FMUX-003 + core structured results -> FMUX-008 Activity
FMUX-003 + FMG-009 -> FMUX-009 Changes
FMUX-003 + FMG-011 -> FMUX-010 Evidence

FMUX-002 + FMG-018/019 -> FMUX-011 Repository
FMUX-002 + FMG-020 -> FMUX-012 Terminal
FMUX-002 + FMG-016/021/022 -> FMUX-013 Recovery
FMUX-003 + FMG-014/015 -> FMUX-014 Artifact / Batch UX
FMUX-003 + FMG-023/024 -> FMUX-015 Backend / Isolation UX

FMUX-004..015 -> FMUX-016 Onboarding
FMUX-001..016 -> FMUX-017 Accessibility / Keyboard / Theme
FMUX-001..017 -> FMUX-018 Performance / Visual Consistency Gate
FMUX-018 -> FMUX-019 Cross-Platform UX Adversarial Gate
FMUX-019 + FMG-026 -> FMUX-020 Product UI/UX Main Verification
```

## Parallelism rule

FMUX design is frozen now, but feature surfaces whose core dependency is not implemented must remain contract/stub-free until the dependency becomes real.

Allowed before FMG-026:
- FMUX-001..010 if their concrete core dependencies exist;
- shell, Home, Workspaces, Connections, Settings, Activity, Changes, Evidence.

FMUX-011..015 implementation must wait for their stated FMG dependencies.

This prevents fake UI and prevents FMUX from mutating FMG scope.

## Final product completion

Technical engine completion:
`FMG-026 COMPLETE_UPGRADE_MAIN_VERIFIED`

Product experience completion:
`FMUX-020 PRODUCT_UI_UX_MAIN_VERIFIED`

FileMCP complete product target requires both.
