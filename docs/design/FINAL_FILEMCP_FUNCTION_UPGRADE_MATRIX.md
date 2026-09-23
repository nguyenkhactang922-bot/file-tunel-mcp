# FINAL FileMCP Function Upgrade Matrix

Status: FINAL DESIGN DECISION MATRIX — PRE-FREEZE INPUT
Date: 2026-09-23
FileMCP source baseline: feature source unchanged since 38026d8a23136b9371369855354acabe4bb8b3e2; current design HEAD at matrix creation: 37fe1455c8772b6b211272cda45b5dfb14899907
Authority inputs:
- docs/audit/FINAL_CROSS_REPO_INDEPENDENT_ARCHITECTURE_AUDIT_MASTER_SPEC.md
- docs/audit/FINAL_CROSS_REPO_CODING_AGENT_ARCHITECTURE_AUDIT.md
- docs/design/CROSS_REPO_CAPABILITY_AND_CONTRADICTION_MATRIX.md
- exact current FileMCP source

Primary action vocabulary:
KEEP / KEEP + HARDEN / ADAPT / REPLACE / ADD / DEPRECATE / REMOVE / DEFER / REJECT.

No row is authorization to code until ADR-0005 and the master dependency graph are frozen.

## Decision matrix

| FileMCP current capability | Exact current source | Current strength | Current weakness / gap | Strongest external evidence | Final action | Target design / acceptance |
|---|---|---|---|---|---|---|
| Loopback MCP listener | Windows `LocalMcpServer.cs`; macOS `LocalMCPServer.swift` | narrow local attack surface; existing connection/header limits | no material architecture gap found | ChatCMD public endpoint is broader; Codex/OpenHands do not justify replacing loopback | KEEP | listener remains loopback-only; no public bind becomes normal mode |
| Runtime local authentication | Windows runtime/credential store + LocalMcpServer; macOS runtime/keychain path | fresh local token; credential separation | policy classification is separate concern | Codex separates authority/policy from transport auth | KEEP | transport identity remains independent of tool policy |
| OpenAI Secure MCP Tunnel | `LocalMcpRuntime.cs` / `TunnelSupervisor.cs`; macOS equivalents | avoids public bearer-token MCP URL; bounded supervision | no source-backed need to replace | ChatCMD public tunnel/token model has larger credential surface | KEEP | preserve header injection/env allowlisting; tunnel is transport only |
| MCP request/response dispatch | Windows `LocalMcpServer.cs`; macOS `LocalMCPServer.swift` | modern + legacy MCP handling; bounded connections | tool catalog is assembled from duplicated native schemas | ChatCMD canonical router/catalog | ADAPT | runtime advertises/validates against canonical language-neutral manifest |
| Tool definitions/catalog | Windows `LocalTools.ToolDefinitions`, `CodexSkillRegistry`, `LocalMcpServer.AllToolDefinitions`; macOS tool definitions | current parity gate works | no single schema/hash/version/risk authority | ChatCMD `tool_catalog.rs`; Goose tool filtering; Codex policy separation | ADD | canonical manifest with protocol/catalog/instruction version+hash, input/output schema, risk/effect/capability flags; C#/Swift exact validation |
| Tool visibility | current static tool set + `EnableCommands` | simple | not tied to fine-grained server policy | Goose available_tools; ChatCMD capability classification; Codex policy | ADAPT | effective catalog may hide denied capabilities, but runtime authorization always rechecks |
| SafePathResolver / path containment | Windows `SafePathResolver.cs`; macOS path resolution in `LocalMCPServer.swift` | strong shared-root and reparse/symlink containment | authority is primarily resolve-time; mutation race remains possible | Codex no-follow/path-swap tests; ChatCMD mutation conflict tests | KEEP + HARDEN | add commit-time Mutation Guard: revalidate canonical/no-follow path identity and ancestor authority immediately before mutation |
| `read_file` | Windows `LocalTools.ReadFile`; macOS `readFile` | bounded file size/output | no version identity | ChatCMD versioned reads | KEEP + HARDEN | return version identity/metadata without breaking compatibility; content remains bounded |
| `read_file_range` | Windows `ReadFileRange`; macOS `readFileRange` | targeted bounded line reads | no version token; no continuation identity | ChatCMD v2 text reads | KEEP + HARDEN | include strong/opaque version identity and optional bounded continuation metadata |
| `list_files` | Windows `LocalTools.ListFiles`; macOS equivalent | fixed hard cap | no common budget/cursor; no cooperative cancellation contract | ChatCMD budget/cursor model | KEEP + HARDEN | common ToolBudget; usage/truncation; optional opaque cursor where pagination is exposed |
| `search_content` | Windows `LocalTools.SearchContent`; macOS `searchContent` | literal search, caps, scan counters | cancellation not checked deeply; no resumable cursor; lexical only | ChatCMD budgets/cursors; Aider repo-map for structural context | KEEP + HARDEN | budget + cooperative cancellation + signed/bound cursor; structural intelligence stays separate Phase B service |
| `search_filenames` | Windows `SearchFilenames`; macOS `searchFilenames` | simple bounded discovery | no shared budget/cursor | ChatCMD scalable find | KEEP + HARDEN | common budget/cancellation contract; cursor only if required |
| `write_file` | Windows `LocalTools.WriteFile`; macOS `writeFile` | atomic whole-file replacement | stale-read overwrite possible; no expected version; path may change after resolution | ChatCMD expectedVersion + atomic writer; Codex path-swap tests | KEEP + HARDEN | expected-version precondition + Mutation Guard before final publish; preserve atomic whole-file compatibility path |
| `delete_file` | Windows `DeleteFile`; macOS `deleteFile` | root/path safety; symlink semantics considered | no expected version/path identity recheck at delete time | ChatCMD versioned delete; Codex no-follow principles | KEEP + HARDEN | optional/required expected-version based on target class; commit-time Mutation Guard |
| `delete_directory` | Windows `DeleteDirectory`; macOS `deleteDirectory` | refuses shared root and non-directory/reparse misuse | recursive destructive action has no version/freshness precondition | ChatCMD dry-run/quarantine options | KEEP + HARDEN | Mutation Guard + policy risk class + dry-run design; quarantine DEFER |
| Atomic multi-edit primitive | absent | — | full-file rewrite is only canonical edit path | ChatCMD `fs_apply_edits`; Codex/Aider model edit adapters | ADD | `apply_edits`: expected strong version + non-overlap validation + dry-run + stage + Mutation Guard + atomic publish |
| Model-specific patch/search-replace adapters | absent | avoids duplicate semantics | ergonomic editing may be weaker for models | Aider edit formats; Codex apply_patch | DEFER | adapters may compile into `apply_edits`; never become storage/security authority |
| File version token | absent | — | no optimistic concurrency identity | ChatCMD authenticated version token | ADD | opaque/authenticated token binding path/identity + content-strength evidence appropriate to mutation; stale mismatch fails closed |
| Mutation Guard | absent as explicit subsystem | current resolver is strong baseline | TOCTOU path/ancestor swap window | Codex `no_follow` tests + ChatCMD adversarial mutation tests | ADD | final pre-commit no-follow/canonical identity validation on Windows/macOS with adversarial swap tests |
| ProcessRunner | Windows `ProcessRunner.RunAsync/StartManaged`; macOS `ProcessRunner.run/startManaged` | executable+argv internally; bounded stdout/stderr; timeout; process-tree/group cleanup | MCP does not expose structured primitive; environment baseline too broad for current shell tool | ChatCMD command runner; Codex structured lifecycle | KEEP + HARDEN | retain native runners; add explicit structured result state and sanitized environment helper |
| `run_command` | Windows `LocalTools.RunCommandAsync`; macOS `runCommand` | flexible shell compatibility | shell-string boundary; inherits broad host environment; open-world side effects | ChatCMD structured command; Codex policy/sandbox | KEEP + HARDEN | retain as explicit high-risk shell compatibility tool; policy classification; sanitized/controlled environment where compatibility permits |
| `exec_process` | absent MCP tool; runner foundation exists | low implementation delta | no deterministic non-shell MCP primitive | ChatCMD `command_run`; Codex execution lifecycle | ADD | executable + argv + cwd + bounded env overrides + timeout/output budget + terminal state/exit/timedOut/cancelled/truncated + operation ID |
| Durable command idempotency registry | absent | avoids false safety today | retries are caller-managed | ChatCMD execution registry | DEFER | add only if a concrete retry/resume contract is proven; never claim arbitrary side-effect commands idempotent from a key alone |
| Execution backend abstraction | absent formal interface | simple direct runner path | future isolation could otherwise force refactor | Codex platform sandboxes; OpenHands host/container/remote workspaces | DEFER | structured exec contract must be backend-neutral enough for later isolated backend, but do not add abstraction before second backend is approved |
| Optional isolated execution backend | absent | maximum host fidelity now | host commands can reach user authority outside workspace if allowed | Codex OS sandbox; OpenHands hardened container runtime | DEFER | future ADR only; host remains default; isolated backend must define network, mounts, credentials, provenance, resource caps, cleanup and cross-platform scope |
| Git repository discovery/layout safety | Windows `GitTools.GitRepoAsync`, metadata validation; macOS equivalents | strong worktree/gitdir/common-dir/object containment | no material replacement gap | compared repos do not provide stronger FileMCP-specific semantic boundary | KEEP | preserve as invariant |
| `git_status/log/diff/add/commit/push` | Windows `GitTools.cs` methods; macOS matching methods | contained Git operations; safe-mode restrictions | result evidence/freshness not first-class | Aider Git workflow; Codex sandbox complements but does not replace semantics | KEEP + HARDEN | attach structured result/evidence metadata where applicable; no automatic orchestration commits |
| Git safe mode | Windows `RunGitAsync`, `SafeGitConfigurationArguments`, config/filter checks; macOS equivalents | suppresses hooks/signing/config/content-filter/local-transport attack paths | no source-backed stronger replacement | Codex sandbox is complementary; Aider/Cline optimize workflow not same security | KEEP | architectural invariant; future isolation cannot remove semantic checks |
| Codex skill discovery/loading | Windows `CodexSkillRegistry.cs`; macOS skill support | bounded reusable instructions | not a full provenance/digest model | Codex hierarchical instruction provenance | ADAPT | keep skills; add project-context source/provenance/effective digest; instructions never grant authority |
| Project context | no first-class canonical tool | repo state can be read manually | no bounded authoritative provenance/digest contract | Codex project instructions; ChatCMD project_context | ADD | bounded source list, scope, provenance, version/range, effective digest; separate from authorization |
| Repository symbol map/intelligence | absent | no index/privacy complexity | large-repo structural context weak | Aider tree-sitter repo map | DEFER | Phase B on-demand metadata-only `repo_map/symbol_search`; rebuildable cache; baseline tools work without it |
| Observability correlation | Windows `LogicalChatCorrelation`, `LogicalSessionRegistry`, `ObservabilityHub`; macOS equivalents | privacy-minimal correlation/metadata | not verification authority | ChatCMD/Cline evidence concepts | KEEP | telemetry remains observability only |
| Telemetry persistence | Windows `TelemetryPersistence.cs`; macOS equivalent | counters/metadata; privacy-preserving | should not absorb evidence/task content | cross-repo broad persistence is larger than product need | KEEP | no raw command/prompt/file/tool-body persistence |
| Structured evidence/freshness layer | absent as first-class authority | — | cannot represent source-fresh PASS/FAIL/STALE independently of stdout | ChatCMD execution evidence; Cline recovery distinctions; Codex structured state | ADD | metadata-only evidence store/envelope with passed/failed/not-run/unknown/stale/blocked/N/A; bounded retention/quota; source-state digest |
| Checkpoint/restore | absent | avoids destructive restore complexity | no local workspace rollback | Cline transactional checkpoints | DEFER | separate ADR only; Git != checkpoint != task state != evidence != observability |
| Runtime/tunnel supervision | Windows `TunnelSupervisor.cs`; macOS `TunnelSupervisor.swift` | verified restart/backoff/cooldown | no architecture gap from cross-repo audit | OpenHands runtime lifecycle is much broader product layer | KEEP | preserve current bounded supervisor |
| Shared ToolBudget | fixed constants exist | hard caps already prevent unbounded work | caps are fragmented; caller cannot lower uniformly; no common usage/truncation | ChatCMD budget contracts | ADD | common hard server caps + caller-lowerable limits + usage/truncation + cancellation contract |
| Cursor contract | mostly absent | simplicity | large scans cannot resume safely | ChatCMD signed/opaque cursor pattern | ADD where needed | cursor binds root/query/options/generation/freshness; tamper/stale continuation fails closed |
| Policy profiles | coarse `EnableCommands` + hard checks | simple, fail-closed | insufficient risk/effect granularity | Codex allow/prompt/forbidden; ChatCMD policy; Goose visibility filtering | ADAPT | server-owned restricted/workspace-auto/custom profiles; separate FS/network/open-world dimensions; no model self-elevation |
| Persistent PTY | absent MCP-facing | avoids state/resource complexity | interactive CLIs unsupported | ChatCMD PTY; Cline/OpenHands terminal use | DEFER | Phase B only with replay bounds, expiry, cancellation, policy, cleanup; never canonical build/test proof |
| Ephemeral large-output artifact spillover | absent | no content persistence expansion | inline limits may eventually block workflows | ChatCMD content refs/artifact quotas | DEFER | only after measured need; content storage separate from observability and short-lived |
| MCP-of-MCP composition | absent | focused secret/trust boundary | cannot centrally host third-party providers | Goose extensions | REJECT | ChatGPT/separate gateway composes providers; FileMCP stays focused local execution server |
| Local task manager | absent | ChatGPT + repo Markdown remain single orchestration law | no local durable task UI | ChatCMD/Cline/OpenHands task/session systems | REJECT | do not duplicate orchestration or persist broad content |
| Local sub-agent runtime | absent | authority/privacy remain simple | no local autonomous children | ChatCMD/Goose/OpenHands subagents | REJECT | future product-level ADR only if FileMCP is intentionally redefined as agent runtime |
| Browser DOM automation | absent | no browser trust/selector dependency | none for current product | ChatCMD optional extension | REJECT | direct MCP remains authoritative |
| Public tokenized MCP URL | absent | avoids transferable bearer URL authority | none for current product | ChatCMD public endpoint pattern | REJECT | keep loopback + Secure Tunnel/local token |
| Cross-platform parity gate | `tests/test_tool_surface_parity.ps1` + native Verify workflows | catches required tool presence | not exact full schema/capability hash parity | ChatCMD canonical catalog | KEEP + HARDEN | exact canonical manifest/hash validation on both runtimes and packaged/native CI |
| Release/build verification contracts | tests + Verify workflows | existing native x64/ARM64/macOS gates | new architecture tasks will need negative/adversarial gates | Codex/ChatCMD adversarial suites | KEEP + HARDEN | every common new contract requires Windows + macOS implementation and adversarial proof before PASS |

