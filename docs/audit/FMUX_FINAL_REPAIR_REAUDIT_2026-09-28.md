# FMUX Final Repair Re-Audit

Status: PASS — DESIGN GATE
Date: 2026-09-28

Reviewed:
- FMUX independent multi-round audit
- product experience architecture
- design system/component spec
- interaction/status/FM G mapping
- decision matrix
- dependency graph
- ADR-0007
- FMG complete scope graph

## Red-team round A — Scope contamination

Question: Does FMUX change FMG-001..026?
Result: PASS.

Repair applied:
- FMUX dependency graph explicitly gates feature surfaces on their FMG dependencies.
- FMUX-020 depends on FMG-026, rather than replacing it.

## Red-team round B — Fake capability risk

Question: Could UI ship controls for Artifact/PT Y/Checkpoint/Docker before core implementation?
Result: PASS after rule.

Rule:
A feature surface may be designed before its FMG dependency but production implementation/control exposure must wait for the real capability.

## Red-team round C — Security boundary drift

Question: Could presentation logic grant authority or reinterpret policy?
Result: PASS.

Rule:
UI consumes policy/capability truth. It never owns authorization.

## Red-team round D — Framework rewrite risk

Question: Is visual modernization being used to justify an unnecessary runtime rewrite?
Result: PASS.

Decision:
Keep WPF + AppKit; modernize presentation architecture.

## Red-team round E — Monolith recurrence

Question: Could FMUX recreate one huge window/controller?
Result: REPAIRED.

Mandatory FMUX-001 acceptance now includes:
- page/view-model contracts;
- shared presentation primitives;
- no new feature UI added to legacy MainWindow monolith without migration plan.

## Red-team round F — Cross-platform drift

Question: Will Windows and macOS diverge?
Result: REPAIRED.

Canonical parity applies to:
- taxonomy;
- state semantics;
- safety language;
- capability availability;
- action outcome.
Pixels/control shapes remain platform-native.

## Red-team round G — Accessibility late-stage risk

Question: Is accessibility postponed until visual polish is complete?
Result: REPAIRED.

Accessibility is a cross-cutting acceptance criterion for every FMUX task; FMUX-017 is a system-wide enforcement gate, not first introduction.

## Red-team round H — Performance

Question: Can live Activity/Terminal/Logs create unbounded UI work?
Result: REPAIRED.

All live collections require:
- bounded in-memory view window;
- virtualized/list-efficient rendering where applicable;
- throttled/coalesced refresh;
- no forced live-tail when user scrolls away.

## P0/P1 blockers

P0: none.
P1: none remaining.

## Final conclusion

FMUX architecture is sufficiently frozen to split implementation and begin FMUX-001.

The next implementation task must be FMUX-001 Presentation Foundation only. Do not begin App Shell until FMUX-001 is verified.
