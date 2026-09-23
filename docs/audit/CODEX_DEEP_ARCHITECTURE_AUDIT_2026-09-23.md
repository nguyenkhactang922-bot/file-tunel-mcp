# OpenAI Codex Deep Architecture Audit for FileMCP

Status: INDEPENDENT SOURCE AUDIT COMPLETE
Date: 2026-09-23
Repository: https://github.com/openai/codex
Pinned commit: cb1eea3e98ebc433ab5f9c12ce043e979d1902df
Audit clone: D:\Tools\_audit\Codex
Purpose: challenge ADR-0004 on sandbox, execution policy, process execution and mutation safety.

## Evidence boundary

This audit reads source/docs/tests at the pinned commit. A focused `cargo test -p codex-execpolicy --lib --quiet` attempt exceeded the 120-second bridge window during compilation. That attempt is AUDIT-TIME-BLOCKED, not PASS or FAIL. Source-backed tests are still identified below.

## Finding C1 - policy and sandbox are separate layers

Source evidence:
- `codex-rs/execpolicy/README.md` defines command policy rules with decisions `allow`, `prompt`, and `forbidden`.
- `codex-rs/core/README.md` and protocol permission types define filesystem/network sandbox policy separately from approval policy.
- `codex-rs/protocol/src/permissions.rs` carries filesystem access modes and network policy as explicit types.

Implication:
FileMCP must not treat future policy profiles as a substitute for isolation. Policy answers "may this operation be requested/executed?"; a sandbox answers "what can the process actually touch if it runs?".

FileMCP decision impact:
- KEEP server-owned policy work from ADR-0004.
- AMEND architecture so execution backend/isolation is a separate seam.
- Do not require a sandbox for every FileMCP command before proving product fit.

## Finding C2 - Codex uses OS-specific isolation, not one universal container

Source evidence:
- macOS: Seatbelt profiles enforce sandbox policy.
- Linux: bubblewrap is used for richer filesystem policy; legacy Landlock remains for semantically sufficient cases.
- Windows: Codex has Windows sandbox policy implementations and explicitly fails closed where requested precision is unsupported.

Trade-off:
OS sandboxing provides stronger containment than FileMCP's current cwd/root checks for arbitrary child processes, but it is platform-specific and materially increases implementation/test burden.

FileMCP decision impact:
The strongest fit is an execution-backend abstraction:
- HostExecutionBackend remains the default for developer fidelity.
- Optional IsolatedExecutionBackend is a future implementation behind the same structured exec contract.
- Policy remains independent of backend selection.

This supports host-first + optional isolation rather than mandatory Docker/VM.

## Finding C3 - execpolicy is explicit and testable

Source evidence:
`codex-rs/execpolicy/README.md` describes Starlark `prefix_rule` policy including:
- command-prefix matching;
- `allow | prompt | forbidden` decisions;
- executable path metadata;
- match/not-match examples validated when policy loads;
- strictest matching decision behavior.

FileMCP impact:
FileMCP policy profiles should be server-owned and testable as data/contracts. Repository instructions must never grant more authority. A `workspace-auto` profile can allow normal pre-authorized workspace operations without per-call confirmation while open-world/privileged classes remain denied or locally gated.

Do not copy:
- Codex's exact Starlark policy language unless FileMCP proves it needs user-programmable policy.
- A smaller typed JSON/settings policy is preferable initially.

## Finding C4 - patch safety includes final-path rechecking

Source evidence:
`codex-rs/apply-patch/tests/suite/no_follow.rs` includes cases for:
- symlink ancestor rejection;
- symlink leaf rejection;
- path swap after verification, where a directory is replaced by a symlink and the patch must fail.

This is important for FileMCP because current `SafePathResolver.Resolve()` proves containment at resolution time, while current writes later operate on an absolute path. A parent component can theoretically change after resolution.

FileMCP impact:
Add a platform-specific **Mutation Guard** contract before final commit/delete:
- capture authorized canonical path/identity;
- revalidate path and file version immediately before publish;
- use no-follow/handle-based primitives where available;
- fail closed if path identity or ancestor identity changes;
- include adversarial junction/symlink swap tests on Windows and macOS.

This is stronger than merely adding `expected_version` to the existing write tool.

## Finding C5 - sandbox policy protects metadata paths inside writable trees

Codex workspace-write semantics carve out protected metadata such as `.git` and other authority/config roots even when the larger workspace is writable.

FileMCP already has unusually strong Git-specific safe mode. Therefore:
- KEEP FileMCP Git safety as an invariant;
- do not replace it with generic sandbox protection;
- optional isolation may add another defense layer but cannot remove Git semantic validation.

## Finding C6 - project instructions are not authority

Codex architecture separates project instructions from sandbox/approval policy. This supports FileMCP's requirement that AGENTS/project context may influence behavior but never increase tool authority.

## Source-backed test inventory used in this audit

Relevant source/tests include:
- `codex-rs/core/tests/suite/approvals.rs`
- `codex-rs/core/tests/suite/exec_policy.rs`
- `codex-rs/core/tests/suite/permissions.rs`
- `codex-rs/core/tests/suite/request_permissions.rs`
- `codex-rs/core/tests/suite/unified_exec.rs`
- `codex-rs/core/tests/suite/windows_sandbox.rs`
- `codex-rs/apply-patch/tests/suite/no_follow.rs`

Local focused test execution: AUDIT-TIME-BLOCKED due compilation exceeding bridge time window.

## FileMCP actions after Codex audit

| Capability | Preliminary action | Reason |
|---|---|---|
| FileMCP path/Git safety | KEEP + HARDEN | semantic controls remain valuable even with isolation |
| server-owned policy profiles | ADAPT | Codex confirms policy should be explicit and separate from sandbox |
| structured `exec_process` | ADD | safer deterministic boundary than shell-string default |
| execution backend abstraction | ADD | prevents future isolation from redesigning exec contract |
| host execution backend | KEEP | preserves developer fidelity and existing ProcessRunner strengths |
| isolated execution backend | DEFER | useful optional defense; cross-platform cost is high |
| mutation-time no-follow/path revalidation | ADD | closes TOCTOU class not clearly covered by current FileMCP write path |
| Starlark policy engine | REJECT for initial architecture | unnecessary complexity for current FileMCP needs |

## Independent conclusion

Codex does not invalidate ADR-0004's structured execution/policy direction. It **amends** it in two important ways:
1. policy and isolation must be separate architecture layers;
2. mutation safety needs a commit-time path/identity guard, not only optimistic file versioning.