## Strong FileMCP capabilities protected from replacement

The final comparative audit found no justification to replace:
- loopback + runtime local-auth boundary;
- OpenAI Secure MCP Tunnel topology;
- shared-root/reparse containment;
- Git safe mode;
- native C#/Swift dual runtime;
- privacy-minimal observability;
- existing native process-runner cleanup semantics.

These are architecture invariants unless a future ADR presents stronger source/test evidence.

## Required Phase A additions/hardening

Phase A architecture requires:
1. canonical tool manifest/hash/capability authority;
2. structured result contract;
3. structured `exec_process`;
4. sanitized environment contract;
5. strong file version identity;
6. Mutation Guard;
7. atomic versioned `apply_edits`;
8. shared ToolBudget + cooperative cancellation + cursors where needed;
9. metadata-only evidence/freshness;
10. bounded project-context provenance/digest;
11. server-owned policy profiles;
12. exact C#/Swift contract parity and adversarial regression.

## Deferred by evidence, not unknown

The following are deliberately deferred and are not blockers for Phase A:
- optional isolated execution backend;
- repository symbol map/index implementation;
- checkpoint/restore;
- persistent PTY;
- artifact spillover;
- durable command idempotency registry.

## Explicitly rejected from current FileMCP core

- public bearer-token MCP URL as primary transport;
- browser ChatGPT DOM automation;
- broad prompt/command/tool-body/file-content persistence;
- mandatory Docker/VM runtime;
- MCP-of-MCP provider gateway role;
- local general task manager;
- local sub-agent/model runtime;
- full-source persistent repository index;
- Rust/Python rewrite;
- custom application-layer crypto for local obfuscation.

