# FMUX Decision Matrix V1

Status: FROZEN
Date: 2026-09-28

| Decision area | Option | Decision | Reason |
|---|---|---|---|
| Windows UI stack | Keep WPF | BUILD | Lowest migration risk; sufficient for premium native UI |
| Windows UI stack | WinUI 3 rewrite | REJECT | No required capability justifies runtime shell migration |
| Cross-platform | Electron/Tauri | REJECT | Adds new runtime/security/product boundary |
| Cross-platform | MAUI/Avalonia | REJECT | Rewrite cost exceeds convergence benefit |
| macOS UI stack | Keep AppKit | BUILD | Native and already integrated with runtime |
| Navigation | top tabs | REJECT as primary IA | Does not scale to complete product scope |
| Navigation | labeled sidebar | BUILD | Scannable, scalable, native desktop pattern |
| Design system | page-local styling | REJECT | Causes drift and inconsistent semantics |
| Design system | semantic tokens | BUILD | One semantic contract, native mappings |
| State | view-owned ad hoc strings | REJECT | Can drift from runtime truth |
| State | canonical UX status model | BUILD | Consistent, testable, accessible |
| Runtime coupling | direct view-to-core everywhere | REPAIR | Add presentation adapter/view-model boundary |
| Activity | raw logs as primary | REJECT | Poor task comprehension |
| Activity | structured timeline + raw diagnostics | BUILD | Human-readable operational model |
| Security | hide complexity | REJECT | Authority must be visible and factual |
| Security | progressive disclosure | BUILD | Safe defaults plus inspectable detail |
| Theme | fixed palette | REJECT | Breaks platform expectations/accessibility |
| Theme | semantic light/dark/high-contrast mapping | BUILD | Native adaptation |
| Icons | emoji/custom mixed set | REJECT | Inconsistent/product-unprofessional |
| Icons | platform-native/system-compatible semantic icons | BUILD | Familiar and accessible |
| Future FMG | design later | REJECT | Would force repeated architecture churn |
| Future FMG | freeze surface contracts now | BUILD | Stable homes without fake implementation |
| Animations | decorative transitions everywhere | REJECT | Noise/performance/accessibility |
| Animations | short causal feedback only | BUILD | Clarifies state changes |
| Data density | card everything | REJECT | Dashboard clutter |
| Data density | hierarchy + rows + cards selectively | BUILD | Better technical scanning |
| Completion | FMG-026 implies premium UI | REJECT | Engine and product experience are separate gates |
| Completion | FMG-026 + FMUX-020 | BUILD | Explicit complete product definition |

## Scope authority

FMUX may consume FMG capabilities but may not:
- change FMG security semantics;
- claim unavailable capability;
- weaken containment/policy/version/evidence rules;
- create a parallel execution path;
- persist content prohibited by existing privacy law.
