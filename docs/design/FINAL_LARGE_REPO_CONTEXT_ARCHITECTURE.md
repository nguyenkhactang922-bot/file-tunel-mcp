# FINAL Large-Repository Context Architecture

Status: FROZEN BY ADR-0005
Date: 2026-09-23

## Decision

Separate Project Context from Repository Intelligence.

### Phase A - Project Context: ADD

Discover instruction/rule sources, expose provenance/scope, bounded ranges/excerpts, effective digest and freshness/version information. Project rules never grant authority.

### Phase B - Repository Intelligence: DEFER implementation

Aider proves structural symbol/reference maps can help large repositories. If profiling justifies it, add bounded on-demand repo_map/symbol_search with definitions/references metadata and ranking.

## Cache boundary

Structural cache is rebuildable performance state, separate from telemetry/evidence, not authorization, not required for baseline tools and metadata-oriented rather than full-source persistence by default.

Cache corruption or absence degrades to ordinary read/search tools.

## Why not Phase A

Phase A correctness blockers are catalog drift, process boundary, mutation races, budgets/cancellation, evidence freshness and policy. Repo intelligence improves efficiency/context quality but is not a foundational safety requirement.

## Benchmark gate

Measure repository size, scan latency, token savings, cache build/update time, invalidation frequency, disk/memory cost, parser coverage, generated/vendor handling and monorepo behavior before promotion.

## Phase A large-repo baseline

Existing list/search/read gain common budgets, cooperative cancellation, usage/truncation and cursors where justified. Large repositories remain operable without an index.

## Privacy

Do not store full repository content for observability/task history. Any future parser cache must define exact stored data, retention and deletion before implementation.