## Matrix completion gate

This matrix contains no unresolved UNKNOWN/TBD architecture decision for Phase A. Deferred items have explicit scope and prerequisites. Architecture freeze still requires independent red-team review, final repaired design, ADR-0005 and master task graph.
## Red-team repair deltas integrated into final matrix

| Capability / prerequisite | Exact current source | Final action | Frozen target |
|---|---|---|---|
| Canonical catalog artifact | absent | ADD | versioned `contracts/tool_catalog.v1.json` (or equivalently named frozen artifact) is the single schema/capability authority; native handler/schema coverage must exact-validate against it |
| SourceStateRef provider | absent | ADD | versioned evidence dependency provider binding canonical workspace/repo identity, Git/source fingerprints, catalog hash, policy generation and/or scoped file versions without persisting raw content |
| Policy migration adapter | `EnableCommands` settings/runtime paths | ADAPT | false -> restricted-equivalent; true -> migration-only legacy-command-compatible; workspace-auto requires explicit local user selection |
| exec_process environment policy | current ProcessRunner accepts supplied environment; run_command passes broad host env | ADD | exec_process default no arbitrary host-env inheritance; minimal platform baseline + local allowlisted pass-through + bounded policy-checked overrides |
| AuthorizedPathSnapshot | absent explicit abstraction | ADD | stable parent/target object identity captured and rechecked no-follow immediately before mutation; string canonicalization alone cannot satisfy Mutation Guard |
| Operation policy generation | absent | ADD | prepared side effects capture effective policy generation/hash and reauthorize immediately before exec/commit |
| Cursor lifecycle signer | absent | ADD where cursor tools are introduced | authenticated short-lived read cursor bound to tool/options/root/generation/position; restart invalidation acceptable |

These are prerequisites/acceptance refinements, not new product-surface expansion.

## Complete-scope extension note

This matrix remains authoritative for foundation decisions. `FINAL_COMPLETE_SCOPE_FUNCTION_MATRIX.md` resolves the former DEFER items into BUILD or REJECT before implementation begins.
