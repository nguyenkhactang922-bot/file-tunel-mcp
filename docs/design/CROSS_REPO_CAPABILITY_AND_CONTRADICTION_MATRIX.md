# CROSS-REPO Capability and Contradiction Matrix

Status: FINAL SYNTHESIS — SUBJECT TO RED-TEAM REPAIR
Date: 2026-09-23

| Topic | ChatCMD | Codex | OpenHands | Aider | Cline | Goose | FileMCP today | Final FileMCP decision | Why |
|---|---|---|---|---|---|---|---|---|---|
| Primary role | local supervised agent platform | coding-agent runtime/CLI | agent runtime/workspace platform | coding assistant | agent/session platform | extensible agent | secure execution bridge | KEEP bridge role | narrow role minimizes duplicated orchestration and persistence |
| Transport | tokenized MCP/public tunnel options | client/service integrations | local/remote agent server | CLI/model APIs | IDE/CLI/services | MCP/extensions | loopback + local token + Secure Tunnel | KEEP FileMCP | smaller public credential surface |
| Command boundary | executable + argv `command_run` | structured internal exec plus shell UX | workspace `execute_command` often shell string | shell/tool driven | terminal-oriented | shell/platform tools | MCP `run_command` shell string; ProcessRunner argv internally | ADD `exec_process`, KEEP `run_command` | get deterministic primitive without breaking shell workflows |
| Command environment | bounded request env | policy/sandbox controlled environment | sanitized/mediated in hardened runtime | inherits app process context patterns | app/session context | extension env/secret resolution | run_command inherits whole host env | structured exec uses sanitized baseline | reduce accidental secret exposure |
| Process cleanup | bounded runner/registry | unified exec lifecycle | runtime/container lifecycle | process tool dependent | terminal/task lifecycle | agent/tool cancellation | Job Object/process group cleanup | KEEP + HARDEN | current runner already strong |
| Durable exec registry | idempotent execution registry | session/process state | runtime registry | no equivalent | durable session state | session task state | none | DEFER | arbitrary command idempotency is not generally safe/needed |
| Policy | allow/approval/deny | approval + exec policy | runtime/config gates | user orchestration | plan/act/approval | tool availability/config | EnableCommands + hard safety | ADD typed server-owned profiles | need finer authority without per-call click default |
| Sandbox | not primary differentiator | OS-specific sandbox | local + container/remote backends | no general sandbox | terminal controlled by app | no universal isolation | host execution | host default, isolation DEFER | product fidelity first; separate future backend |
| Network authority | policy/open-world classes | explicit network policy | container networking/deployment | host network | app/task tool permissions | extension network transports | shell has user network authority | separate open-world/network risk dimension | sandbox and network policy must not be conflated |
| Workspace authority | canonical workspace service | sandbox writable roots/protected metadata | workspace backend/mounts | repo working tree | workspace/session | working dir/extensions | SafePathResolver shared root | KEEP + HARDEN | strong fit; add commit-time guard |
| Path race defense | revalidation/version tests | no-follow/path-swap patch tests | mount/symlink checks | Git/file operations | checkpoint safeguards | normal FS | resolve-time canonicalization | ADD Mutation Guard | close TOCTOU gap |
| File identity | authenticated version token | patch state/path checks, not same token | workspace abstraction | mtime/cache/edit matching | Git/checkpoint identities | none central | none | ADD strong opaque version | necessary optimistic concurrency primitive |
| Atomic editing | staged/versioned apply_edits | apply_patch may leave partial side effects | workspace write APIs | model edit formats | IDE edit/checkpoint | tool dependent | atomic whole-file write only | ADD atomic apply_edits | strongest low-level mutation contract |
| Model edit formats | range edits + blobs | apply_patch | agent tools | search/replace, patch, udiff, whole-file | editor/tool formats | tool dependent | whole-file write | DEFER adapters | adapters sit above canonical storage primitive |
| Delete safety | version/dry-run/quarantine options | sandbox/path rules | workspace isolation | Git undo | checkpoint restore | tool dependent | direct safe delete | KEEP + HARDEN; quarantine DEFER | version/path guard first; avoid new UX/storage now |
| List/search scaling | budgets/cursors/index | bounded tooling | workspace APIs | repo map | search/tool ecosystem | extensions | fixed caps | ADD common budget/cursor/cancel | retain simple tools while making them resumable/cancellable |
| Cooperative cancellation | context cancellation throughout | cancellation-aware runtime | runtime/session cancellation | agent loop | task/session cancellation | tokio cancellation | process yes; search loops no | ADD to long loops | current concrete gap |
| Repository map | project context/indexes | project instructions/search | workspace tools | tree-sitter ranked repo map | context services | agent context | none | Phase B on-demand symbol map | useful for large repos, not foundational safety |
| Project instructions | project_context | hierarchical AGENTS provenance | agent/project config | conventions/context | rules/skills | recipes/agents | Codex skills + repo docs | ADD bounded project_context | separate context from authority |
| Tool catalog | canonical hash/capabilities | MCP/tool registries | tool/action schemas | internal coder modes | tool registry | multi-provider tool catalog | duplicated C#/Swift definitions | ADD canonical manifest/hash | prevents cross-platform schema drift |
| Tool visibility | capability classification | policy/tool availability | runtime capabilities | context/tool choices | mode/tool visibility | `available_tools` | static tool set + EnableCommands | policy-filtered effective catalog | UX minimization while auth stays server-side |
| Evidence | execution ID/state/source fingerprints | structured events/state | event/runtime state | Git/lint/test feedback | completion/session state | tool/session events | telemetry counters only | ADD metadata-only evidence | distinguish PASS/freshness from stdout and telemetry |
| Observability | events/storage | tracing/session logs | events/logs | CLI output | rich telemetry/history | telemetry/session | privacy-minimal counters/traces | KEEP | user privacy boundary is stronger fit |
| Checkpoint | task persistence | rollouts/session resume | persisted runtime/conversation | Git commits | transactional Git snapshot restore | session state | none | DEFER separate ADR | safe restore is high-complexity and not Phase A prerequisite |
| Git workflow | Git/runtime tools | Git under sandbox/policy | Git workspace APIs | auto-commit/dirty isolation | checkpoint refs/history | tools/extensions | hardened Git safe mode | KEEP safe mode; no auto-commit default | security vs orchestration are different layers |
| PTY | persistent shell tools | unified exec/interactive process | terminal runtime | terminal usage | terminal integration | shell tools | none MCP-facing | DEFER | not required for deterministic build/test proof |
| Artifacts | content refs/artifact quota | output/events/files | workspace files/events | file outputs | session artifacts | session/tool outputs | bounded inline output | DEFER spillover | add only when real output limit blocks workflows |
| Task state | durable tasks | threads/rollouts | conversations | coding session | durable sessions/tasks | agent sessions | repository state files + ChatGPT orchestration | REJECT local general task manager | avoids duplicate authority/persistence |
| Sub-agents | full child runtime | agent concepts | local task agents | no central local subagent | subtasks/agent modes | full subagent runtime | none | REJECT from core | changes FileMCP product from bridge to agent platform |
| MCP composition | server is product endpoint | supports MCP integrations | runtime tools | not gateway focus | connects MCP | first-class multi-provider extensions | one focused server | REJECT from core | ChatGPT can compose connectors; FileMCP need not own external secrets/lifecycle |
| Browser DOM bridge | optional extension | none required | none | none | IDE integration | none required | none | REJECT | fragile extra trust boundary |
| Persistent content | task/report DB | rollouts/thread history | events/conversations | cache/Git | messages/session artifacts | sessions | metadata counters only | KEEP privacy-minimal | no need for raw prompt/command/file persistence |
| Cross-platform strategy | Rust cross-platform | platform-specific sandbox code | Linux/container-heavy + local abstractions | Python portability | TS/IDE portability | Rust | native C# + Swift | KEEP dual-native + canonical contracts | rewrite cost exceeds benefit |

## Key contradictions resolved

### Policy versus sandbox

ChatCMD emphasizes policy/approval; Codex proves policy plus OS sandbox; OpenHands proves container isolation is a full backend/lifecycle. FileMCP chooses **server-owned policy now, host execution default, optional isolation later**.

### Patch ergonomics versus mutation safety

Codex/Aider provide model-friendly patches; ChatCMD provides stronger optimistic/atomic mutation semantics. FileMCP chooses **atomic versioned storage primitive first, patch adapters later**.

### Context intelligence versus privacy/simplicity

Aider shows structural repo maps materially help large repos, but FileMCP does not need a mandatory persistent source index. Choose **on-demand metadata-only repository intelligence after Phase A**.

### Recovery versus product scope

Cline/OpenHands show robust recovery requires durable task/session/checkpoint machinery. Current FileMCP keeps orchestration in ChatGPT and therefore chooses **no local general task manager; checkpoint deferred**.

### Extensibility versus trust surface

Goose proves MCP composition is technically sound for an agent product. FileMCP chooses **coexistence rather than gateway composition**, preserving its focused secret/trust boundary.
