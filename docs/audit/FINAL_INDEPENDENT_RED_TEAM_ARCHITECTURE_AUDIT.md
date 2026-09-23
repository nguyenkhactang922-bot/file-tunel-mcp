# FINAL Independent Red-Team Architecture Audit

Status: REPAIRED / CLOSED BY FINAL RE-AUDIT
Date: 2026-09-23

Target: proposed MASTER FileMCP Coding-Agent Gateway Architecture V1.

Method: assume the architecture is wrong and search for authority, compatibility, freshness, corruption and migration ambiguity.

## RT-01 - P1 - canonical catalog source of truth

Finding: a generic language-neutral manifest was insufficient if C#, Swift and the manifest could drift independently.

Repair required and now integrated: one versioned repository catalog artifact is canonical; native advertised schemas and handler registries exact-validate against it; catalog hash is derived from canonical normalized content; descriptions never grant authority.

Status: CLOSED.

## RT-02 - P1 - undefined source-state freshness

Finding: evidence referenced a source/workspace digest without a precise dependency contract.

Repair: SourceStateRef now has versioned providers and explicit dependency scope. Git-backed evidence can bind worktree identity, HEAD, index/tree state, tracked dirty fingerprint, scoped untracked fingerprint, catalog hash, policy generation and relevant file versions. Only digests/metadata persist.

Status: CLOSED.

## RT-03 - P1 - EnableCommands migration ambiguity

Finding: moving to policy profiles could silently reduce or expand existing authority.

Repair: legacy false maps restricted-equivalent; legacy true maps migration-only legacy-command-compatible; workspace-auto requires explicit local user choice; model cannot elevate.

Status: CLOSED.

## RT-04 - P1 - exec_process environment authority

Finding: 'sanitized baseline' was too vague and could either leak secrets or break builds.

Repair: exec_process defaults to no arbitrary host-env inheritance; server supplies minimal platform baseline; local config controls additional pass-through; request overrides are bounded and policy checked; secret-like variables are not implicitly forwarded. run_command may retain legacy compatibility semantics and is high-risk.

Status: CLOSED.

## RT-05 - P1 - Mutation Guard identity precision

Finding: a second path-string canonicalization would not close TOCTOU races.

Repair: AuthorizedPathSnapshot captures stable root/parent/target identity; new targets bind parent + expected leaf state; final mutation uses no-follow/reparse-aware native identity recheck immediately before commit/delete. Windows/macOS primitives may differ but adversarial swap behavior must match.

Status: CLOSED.

## RT-06 - P2 - cursor lifecycle

Repair integrated: cursor binds tool/options/root/generation/position, is authenticated and bounded-lifetime, invalidates across incompatible root/policy/catalog generation; restart invalidation is acceptable; cursor never grants mutation authority.

## RT-07 - P2 - evidence ownership/retention

Repair integrated: evidence is local FileMCP/workspace metadata with bounded configurable retention/quota; storage failure yields unknown/unavailable, never false PASS; basic tools remain available unless evidence is explicitly required.

## RT-08 - P2 - policy generation during prepared operations

Repair integrated: operation context captures effective policy generation/hash and reauthorizes before side-effect exec/commit.

## RT-09 - P2 - project-context/version dependency

Repair integrated: project-context provenance/digest is versioned; context hash is evidence/context material, never an authority token.

## Red-team verdict

No P0 blocker found.

Five P1 blockers were real and required design repair. All five have explicit repair contracts in the final master/security/execution/function-matrix documents.

P2 findings are represented in owning Phase A task acceptance.

Final freeze depends on the separate repair re-audit PASS and ADR-0005.