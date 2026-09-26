#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

TMP_DIR="$(mktemp -d)"
SERVER_PID=""
stop_server() {
    [ -n "$SERVER_PID" ] || return 0
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            kill -0 "$SERVER_PID" 2>/dev/null || break
            sleep 0.05
        done
        if kill -0 "$SERVER_PID" 2>/dev/null; then
            kill -9 "$SERVER_PID" 2>/dev/null || true
        fi
    fi
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
}
cleanup() {
    stop_server
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

MCP_HTTP_FUZZ_ITERATIONS="${MCP_HTTP_FUZZ_ITERATIONS:-160}"
case "$MCP_HTTP_FUZZ_ITERATIONS" in
    ''|*[!0-9]*)
        echo "MCP_HTTP_FUZZ_ITERATIONS must be a positive integer" >&2
        exit 2
        ;;
esac
if [ "$MCP_HTTP_FUZZ_ITERATIONS" -lt 1 ]; then
    echo "MCP_HTTP_FUZZ_ITERATIONS must be at least 1" >&2
    exit 2
fi

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func mutatedCatalog(_ data: Data, _ mutate: (inout [String: Any]) -> Void) throws -> Data {
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fatalError("canonical catalog test fixture must be an object")
    }
    mutate(&root)
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
}

func expectCatalogFailure(_ label: String, _ data: Data, containing expected: String) {
    do {
        _ = try CanonicalToolCatalog.fromPayloadForTest(data)
        fatalError("expected catalog failure: \(label)")
    } catch {
        precondition(error.localizedDescription.contains(expected), "\(label) failed with unexpected error: \(error)")
    }
}

let canonicalURL = URL(fileURLWithPath: "contracts/tool_catalog.v1.json")
let canonicalData = try Data(contentsOf: canonicalURL)
let canonical = try CanonicalToolCatalog.fromPayloadForTest(canonicalData)
let canonicalText = String(data: canonicalData, encoding: .utf8)!
let crlf = Data(canonicalText.replacingOccurrences(of: "\n", with: "\r\n").utf8)
let crlfCatalog = try CanonicalToolCatalog.fromPayloadForTest(crlf)
precondition(canonical.catalogHash == crlfCatalog.catalogHash, "catalog hash must normalize line endings")
try canonical.validateHandlerCoverage(handler: "skills", runtimeHandlerNames: ["list_codex_skills", "load_codex_skill"])
do {
    try canonical.validateHandlerCoverage(handler: "skills", runtimeHandlerNames: ["list_codex_skills"])
    fatalError("missing handler must fail closed")
} catch {
    precondition(error.localizedDescription.contains("missing=[load_codex_skill]"))
}
do {
    try canonical.validateHandlerCoverage(handler: "skills", runtimeHandlerNames: ["list_codex_skills", "load_codex_skill", "extra_tool"])
    fatalError("extra runtime tool must fail closed")
} catch {
    precondition(error.localizedDescription.contains("extra=[extra_tool]"))
}

expectCatalogFailure("stale catalog version", try mutatedCatalog(canonicalData) { $0["catalogVersion"] = "0.9.0" }, containing: "catalogVersion")
expectCatalogFailure("stale instruction version", try mutatedCatalog(canonicalData) { $0["instructionVersion"] = "0.9.0" }, containing: "instructionVersion")
expectCatalogFailure("schema mismatch", try mutatedCatalog(canonicalData) { root in
    var tools = root["tools"] as! [[String: Any]]
    var first = tools[0]
    var definition = first["definition"] as! [String: Any]
    definition["inputSchema"] = "not-an-object"
    first["definition"] = definition
    tools[0] = first
    root["tools"] = tools
}, containing: "inputSchema")
expectCatalogFailure("metadata mismatch", try mutatedCatalog(canonicalData) { root in
    var tools = root["tools"] as! [[String: Any]]
    var first = tools[0]
    first["risk"] = "unknown"
    tools[0] = first
    root["tools"] = tools
}, containing: "risk metadata")
expectCatalogFailure("malformed catalog", Data("{ malformed".utf8), containing: "Malformed canonical tool catalog JSON")
print("swift-tool-catalog: ok (hash=\(canonical.catalogHash))")
SWIFT
swiftc -framework CryptoKit -o "$TMP_DIR/catalog-test" macos/ToolCatalog.swift "$TMP_DIR/main.swift"
"$TMP_DIR/catalog-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func expectEnvelopeFailure(_ label: String, _ envelope: [String: Any], containing expected: String) {
    do {
        try ToolResultEnvelope.validate(envelope)
        fatalError("expected envelope failure: \(label)")
    } catch {
        precondition(error.localizedDescription.lowercased().contains(expected.lowercased()), "\(label) unexpected error: \(error)")
    }
}

let content: [[String: Any]] = [["type": "text", "text": "ok"]]
let success = ToolResultEnvelope.create(isError: false, content: content, structuredContent: ["result": "ok"], warnings: ["non-blocking warning"])
precondition(success["schemaVersion"] as? String == "1.0.0")
precondition(success["status"] as? String == "success")
let operationID = success["operationId"] as! String
precondition(operationID.hasPrefix("op_") && operationID.count == 35)
let successTruncation = success["truncation"] as! [String: Any]
precondition(successTruncation["truncated"] as? Bool == false && successTruncation["reason"] as? String == "none")
precondition((success["usage"] as! [String: Any])["contentItems"] as? Int == 1)
precondition((success["warnings"] as! [String]) == ["non-blocking warning"])

let partial = ToolResultEnvelope.create(isError: false, content: content, structuredContent: ["truncated": true])
precondition(partial["status"] as? String == "partial")
let partialTruncation = partial["truncation"] as! [String: Any]
precondition(partialTruncation["truncated"] as? Bool == true && partialTruncation["reason"] as? String == "server_limit")
let toolError = ToolResultEnvelope.create(isError: true, content: content, structuredContent: nil)
precondition(toolError["status"] as? String == "tool_error")

var carrier: [String: Any] = ["content": content, "isError": false]
ToolResultEnvelope.attach(to: &carrier, isError: false, content: content, structuredContent: ["result": "ok"])
let requiredEnvelope = try ToolResultEnvelope.require(from: carrier)
precondition(requiredEnvelope["status"] as? String == "success")
precondition(carrier["resultEnvelope"] == nil)

var badVersion = success; badVersion["schemaVersion"] = "9.9.9"
expectEnvelopeFailure("unknown schema", badVersion, containing: "schemaVersion")
var badStatus = success; badStatus["status"] = "mystery"
expectEnvelopeFailure("unknown status", badStatus, containing: "status")
var badOperation = success; badOperation.removeValue(forKey: "operationId")
expectEnvelopeFailure("missing operation", badOperation, containing: "operationId")
var badUsage = success; badUsage["usage"] = ["contentItems": -1]
expectEnvelopeFailure("bad usage", badUsage, containing: "usage")
var badTruncation = partial; badTruncation["truncation"] = ["truncated": true, "reason": "none"]
expectEnvelopeFailure("bad truncation", badTruncation, containing: "truncation")
var badWarnings = success; badWarnings["warnings"] = [""]
expectEnvelopeFailure("bad warnings", badWarnings, containing: "warnings")
print("swift-result-envelope: ok")
SWIFT
swiftc -o "$TMP_DIR/result-envelope-test" macos/ToolResultEnvelope.swift "$TMP_DIR/main.swift"
"$TMP_DIR/result-envelope-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func expectDenied(_ policy: ServerPolicy, _ tool: String) {
    do {
        try policy.authorize(tool)
        fatalError("expected policy denial for \(tool)")
    } catch {
        precondition(error.localizedDescription.lowercased().contains("denied"))
    }
}

let restricted = try ServerPolicy.fromLegacy(enableCommands: false)
precondition(restricted.profile == FileMCPPolicyProfiles.restricted)
precondition(restricted.isAllowed("read_file"))
precondition(restricted.isAllowed("write_file"))
precondition(restricted.isAllowed("git_push"))
precondition(!restricted.isAllowed("run_command"))
precondition(!restricted.isAllowed("exec_process"))
precondition(!restricted.legacyUnsafeGitCompatibility)
precondition(restricted.hash == "174b1d27efe868c387b87923665b8d53270f40b48e890e67f40720620d729156")
expectDenied(restricted, "run_command")
expectDenied(restricted, "exec_process")

let legacy = try ServerPolicy.fromLegacy(enableCommands: true)
precondition(legacy.profile == FileMCPPolicyProfiles.legacyCommandCompatible)
precondition(legacy.isAllowed("run_command"))
precondition(legacy.isAllowed("exec_process"))
precondition(legacy.legacyUnsafeGitCompatibility)
precondition(!FileMCPPolicyProfiles.isUserSelectable(FileMCPPolicyProfiles.legacyCommandCompatible))

let workspaceAuto = try ServerPolicy(configuration: LocalPolicyConfiguration(profile: FileMCPPolicyProfiles.workspaceAuto))
precondition(workspaceAuto.isAllowed("write_file"))
precondition(workspaceAuto.isAllowed("git_commit"))
precondition(!workspaceAuto.isAllowed("git_push"))
precondition(!workspaceAuto.isAllowed("run_command"))
precondition(!workspaceAuto.isAllowed("exec_process"))
let workspaceDefs = try workspaceAuto.filterDefinitions(CanonicalToolCatalog.shared.toolDefinitions(handler: "local_tools", commandsEnabled: true))
let workspaceNames = Set(workspaceDefs.compactMap { $0["name"] as? String })
precondition(!workspaceNames.contains("run_command") && !workspaceNames.contains("exec_process") && !workspaceNames.contains("git_push") && workspaceNames.contains("write_file"))

let custom = try ServerPolicy(configuration: LocalPolicyConfiguration(
    profile: FileMCPPolicyProfiles.custom,
    customMaxRisk: "low",
    customAllowedEffects: ["read", "metadata"]
))
precondition(custom.isAllowed("read_file"))
precondition(custom.isAllowed("filemcp_observability_connect"))
precondition(!custom.isAllowed("write_file"))
precondition(!custom.isAllowed("git_push"))
precondition(!custom.isAllowed("run_command"))
precondition(!custom.isAllowed("exec_process"))

let customExec = try ServerPolicy(configuration: LocalPolicyConfiguration(
    profile: FileMCPPolicyProfiles.custom,
    customMaxRisk: "high",
    customAllowedEffects: ["execute"],
    customAllowNetworkOpenWorld: true,
    customAllowShell: false
))
precondition(customExec.isAllowed("exec_process"))
precondition(!customExec.isAllowed("run_command"))

let prepared = custom.capture()
let generation = custom.generation
let oldHash = custom.hash
try custom.update(LocalPolicyConfiguration(
    profile: FileMCPPolicyProfiles.custom,
    customMaxRisk: "high",
    customAllowedEffects: ["read", "metadata", "write"]
))
precondition(custom.generation == generation + 1)
precondition(custom.hash != oldHash)
do {
    try custom.authorize("read_file", prepared: prepared)
    fatalError("stale prepared policy snapshot must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("stale"))
}
print("swift-server-policy: ok")
SWIFT
swiftc -framework CryptoKit -o "$TMP_DIR/server-policy-test" macos/ToolCatalog.swift macos/ServerPolicy.swift "$TMP_DIR/main.swift"
"$TMP_DIR/server-policy-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func expectFailure(_ label: String, containing expected: String, _ body: () throws -> Void) {
    do {
        try body()
        fatalError("expected failure: \(label)")
    } catch {
        precondition(error.localizedDescription.lowercased().contains(expected.lowercased()), "\(label) unexpected error: \(error)")
    }
}

let budgetMeta: [String: Any] = [ToolExecutionContext.budgetMetadataKey: [
    "maxVisitedEntries": 3,
    "maxFilesScanned": 2,
    "maxBytesScanned": 20,
    "maxOutputItems": 2,
    "timeoutMs": 500,
]]
let budget = try ToolExecutionContext(meta: budgetMeta)
precondition(budget.limits.maxVisitedEntries == 3 && budget.limits.maxFilesScanned == 2)
let parsedBudgetJSON = try JSONSerialization.jsonObject(with: Data("{\"io.filemcp/budget\":{\"maxOutputItems\":1}}".utf8)) as! [String: Any]
let parsedBudget = try ToolExecutionContext(meta: parsedBudgetJSON)
precondition(parsedBudget.limits.maxOutputItems == 1, "JSONSerialization NSNumber budget must not be confused with Bool")
precondition(budget.limits.maxBytesScanned == 20 && budget.limits.maxOutputItems == 2)
precondition(budget.tryVisitEntry() && budget.tryVisitEntry() && budget.tryVisitEntry())
precondition(!budget.tryVisitEntry() && budget.truncated && budget.truncationReason == "visited_entries")
let budgetUsage = budget.usage()
precondition(budgetUsage["truncated"] as? Bool == true)
precondition(budgetUsage["truncationReason"] as? String == "visited_entries")

expectFailure("oversized budget", containing: "may only lower") {
    _ = try ToolExecutionContext(meta: [ToolExecutionContext.budgetMetadataKey: [
        "maxVisitedEntries": ToolBudgetLimits.serverCaps.maxVisitedEntries + 1
    ]])
}
expectFailure("unknown budget", containing: "unknown budget field") {
    _ = try ToolExecutionContext(meta: [ToolExecutionContext.budgetMetadataKey: ["future": 1]])
}

var cancelled = false
let cancellable = try ToolExecutionContext(meta: nil, cancellationProbe: { cancelled })
precondition(cancellable.tryContinue())
cancelled = true
precondition(!cancellable.tryContinue() && cancellable.truncationReason == "cancelled")

var now = Date(timeIntervalSince1970: 1_700_000_000)
let timed = try ToolExecutionContext(
    meta: [ToolExecutionContext.budgetMetadataKey: ["timeoutMs": 10]],
    nowProvider: { now }
)
precondition(timed.tryContinue())
now = now.addingTimeInterval(0.011)
precondition(!timed.tryContinue() && timed.truncationReason == "timeout")

let key = Data(repeating: 0x5a, count: 32)
let codec = try AuthenticatedCursorCodec(keyData: key, nowProvider: { now })
let expiry = now.addingTimeInterval(60)
let cursor = try codec.encode(tool: "search_filenames", optionsHash: "opts", rootAuthorityID: "root", generation: 7, position: "pos-42", expiresAt: expiry)
let decodedCursorPosition = try codec.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
precondition(decodedCursorPosition == "pos-42")
expectFailure("tamper", containing: "cursor") {
    _ = try codec.decode(cursor + "x", expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
}
expectFailure("tool binding", containing: "tool mismatch") {
    _ = try codec.decode(cursor, expectedTool: "search_content", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
}
expectFailure("options binding", containing: "options mismatch") {
    _ = try codec.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "other", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
}
expectFailure("root binding", containing: "root mismatch") {
    _ = try codec.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "other", expectedGeneration: 7, now: now)
}
expectFailure("generation binding", containing: "stale") {
    _ = try codec.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 8, now: now)
}
expectFailure("expiry", containing: "expired") {
    _ = try codec.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: expiry)
}
let restarted = try AuthenticatedCursorCodec(keyData: Data(repeating: 0xa5, count: 32), nowProvider: { now })
expectFailure("restart key", containing: "authentication") {
    _ = try restarted.decode(cursor, expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
}
expectFailure("cursor lifetime", containing: "one hour") {
    _ = try AuthenticatedCursorCodec(keyData: key, nowProvider: { now }, maxLifetime: 60 * 60 + 1)
}
expectFailure("cursor expiry upper bound", containing: "within") {
    _ = try codec.encode(tool: "search_filenames", optionsHash: "opts", rootAuthorityID: "root", generation: 7, position: "pos", expiresAt: now.addingTimeInterval(16 * 60))
}
expectFailure("oversized cursor", containing: "malformed") {
    _ = try codec.decode(String(repeating: "a", count: 4097), expectedTool: "search_filenames", expectedOptionsHash: "opts", expectedRootAuthorityID: "root", expectedGeneration: 7, now: now)
}
print("swift-tool-budget-cursor: ok")
SWIFT
swiftc -framework Security -framework CryptoKit -o "$TMP_DIR/tool-budget-cursor-test" macos/ToolExecutionContext.swift macos/AuthenticatedCursorCodec.swift "$TMP_DIR/main.swift"
"$TMP_DIR/tool-budget-cursor-test"

case "$(uname -m)" in
    arm64|aarch64) TUNNEL_TARGET="darwin-arm64" ;;
    x86_64|amd64) TUNNEL_TARGET="darwin-amd64" ;;
    *) echo "unsupported macOS architecture for tunnel-client test" >&2; exit 2 ;;
esac
TUNNEL_BIN="$PWD/vendor/tunnel-client/$TUNNEL_TARGET/tunnel-client"
[ -x "$TUNNEL_BIN" ] || { echo "missing vendored tunnel-client: $TUNNEL_BIN" >&2; exit 2; }
LOCAL_AUTH_PROFILE_DIR="$TMP_DIR/tunnel-profile"
LOCAL_AUTH_PROFILE_TOKEN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
FILEMCP_LOCAL_AUTH_TOKEN="$LOCAL_AUTH_PROFILE_TOKEN" \
MCP_EXTRA_HEADERS="X-FileMCP-Local-Token: env:FILEMCP_LOCAL_AUTH_TOKEN" \
MCP_DISCOVERY_EXTRA_HEADERS="X-FileMCP-Local-Token: env:FILEMCP_LOCAL_AUTH_TOKEN" \
"$TUNNEL_BIN" init \
    --sample sample_mcp_remote_no_auth \
    --profile local-auth-profile \
    --profile-dir "$LOCAL_AUTH_PROFILE_DIR" \
    --force \
    --tunnel-id tunnel_0123456789abcdef0123456789abcdef \
    --mcp-server-url http://127.0.0.1:18088/mcp \
    --health-listen-addr 127.0.0.1:0 >/dev/null
LOCAL_AUTH_PROFILE="$LOCAL_AUTH_PROFILE_DIR/local-auth-profile.yaml"
[ -s "$LOCAL_AUTH_PROFILE" ]
[ "$(stat -f '%Lp' "$LOCAL_AUTH_PROFILE")" = "600" ]
if grep -Fq "$LOCAL_AUTH_PROFILE_TOKEN" "$LOCAL_AUTH_PROFILE" || \
   grep -Eiq 'extra_headers|X-FileMCP-Local-Token|FILEMCP_LOCAL_AUTH_TOKEN' "$LOCAL_AUTH_PROFILE"; then
    echo "tunnel-client init persisted the per-runtime local auth credential" >&2
    exit 1
fi
echo "tunnel-client-local-auth-env: ok"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation
import Darwin

let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-test-child.pid").path
try? FileManager.default.removeItem(atPath: pidFile)
let command = "sh -c 'sleep 20 & echo $! > \(pidFile); wait'"
let timed = try ProcessRunner.run(
    executable: "/bin/sh",
    arguments: ["-lc", command],
    timeoutSeconds: 1
)
precondition(timed.timedOut, "command should time out")
let childText = try String(contentsOfFile: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
let childPID = pid_t(Int(childText) ?? 0)
usleep(200_000)
precondition(childPID <= 0 || kill(childPID, 0) != 0, "timed-out child process survived")
print("process-tree-timeout: ok")

let cancelPIDFile = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-test-cancel-child.pid").path
try? FileManager.default.removeItem(atPath: cancelPIDFile)
let cancelCommand = "sh -c 'sleep 20 & echo $! > \(cancelPIDFile); wait'"
let cancelled = try ProcessRunner.run(
    executable: "/bin/sh",
    arguments: ["-lc", cancelCommand],
    timeoutSeconds: 20,
    shouldCancel: { FileManager.default.fileExists(atPath: cancelPIDFile) }
)
precondition(cancelled.cancelled && !cancelled.timedOut, "cooperative process cancellation state")
let cancelChildText = try String(contentsOfFile: cancelPIDFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
let cancelChildPID = pid_t(Int(cancelChildText) ?? 0)
usleep(200_000)
precondition(cancelChildPID <= 0 || kill(cancelChildPID, 0) != 0, "cancelled child process survived")
print("process-tree-cancellation: ok")

let backgroundPIDFile = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-test-background-child.pid").path
try? FileManager.default.removeItem(atPath: backgroundPIDFile)
let background = try ProcessRunner.run(
    executable: "/bin/sh",
    arguments: ["-lc", "sleep 20 & echo $! > \(backgroundPIDFile)"],
    timeoutSeconds: 5
)
precondition(!background.timedOut && background.exitCode == 0, "background parent should exit normally")
let backgroundPIDText = try String(contentsOfFile: backgroundPIDFile, encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)
let backgroundPID = pid_t(Int(backgroundPIDText) ?? 0)
usleep(300_000)
precondition(backgroundPID <= 0 || kill(backgroundPID, 0) != 0, "background child survived successful parent exit")
print("process-tree-normal-exit-cleanup: ok")

for index in 0..<12 {
    let exited = DispatchSemaphore(value: 0)
    let managed = try ProcessRunner.startManaged(
        executable: "/bin/sh",
        arguments: ["-lc", "printf managed-\(index); sleep 10"],
        onOutput: { _ in },
        onExit: { _ in exited.signal() }
    )
    managed.stopSynchronously()
    precondition(exited.wait(timeout: .now() + 3) == .success, "managed stop did not complete")
}
print("managed-reader-stop-race: ok")

let managedChildPIDFile = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-managed-background-child.pid").path
try? FileManager.default.removeItem(atPath: managedChildPIDFile)
let managedExited = DispatchSemaphore(value: 0)
let managedBackground = try ProcessRunner.startManaged(
    executable: "/bin/sh",
    arguments: ["-lc", "sleep 20 & echo $! > \(managedChildPIDFile)"],
    onOutput: { _ in },
    onExit: { _ in managedExited.signal() }
)
precondition(managedExited.wait(timeout: .now() + 3) == .success, "managed parent exit did not complete")
_ = managedBackground
let managedChildText = try String(contentsOfFile: managedChildPIDFile, encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)
let managedChildPID = pid_t(Int(managedChildText) ?? 0)
usleep(200_000)
precondition(managedChildPID <= 0 || kill(managedChildPID, 0) != 0, "managed background child survived parent exit")
print("managed-process-descendant-cleanup: ok")

do {
    _ = try ProcessRunner.run(
        executable: "/bin/echo",
        arguments: ["safe\0truncated"],
        timeoutSeconds: 1
    )
    preconditionFailure("NUL-containing argv must be rejected")
} catch {
    precondition(error.localizedDescription.contains("NUL byte"), "unexpected NUL argv error: \(error)")
}

do {
    _ = try ProcessRunner.run(
        executable: "/bin/echo",
        arguments: [],
        environment: ["BAD=NAME": "value"],
        timeoutSeconds: 1
    )
    preconditionFailure("invalid environment variable name must be rejected")
} catch {
    precondition(error.localizedDescription.contains("Environment variable name"), "unexpected environment error: \(error)")
}
print("process-posix-string-validation: ok")
SWIFT

swiftc -o "$TMP_DIR/process-test" \
    macos/ProcessRunner.swift \
    "$TMP_DIR/main.swift"

"$TMP_DIR/process-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

let host = [
    "PATH": "/usr/bin:/bin",
    "HOME": "/tmp/home",
    "FMG005_PLAIN": "plain-pass",
    "FMG005_SECRET_TOKEN": "secret-pass",
]
let wildcard = try ExecProcessEnvironmentAuthority(patterns: ["FMG005_*"])
let wildcardEnvironment = try wildcard.build(host: host)
precondition(wildcardEnvironment["FMG005_PLAIN"] == "plain-pass", "wildcard pass-through keeps ordinary host environment")
precondition(wildcardEnvironment["FMG005_SECRET_TOKEN"] == nil, "wildcard pass-through suppresses secret-like host environment")

let exact = try ExecProcessEnvironmentAuthority(patterns: ["FMG005_SECRET_TOKEN", "FMG005_OVERRIDE"])
let exactEnvironment = try exact.build(overrides: ["FMG005_OVERRIDE": "request-value"], host: host)
precondition(exactEnvironment["FMG005_SECRET_TOKEN"] == "secret-pass", "exact allowlist permits secret-like host variable")
precondition(exactEnvironment["FMG005_OVERRIDE"] == "request-value", "exact allowlist permits bounded request override")

do {
    _ = try exact.build(overrides: ["FMG005_FORBIDDEN": "blocked"], host: host)
    preconditionFailure("forbidden environment override must be rejected")
} catch {
    precondition(error.localizedDescription.contains("not locally allowed"), "unexpected forbidden override error: \(error)")
}

do {
    _ = try exact.build(overrides: ["PATH": "/tmp/untrusted"], host: host)
    preconditionFailure("minimal baseline override must require explicit local authority")
} catch {
    precondition(error.localizedDescription.contains("not locally allowed"), "unexpected baseline override error: \(error)")
}

do {
    _ = try ExecProcessEnvironmentAuthority(patterns: ["BAD PATTERN"])
    preconditionFailure("invalid allowlist pattern must be rejected")
} catch {
    precondition(error.localizedDescription.contains("Invalid exec_process environment allowlist pattern"), "unexpected pattern error: \(error)")
}

let manyHost = Dictionary(uniqueKeysWithValues: (0...ExecProcessEnvironmentAuthority.maxForwardedVariables).map { ("FMG005_MANY_\($0)", "x") })
let broad = try ExecProcessEnvironmentAuthority(patterns: ["FMG005_MANY_*"])
do {
    _ = try broad.build(host: manyHost)
    preconditionFailure("wildcard pass-through count bound was not enforced")
} catch {
    precondition(error.localizedDescription.contains("forwarded variables"), "unexpected environment count error: \(error)")
}

print("exec-process-environment-authority: ok")
SWIFT

swiftc -o "$TMP_DIR/exec-env-test"     macos/ExecProcessEnvironmentAuthority.swift     "$TMP_DIR/main.swift"
"$TMP_DIR/exec-env-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

var now = Date(timeIntervalSince1970: 1_000)
var randomSeed: UInt8 = 1
let service = LogicalChatCorrelationService(
    maxKnownHandles: 4,
    retention: 60,
    nowProvider: { now },
    randomBytesProvider: { count in
        let value = randomSeed
        randomSeed &+= 1
        return [UInt8](repeating: value, count: count)
    }
)

let first = try service.connect()
precondition(!first.resumed, "new correlation handle must not be resumed")
precondition(LogicalChatCorrelationService.isValidHandle(first.chatInstanceID), "generated handle format")
precondition(first.chatInstanceID.hasPrefix("chat_"), "generated handle prefix")
precondition(first.chatInstanceID.count == 48, "generated handle total length")

let firstHash = service.tryResolve(first.chatInstanceID)
precondition(firstHash?.count == 64, "known handle resolves to SHA-256 hash")
let persistedHash = try LogicalChatCorrelationService.hashForPersistence(first.chatInstanceID)
precondition(persistedHash == firstHash, "persistence hash parity")

let resumed = try service.connect(chatInstanceID: first.chatInstanceID)
precondition(resumed.resumed && resumed.chatInstanceID == first.chatInstanceID, "known handle resumes")

do {
    _ = try service.connect(chatInstanceID: "bad")
    preconditionFailure("malformed handle must be rejected")
} catch {
    precondition(error.localizedDescription.contains("Invalid FileMCP chat correlation handle"), "unexpected malformed-handle error")
}

let unknown = "chat_" + String(repeating: "A", count: 43)
precondition(LogicalChatCorrelationService.isValidHandle(unknown), "unknown test handle must be syntactically valid")
do {
    _ = try service.connect(chatInstanceID: unknown)
    preconditionFailure("unknown valid handle must be rejected")
} catch {
    precondition(error.localizedDescription.contains("Unknown FileMCP chat correlation handle"), "unexpected unknown-handle error")
}

now = now.addingTimeInterval(61)
precondition(service.tryResolve(first.chatInstanceID) == nil, "expired handle must not resolve")
let expiredSnapshot = service.retentionSnapshot()
precondition(expiredSnapshot.knownHandles == 0, "expired handle must be removed")
precondition(expiredSnapshot.expiredEvictions >= 1, "expiry counter must advance")

var pressureNow = Date(timeIntervalSince1970: 2_000)
var pressureSeed: UInt8 = 20
let pressure = LogicalChatCorrelationService(
    maxKnownHandles: 2,
    retention: 3_600,
    nowProvider: { pressureNow },
    randomBytesProvider: { count in
        let value = pressureSeed
        pressureSeed &+= 1
        return [UInt8](repeating: value, count: count)
    }
)
let p1 = try pressure.connect()
pressureNow = pressureNow.addingTimeInterval(1)
let p2 = try pressure.connect()
pressureNow = pressureNow.addingTimeInterval(1)
_ = try pressure.connect()
let pressureSnapshot = pressure.retentionSnapshot()
precondition(pressureSnapshot.knownHandles == 2, "pressure registry must remain bounded")
precondition(pressureSnapshot.capacityPressureEvents >= 1, "pressure event counter must advance")
precondition(pressureSnapshot.pressureEvictions >= 1, "pressure eviction counter must advance")
precondition(pressure.tryResolve(p1.chatInstanceID) == nil, "oldest handle must be pressure-evicted")
precondition(pressure.tryResolve(p2.chatInstanceID) != nil, "newer handle must remain")

print("logical-chat-correlation: ok")
SWIFT

swiftc -framework Security -o "$TMP_DIR/correlation-test" \
    macos/LogicalChatCorrelation.swift \
    "$TMP_DIR/main.swift"
"$TMP_DIR/correlation-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func approx(_ lhs: TimeInterval, _ rhs: TimeInterval, tolerance: TimeInterval = 0.0001) -> Bool {
    abs(lhs - rhs) <= tolerance
}

let base = Date(timeIntervalSince1970: 10_000)
let options = TunnelSupervisorOptions(
    initialBackoff: 1,
    maxBackoff: 4,
    restartWindow: 10,
    maxRestartsInWindow: 3,
    stableRunReset: 5,
    jitterRatio: 0.20
)
let policy = TunnelRestartPolicy(options: options)
let first = policy.next(processStarted: base, now: base, random: { 0.5 })
precondition(!first.isCooldown && first.attemptNumber == 1 && approx(first.delay, 1), "first backoff")
let second = policy.next(processStarted: base, now: base.addingTimeInterval(1), random: { 0.5 })
precondition(!second.isCooldown && second.attemptNumber == 2 && approx(second.delay, 2), "second backoff")
let third = policy.next(processStarted: base, now: base.addingTimeInterval(2), random: { 0.5 })
precondition(!third.isCooldown && third.attemptNumber == 3 && approx(third.delay, 4), "third backoff")
let cooldown = policy.next(processStarted: base, now: base.addingTimeInterval(3), random: { 0.5 })
precondition(cooldown.isCooldown, "restart budget must enter cooldown")
precondition(approx(cooldown.delay, 7), "cooldown delay must reach oldest-attempt window expiry")
precondition(cooldown.resumeAt == base.addingTimeInterval(10), "cooldown resume time")

let jitterOptions = TunnelSupervisorOptions(
    initialBackoff: 10,
    maxBackoff: 30,
    restartWindow: 100,
    maxRestartsInWindow: 10,
    stableRunReset: 50,
    jitterRatio: 0.20
)
let lowJitter = TunnelRestartPolicy(options: jitterOptions)
precondition(approx(lowJitter.next(processStarted: base, now: base, random: { 0 }).delay, 8), "low jitter bound")
let highJitter = TunnelRestartPolicy(options: jitterOptions)
precondition(approx(highJitter.next(processStarted: base, now: base, random: { 1 }).delay, 12), "high jitter bound")

let clampOptions = TunnelSupervisorOptions(
    initialBackoff: 1,
    maxBackoff: 4,
    restartWindow: 100,
    maxRestartsInWindow: 20,
    stableRunReset: 50,
    jitterRatio: 0
)
let clamp = TunnelRestartPolicy(options: clampOptions)
_ = clamp.next(processStarted: base, now: base, random: { 0.5 })
_ = clamp.next(processStarted: base, now: base.addingTimeInterval(1), random: { 0.5 })
_ = clamp.next(processStarted: base, now: base.addingTimeInterval(2), random: { 0.5 })
let clamped = clamp.next(processStarted: base, now: base.addingTimeInterval(3), random: { 0.5 })
precondition(approx(clamped.delay, 4), "max backoff clamp")

let stable = TunnelRestartPolicy(options: options)
_ = stable.next(processStarted: base, now: base, random: { 0.5 })
_ = stable.next(processStarted: base, now: base.addingTimeInterval(1), random: { 0.5 })
let afterStableRun = stable.next(processStarted: base, now: base.addingTimeInterval(6), random: { 0.5 })
precondition(afterStableRun.attemptNumber == 1 && approx(afterStableRun.delay, 1), "stable run must reset history")
stable.reset()
precondition(stable.consecutiveRestarts == 0 && stable.attemptsInWindow == 0, "explicit reset")

let stressOptions = TunnelSupervisorOptions(
    initialBackoff: 0.001,
    maxBackoff: 0.01,
    restartWindow: 1,
    maxRestartsInWindow: 5,
    stableRunReset: 10_000,
    jitterRatio: 0.20
)
let stress = TunnelRestartPolicy(options: stressOptions)
var stressNow = base
for _ in 0..<10_000 {
    let decision = stress.next(processStarted: stressNow, now: stressNow, random: { 0.5 })
    precondition(stress.attemptsInWindow <= 5, "restart window state must stay bounded")
    if decision.isCooldown {
        stressNow = decision.resumeAt ?? stressNow.addingTimeInterval(decision.delay)
        stress.reset()
    } else {
        stressNow = stressNow.addingTimeInterval(0.0001)
    }
}
print("tunnel-supervisor-policy: ok")
SWIFT

swiftc -o "$TMP_DIR/supervisor-test" \
    macos/TunnelSupervisor.swift \
    "$TMP_DIR/main.swift"
"$TMP_DIR/supervisor-test"

cat >"$TMP_DIR/tunnel-client" <<'SH'
#!/bin/sh
profile_dir=
previous=
for argument in "$@"; do
    if [ "$previous" = "--profile-dir" ]; then profile_dir="$argument"; fi
    previous="$argument"
done
if [ -n "${MCP_TEST_PROFILE_DIR_EXPECTED:-}" ] && [ "$profile_dir" != "$MCP_TEST_PROFILE_DIR_EXPECTED" ]; then
    echo "unexpected profile directory: $profile_dir" >&2
    exit 3
fi
if [ -n "${MCP_TEST_ENV_CAPTURE:-}" ]; then
    case "${NO_PROXY:-}" in
        *127.0.0.1*localhost*::1*|*127.0.0.1*::1*localhost*|*localhost*127.0.0.1*::1*|*localhost*::1*127.0.0.1*|*::1*127.0.0.1*localhost*|*::1*localhost*127.0.0.1*) ;;
        *) echo missing-loopback-no-proxy >&2; exit 3 ;;
    esac
    [ -z "${MCP_SERVER_URL:-}" ] || { echo inherited-mcp-server-url >&2; exit 3; }
    [ -z "${HEALTH_UNIX_SOCKET:-}" ] || { echo inherited-health-unix-socket >&2; exit 3; }
    [ -z "${LOG_HTTP_RAW_UNSAFE:-}" ] || { echo inherited-raw-http-logging >&2; exit 3; }
fi
if [ -n "${MCP_TEST_ENV_CAPTURE:-}" ]; then
    {
        printf '%s\n' "${MCP_EXTRA_HEADERS:-}"
        printf '%s\n' "${MCP_DISCOVERY_EXTRA_HEADERS:-}"
    } > "$MCP_TEST_ENV_CAPTURE"
fi
case "$1" in
    init)
        [ "${MCP_EXTRA_HEADERS:-}" = "X-FileMCP-Local-Token: env:FILEMCP_LOCAL_AUTH_TOKEN" ] || { echo bad-mcp-extra-headers >&2; exit 3; }
        [ "${MCP_DISCOVERY_EXTRA_HEADERS:-}" = "X-FileMCP-Local-Token: env:FILEMCP_LOCAL_AUTH_TOKEN" ] || { echo bad-discovery-extra-headers >&2; exit 3; }
        case "${FILEMCP_LOCAL_AUTH_TOKEN:-}" in
            ''|*[!0-9a-f]*) echo invalid-local-auth-token >&2; exit 3 ;;
        esac
        [ "${#FILEMCP_LOCAL_AUTH_TOKEN}" -eq 64 ] || { echo bad-local-auth-token-length >&2; exit 3; }
        if [ "${MCP_TEST_SLOW_INIT:-0}" = "1" ]; then sleep 10; fi
        echo "init-ok ${CONTROL_PLANE_API_KEY:-} ${FILEMCP_LOCAL_AUTH_TOKEN:-}"
        exit 0
        ;;
    doctor) echo "doctor-ok ${CONTROL_PLANE_API_KEY:-} ${FILEMCP_LOCAL_AUTH_TOKEN:-}"; exit 0 ;;
    run)
        if [ -n "${MCP_TEST_RUN_COUNT_FILE:-}" ]; then printf 'run\n' >> "$MCP_TEST_RUN_COUNT_FILE"; fi
        if [ -n "${MCP_TEST_RUN_EXIT_ONCE_MARKER:-}" ] && [ ! -e "$MCP_TEST_RUN_EXIT_ONCE_MARKER" ]; then
            : > "$MCP_TEST_RUN_EXIT_ONCE_MARKER"
            echo "run-crash-once"
            exit "${MCP_TEST_RUN_EXIT_CODE:-17}"
        fi
        if [ "${MCP_TEST_RUN_ALWAYS_EXIT:-0}" = "1" ]; then
            echo "run-crash"
            exit "${MCP_TEST_RUN_EXIT_CODE:-17}"
        fi
        echo "run-ok ${CONTROL_PLANE_API_KEY:-} ${FILEMCP_LOCAL_AUTH_TOKEN:-}"
        trap 'exit 0' TERM INT
        while :; do sleep 1; done
        ;;
    *) echo unsupported-subcommand >&2; exit 2 ;;
esac
SH
chmod +x "$TMP_DIR/tunnel-client"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func waitFor(_ predicate: () -> Bool, timeout: TimeInterval, label: String) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if predicate() { return }
        Thread.sleep(forTimeInterval: 0.05)
    }
    fatalError("timed out waiting for \(label)")
}

func isFailed(_ state: LocalMCPRuntimeState) -> Bool {
    if case .failed = state { return true }
    return false
}

let root = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-runtime-test-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let profile = "runtime-test-\(UUID().uuidString)"
let profileDirectory = root.appendingPathComponent("tunnel-profiles", isDirectory: true)
let authCapture = root.appendingPathComponent("local-auth-headers.txt")
setenv("MCP_TEST_ENV_CAPTURE", authCapture.path, 1)
setenv("MCP_TEST_PROFILE_DIR_EXPECTED", profileDirectory.path, 1)
setenv("MCP_SERVER_URL", "https://evil.example/mcp", 1)
setenv("HEALTH_UNIX_SOCKET", "/tmp/evil-health.sock", 1)
setenv("LOG_HTTP_RAW_UNSAFE", "true", 1)
let first = LocalMCPRuntime(profileDirectory: profileDirectory)
let second = LocalMCPRuntime(profileDirectory: profileDirectory)
let logLock = NSLock()
var capturedRuntimeLog = ""
first.onLog = { text in
    logLock.lock()
    capturedRuntimeLog += text
    logLock.unlock()
}
let firstConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: profile, port: 18086,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
let secondConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: profile, port: 18087,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)

first.start(firstConfig)
waitFor({ first.state == .running }, timeout: 5, label: "first runtime")
let authLines = try String(contentsOf: authCapture, encoding: .utf8)
    .split(whereSeparator: { $0.isNewline })
    .map(String.init)
precondition(authLines.count == 2, "tunnel-client did not receive both local auth header settings")
let expectedLocalAuthHeader = "\(fileMCPLocalAuthHeaderName): env:FILEMCP_LOCAL_AUTH_TOKEN"
precondition(authLines[0] == expectedLocalAuthHeader, "unexpected runtime local auth header reference")
precondition(authLines[1] == expectedLocalAuthHeader, "unexpected discovery local auth header reference")
Thread.sleep(forTimeInterval: 0.2)
logLock.lock()
let safeRuntimeLog = capturedRuntimeLog
logLock.unlock()
precondition(!safeRuntimeLog.contains("test-key"), "runtime log leaked the control-plane API key")
precondition(safeRuntimeLog.range(of: "[0-9a-f]{64}", options: .regularExpression) == nil, "runtime log leaked the local auth token")
precondition(safeRuntimeLog.contains("[REDACTED]"), "runtime log did not exercise secret redaction")
unsetenv("MCP_TEST_ENV_CAPTURE")
second.start(secondConfig)
waitFor({ isFailed(second.state) }, timeout: 5, label: "profile lock failure")
first.stop()
waitFor({ first.state == .stopped }, timeout: 5, label: "first stop")
second.start(secondConfig)
waitFor({ second.state == .running }, timeout: 5, label: "second recovery")
second.stop()
waitFor({ second.state == .stopped }, timeout: 5, label: "second stop")
first.start(firstConfig)
waitFor({ first.state == .running }, timeout: 5, label: "first restart")
first.shutdownImmediately()
waitFor({ first.state == .stopped }, timeout: 5, label: "shutdown")
print("runtime-lifecycle-profile-lock: ok")

func runLaunchCount(_ url: URL) -> Int {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
    return text.split(whereSeparator: { $0.isNewline }).count
}

let supervisorOptions = TunnelSupervisorOptions(
    initialBackoff: 0.8,
    maxBackoff: 0.8,
    restartWindow: 5,
    maxRestartsInWindow: 3,
    stableRunReset: 3,
    jitterRatio: 0
)

let crashOnceMarker = root.appendingPathComponent("crash-once.marker")
let restartCountFile = root.appendingPathComponent("restart-count.txt")
setenv("MCP_TEST_RUN_EXIT_ONCE_MARKER", crashOnceMarker.path, 1)
setenv("MCP_TEST_RUN_COUNT_FILE", restartCountFile.path, 1)
setenv("MCP_TEST_RUN_EXIT_CODE", "17", 1)
let restartProfile = "restart-runtime-\(UUID().uuidString)"
let restartRuntime = LocalMCPRuntime(
    profileDirectory: profileDirectory,
    supervisorOptions: supervisorOptions,
    jitterProvider: { 0.5 }
)
let restartLogLock = NSLock()
var restartLog = ""
restartRuntime.onLog = { text in
    restartLogLock.lock()
    restartLog += text
    restartLogLock.unlock()
}
let restartConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: restartProfile, port: 18082,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
restartRuntime.start(restartConfig)
waitFor({ FileManager.default.fileExists(atPath: crashOnceMarker.path) }, timeout: 5, label: "first tunnel crash")
waitFor({
    if case .restarting = restartRuntime.state { return true }
    return false
}, timeout: 5, label: "restart pending")

let lockContender = LocalMCPRuntime(profileDirectory: profileDirectory)
let contenderConfig = LocalMCPConfiguration(
    tunnelID: restartConfig.tunnelID, apiKey: restartConfig.apiKey, profile: restartProfile, port: 18081,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
lockContender.start(contenderConfig)
waitFor({ isFailed(lockContender.state) }, timeout: 3, label: "profile lock retained during restart")
lockContender.shutdownImmediately()

waitFor({ restartRuntime.state == .running && runLaunchCount(restartCountFile) >= 2 }, timeout: 5, label: "automatic tunnel restart")
restartLogLock.lock()
let restartLogSnapshot = restartLog
restartLogLock.unlock()
precondition(restartLogSnapshot.contains("Tunnel restart succeeded."), "runtime did not report successful restart")
precondition(runLaunchCount(restartCountFile) == 2, "crash-once runtime should launch tunnel exactly twice")
unsetenv("MCP_TEST_RUN_EXIT_ONCE_MARKER")
unsetenv("MCP_TEST_RUN_COUNT_FILE")
unsetenv("MCP_TEST_RUN_EXIT_CODE")
restartRuntime.stop()
waitFor({ restartRuntime.state == .stopped }, timeout: 5, label: "restarted runtime stop")
print("runtime-tunnel-auto-restart: ok")

let cancelCountFile = root.appendingPathComponent("cancel-restart-count.txt")
setenv("MCP_TEST_RUN_ALWAYS_EXIT", "1", 1)
setenv("MCP_TEST_RUN_COUNT_FILE", cancelCountFile.path, 1)
setenv("MCP_TEST_RUN_EXIT_CODE", "19", 1)
let cancelRuntime = LocalMCPRuntime(
    profileDirectory: profileDirectory,
    supervisorOptions: supervisorOptions,
    jitterProvider: { 0.5 }
)
let cancelConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: "cancel-runtime-\(UUID().uuidString)", port: 18080,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
cancelRuntime.start(cancelConfig)
waitFor({ runLaunchCount(cancelCountFile) >= 1 }, timeout: 5, label: "cancel test first launch")
waitFor({
    if case .restarting = cancelRuntime.state { return true }
    return false
}, timeout: 5, label: "cancel test restart pending")
cancelRuntime.stop()
waitFor({ cancelRuntime.state == .stopped }, timeout: 5, label: "cancel test stopped")
let launchCountAtStop = runLaunchCount(cancelCountFile)
Thread.sleep(forTimeInterval: 1.2)
precondition(runLaunchCount(cancelCountFile) == launchCountAtStop, "tunnel relaunched after user stop canceled pending restart")
unsetenv("MCP_TEST_RUN_ALWAYS_EXIT")
unsetenv("MCP_TEST_RUN_COUNT_FILE")
unsetenv("MCP_TEST_RUN_EXIT_CODE")
print("runtime-tunnel-restart-cancel: ok")

let cooldownCountFile = root.appendingPathComponent("cooldown-restart-count.txt")
setenv("MCP_TEST_RUN_ALWAYS_EXIT", "1", 1)
setenv("MCP_TEST_RUN_COUNT_FILE", cooldownCountFile.path, 1)
setenv("MCP_TEST_RUN_EXIT_CODE", "23", 1)
let cooldownOptions = TunnelSupervisorOptions(
    initialBackoff: 0.05,
    maxBackoff: 0.05,
    restartWindow: 30,
    maxRestartsInWindow: 1,
    stableRunReset: 60,
    jitterRatio: 0
)
let cooldownRuntime = LocalMCPRuntime(
    profileDirectory: profileDirectory,
    supervisorOptions: cooldownOptions,
    jitterProvider: { 0.5 }
)
let cooldownLogLock = NSLock()
var cooldownLog = ""
cooldownRuntime.onLog = { text in
    cooldownLogLock.lock()
    cooldownLog += text
    cooldownLogLock.unlock()
}
let cooldownConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key",
    profile: "cooldown-runtime-test", port: 18079,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
cooldownRuntime.start(cooldownConfig)
let cooldownDeadline = Date().addingTimeInterval(8)
var observedCooldown = false
while Date() < cooldownDeadline {
    if case .cooldown = cooldownRuntime.state {
        observedCooldown = true
        break
    }
    Thread.sleep(forTimeInterval: 0.05)
}
if !observedCooldown {
    cooldownLogLock.lock()
    let cooldownLogSnapshot = cooldownLog
    cooldownLogLock.unlock()
    fatalError("timed out waiting for restart budget cooldown; state=\(cooldownRuntime.state); launches=\(runLaunchCount(cooldownCountFile)); log=\(cooldownLogSnapshot)")
}
precondition(runLaunchCount(cooldownCountFile) == 2, "cooldown should occur after initial launch plus one bounded restart attempt")
cooldownRuntime.stop()
waitFor({ cooldownRuntime.state == .stopped }, timeout: 5, label: "cooldown stop")
let cooldownLaunchCountAtStop = runLaunchCount(cooldownCountFile)
Thread.sleep(forTimeInterval: 0.3)
precondition(runLaunchCount(cooldownCountFile) == cooldownLaunchCountAtStop, "cooldown stop must cancel pending recovery")
unsetenv("MCP_TEST_RUN_ALWAYS_EXIT")
unsetenv("MCP_TEST_RUN_COUNT_FILE")
unsetenv("MCP_TEST_RUN_EXIT_CODE")
print("runtime-tunnel-restart-cooldown: ok")

let invalidHealthRuntime = LocalMCPRuntime(profileDirectory: profileDirectory)
let invalidHealthConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: "invalid-health-\(UUID().uuidString)", port: 18083,
    allowedDirectory: root.path, healthAddress: "0.0.0.0:8080",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
invalidHealthRuntime.start(invalidHealthConfig)
waitFor({ isFailed(invalidHealthRuntime.state) }, timeout: 2, label: "non-loopback health address rejection")
if case let .failed(message) = invalidHealthRuntime.state {
    precondition(message.contains("Health listener must use localhost"), "unexpected health validation error: \(message)")
}
print("runtime-health-loopback-policy: ok")

let invalidTunnelRuntime = LocalMCPRuntime(profileDirectory: profileDirectory)
let invalidTunnelConfig = LocalMCPConfiguration(
    tunnelID: "tunnel-test", apiKey: "test-key", profile: "invalid-tunnel", port: 18082,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
invalidTunnelRuntime.start(invalidTunnelConfig)
waitFor({ isFailed(invalidTunnelRuntime.state) }, timeout: 2, label: "invalid tunnel ID rejection")
if case let .failed(message) = invalidTunnelRuntime.state {
    precondition(message.contains("Tunnel ID must match"), "unexpected tunnel ID validation error: \(message)")
}

let invalidProfileRuntime = LocalMCPRuntime(profileDirectory: profileDirectory)
let invalidProfileConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: "../escape", port: 18081,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
invalidProfileRuntime.start(invalidProfileConfig)
waitFor({ isFailed(invalidProfileRuntime.state) }, timeout: 2, label: "invalid profile rejection")
if case let .failed(message) = invalidProfileRuntime.state {
    precondition(message.contains("Profile must start"), "unexpected profile validation error: \(message)")
}
print("runtime-tunnel-profile-validation: ok")

setenv("MCP_TEST_SLOW_INIT", "1", 1)
let immediateStopRuntime = LocalMCPRuntime(profileDirectory: profileDirectory)
let immediateStopConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: "immediate-\(UUID().uuidString)", port: 18084,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
immediateStopRuntime.start(immediateStopConfig)
immediateStopRuntime.stop()
Thread.sleep(forTimeInterval: 0.5)
precondition(immediateStopRuntime.state == .stopped, "immediate stop after start must cancel the queued startup")
print("runtime-immediate-stop: ok")

let slowRuntime = LocalMCPRuntime(profileDirectory: profileDirectory)
let slowConfig = LocalMCPConfiguration(
    tunnelID: "tunnel_0123456789abcdef0123456789abcdef", apiKey: "test-key", profile: "slow-\(UUID().uuidString)", port: 18085,
    allowedDirectory: root.path, healthAddress: "127.0.0.1:0",
    gitUserName: "", gitUserEmail: "", enableCommands: false
)
slowRuntime.start(slowConfig)
waitFor({ slowRuntime.state == .starting }, timeout: 2, label: "slow runtime starting")
Thread.sleep(forTimeInterval: 0.2)
let shutdownStart = Date()
slowRuntime.shutdownImmediately()
let shutdownElapsed = Date().timeIntervalSince(shutdownStart)
unsetenv("MCP_TEST_SLOW_INIT")
unsetenv("MCP_TEST_PROFILE_DIR_EXPECTED")
unsetenv("MCP_SERVER_URL")
unsetenv("HEALTH_UNIX_SOCKET")
unsetenv("LOG_HTTP_RAW_UNSAFE")
precondition(slowRuntime.state == .stopped, "cancelled bootstrap must end stopped")
precondition(shutdownElapsed < 2.5, "bootstrap shutdown took too long: \(shutdownElapsed)s")
print("runtime-bootstrap-cancel: ok")
SWIFT

swiftc -framework Network -framework Security -o "$TMP_DIR/runtime-test" \
    macos/ProcessRunner.swift \
    macos/ExecProcessEnvironmentAuthority.swift \
    macos/LogicalChatCorrelation.swift \
    macos/ToolCatalog.swift \
    macos/ServerPolicy.swift \
    macos/ToolResultEnvelope.swift \
    macos/ToolExecutionContext.swift \
    macos/AuthenticatedCursorCodec.swift \
    macos/FileVersionService.swift \
    macos/AuthorizedPathSnapshot.swift \
    macos/LocalMCPServer.swift \
    macos/TunnelSupervisor.swift \
    macos/LocalMCPRuntime.swift \
    "$TMP_DIR/main.swift"
"$TMP_DIR/runtime-test"

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

let root = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-server-test")
try? FileManager.default.removeItem(at: root)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: root.appendingPathComponent("exec-work"), withIntermediateDirectories: true)
try "hello swift".write(to: root.appendingPathComponent("hello.txt"), atomically: true, encoding: .utf8)
try """
import Foundation

func alpha() {
    print("needle-target")
}

func beta() {
    alpha()
}
""".write(to: root.appendingPathComponent("sample.swift"), atomically: true, encoding: .utf8)
let crlfText = [
    "line-one",
    "line-two",
    "needle-crlf",
    "line-four",
].joined(separator: "\r\n")
try crlfText.write(to: root.appendingPathComponent("crlf.txt"), atomically: true, encoding: .utf8)
let binaryDirectory = root.appendingPathComponent("binary-only")
try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
var binaryData = Data(repeating: 65, count: 1_024)
binaryData[0] = 0
try binaryData.write(to: binaryDirectory.appendingPathComponent("blob.bin"))
try "first\nsecond\n".write(to: root.appendingPathComponent("trailing-newline.txt"), atomically: true, encoding: .utf8)
try String(repeating: "x", count: 80_001).write(to: root.appendingPathComponent("long-line.txt"), atomically: true, encoding: .utf8)
let manyLinesText = (1...1200).map { index in
    String(format: "SHORT-%04d", index)
}.joined(separator: "\n")
try manyLinesText.write(to: root.appendingPathComponent("many-lines.txt"), atomically: true, encoding: .utf8)
let largeRangeText = (1...1000).map { index in
    String(format: "LINE-%04d ", index) + String(repeating: "x", count: 190)
}.joined(separator: "\n")
try largeRangeText.write(to: root.appendingPathComponent("large-range.txt"), atomically: true, encoding: .utf8)
let listLimitDirectory = root.appendingPathComponent("list-limit")
try FileManager.default.createDirectory(at: listLimitDirectory, withIntermediateDirectories: true)
for index in 1...1001 {
    FileManager.default.createFile(
        atPath: listLimitDirectory.appendingPathComponent(String(format: "entry-%04d.txt", index)).path,
        contents: Data()
    )
}
let filenameLimitDirectory = root.appendingPathComponent("filename-limit")
try FileManager.default.createDirectory(at: filenameLimitDirectory, withIntermediateDirectories: true)
for index in 1...205 {
    FileManager.default.createFile(
        atPath: filenameLimitDirectory.appendingPathComponent(String(format: "filename-target-%03d.txt", index)).path,
        contents: Data()
    )
}
let outside = FileManager.default.temporaryDirectory.appendingPathComponent("filemcp-server-outside")
try? FileManager.default.removeItem(at: outside)
try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
try "must stay private".write(to: outside.appendingPathComponent("secret.txt"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"), withDestinationURL: outside)
try "keep target".write(to: root.appendingPathComponent("delete-target.txt"), atomically: true, encoding: .utf8)
let deleteTargetDirectory = root.appendingPathComponent("delete-target-dir")
try FileManager.default.createDirectory(at: deleteTargetDirectory, withIntermediateDirectories: true)
try "keep nested".write(to: deleteTargetDirectory.appendingPathComponent("nested.txt"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(
    at: root.appendingPathComponent("delete-file-link"),
    withDestinationURL: root.appendingPathComponent("delete-target.txt")
)
try FileManager.default.createSymbolicLink(
    at: root.appendingPathComponent("delete-dir-link"),
    withDestinationURL: deleteTargetDirectory
)
try FileManager.default.createSymbolicLink(
    at: root.appendingPathComponent("delete-outside-link"),
    withDestinationURL: outside.appendingPathComponent("secret.txt")
)

func runGitFixture(_ repo: URL, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["-C", repo.path] + arguments
    let stderr = Pipe()
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let data = stderr.fileHandleForReading.readDataToEndOfFile()
        throw NSError(domain: "FMG006GitFixture", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
    }
}

let versionResolver = try SafePathResolver(rootPath: root.path)
let versionService = try FileVersionService(resolver: versionResolver, keyData: Data(repeating: 0x5A, count: 32))
let sameURL = root.appendingPathComponent("fmg006-same.txt")
try "AAAA".write(to: sameURL, atomically: true, encoding: .utf8)
let sameModified = try FileManager.default.attributesOfItem(atPath: sameURL.path)[.modificationDate] as! Date
let sameVersion = try versionService.readVersioned(relativePath: "fmg006-same.txt", maxBytes: 5_000_000)
let sameRepeat = try versionService.readVersioned(relativePath: "fmg006-same.txt", maxBytes: 5_000_000)
precondition(sameVersion.versionToken == sameRepeat.versionToken && sameVersion.versionFingerprint == sameRepeat.versionFingerprint)
try "BBBB".write(to: sameURL, atomically: false, encoding: .utf8)
try FileManager.default.setAttributes([.modificationDate: sameModified], ofItemAtPath: sameURL.path)
do {
    _ = try versionService.verifyExpectedVersion(relativePath: "fmg006-same.txt", token: sameVersion.versionToken, maxBytes: 5_000_000)
    preconditionFailure("same-size same-mtime content change must stale the strong version")
} catch {
    precondition(error.localizedDescription.lowercased().contains("changed"), "unexpected same-size version error: \(error)")
}

let replaceURL = root.appendingPathComponent("fmg006-replace.txt")
try "same-content".write(to: replaceURL, atomically: true, encoding: .utf8)
let replaceModified = try FileManager.default.attributesOfItem(atPath: replaceURL.path)[.modificationDate] as! Date
let replaceVersion = try versionService.readVersioned(relativePath: "fmg006-replace.txt", maxBytes: 5_000_000)
let replaceNewURL = root.appendingPathComponent("fmg006-replace-new.txt")
try "same-content".write(to: replaceNewURL, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.modificationDate: replaceModified], ofItemAtPath: replaceNewURL.path)
try FileManager.default.removeItem(at: replaceURL)
try FileManager.default.moveItem(at: replaceNewURL, to: replaceURL)
do {
    _ = try versionService.verifyExpectedVersion(relativePath: "fmg006-replace.txt", token: replaceVersion.versionToken, maxBytes: 5_000_000)
    preconditionFailure("replacement object must stale the strong version")
} catch {
    precondition(error.localizedDescription.lowercased().contains("replaced"), "unexpected replacement version error: \(error)")
}

let tokenURL = root.appendingPathComponent("fmg006-token.txt")
let otherURL = root.appendingPathComponent("fmg006-other.txt")
try "token-state".write(to: tokenURL, atomically: true, encoding: .utf8)
try "token-state".write(to: otherURL, atomically: true, encoding: .utf8)
let tokenVersion = try versionService.readVersioned(relativePath: "fmg006-token.txt", maxBytes: 5_000_000)
var tokenParts = tokenVersion.versionToken.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
precondition(tokenParts.count == 3 && !tokenParts[2].isEmpty)
let firstSignatureCharacter = tokenParts[2].first!
tokenParts[2] = String(firstSignatureCharacter == "A" ? "B" : "A") + tokenParts[2].dropFirst()
let tamperedToken = tokenParts.joined(separator: ":")
do {
    _ = try versionService.verifyExpectedVersion(relativePath: "fmg006-token.txt", token: tamperedToken, maxBytes: 5_000_000)
    preconditionFailure("tampered file version token must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("authentication"), "unexpected token authentication error: \(error)")
}
do {
    _ = try versionService.verifyExpectedVersion(relativePath: "fmg006-other.txt", token: tokenVersion.versionToken, maxBytes: 5_000_000)
    preconditionFailure("file version token path replay must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("different path"), "unexpected path replay error: \(error)")
}

let sourceRepo = root.appendingPathComponent("source-state-repo")
try FileManager.default.createDirectory(at: sourceRepo, withIntermediateDirectories: true)
try runGitFixture(sourceRepo, ["init", "-b", "main", "--template="])
try "alpha\n".write(to: sourceRepo.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
try "bravo\n".write(to: sourceRepo.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
try runGitFixture(sourceRepo, ["add", "."])
try runGitFixture(sourceRepo, ["-c", "user.name=FileMCP Test", "-c", "user.email=filemcp@example.invalid", "commit", "-m", "source-state baseline"])

let mutationGuardRoot = root.appendingPathComponent("mutation-guard")
try FileManager.default.createDirectory(at: mutationGuardRoot.appendingPathComponent("stable"), withIntermediateDirectories: true)
try "stable\n".write(to: mutationGuardRoot.appendingPathComponent("stable/file.txt"), atomically: true, encoding: .utf8)
let mutationResolver = try SafePathResolver(rootPath: mutationGuardRoot.path)
let mutationGuard = AuthorizedPathSnapshotService(resolver: mutationResolver)
let stableMutationSnapshot = try mutationGuard.captureExisting(relativePath: "stable/file.txt")
let stableMutationURL = try mutationGuard.verify(stableMutationSnapshot)
precondition(stableMutationURL.path == mutationGuardRoot.appendingPathComponent("stable/file.txt").path)
precondition(stableMutationSnapshot.ancestors.count >= 2 && stableMutationSnapshot.targetIdentity != nil && !stableMutationSnapshot.expectedLeafAbsent)

let targetReplaceParent = mutationGuardRoot.appendingPathComponent("target-replace")
try FileManager.default.createDirectory(at: targetReplaceParent, withIntermediateDirectories: true)
let targetReplaceURL = targetReplaceParent.appendingPathComponent("file.txt")
try "same-content\n".write(to: targetReplaceURL, atomically: true, encoding: .utf8)
let targetReplaceSnapshot = try mutationGuard.captureExisting(relativePath: "target-replace/file.txt")
try FileManager.default.removeItem(at: targetReplaceURL)
try "same-content\n".write(to: targetReplaceURL, atomically: true, encoding: .utf8)
do {
    _ = try mutationGuard.verify(targetReplaceSnapshot)
    preconditionFailure("Mutation Guard target replacement must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("target identity changed"), "unexpected target replacement error: \(error)")
}

let parentReplaceURL = mutationGuardRoot.appendingPathComponent("parent-replace")
try FileManager.default.createDirectory(at: parentReplaceURL, withIntermediateDirectories: true)
try "child\n".write(to: parentReplaceURL.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)
let parentReplaceSnapshot = try mutationGuard.captureExisting(relativePath: "parent-replace/child.txt")
let parentReplaceOld = mutationGuardRoot.appendingPathComponent("parent-replace-old")
try FileManager.default.moveItem(at: parentReplaceURL, to: parentReplaceOld)
try FileManager.default.createDirectory(at: parentReplaceURL, withIntermediateDirectories: true)
try "child\n".write(to: parentReplaceURL.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)
do {
    _ = try mutationGuard.verify(parentReplaceSnapshot)
    preconditionFailure("Mutation Guard parent replacement must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("ancestor identity changed"), "unexpected parent replacement error: \(error)")
}

let newTargetParent = mutationGuardRoot.appendingPathComponent("new-target")
try FileManager.default.createDirectory(at: newTargetParent, withIntermediateDirectories: true)
let newTargetSnapshot = try mutationGuard.captureNewTarget(relativePath: "new-target/created.txt")
precondition(newTargetSnapshot.expectedLeafAbsent && newTargetSnapshot.targetIdentity == nil)
try "inserted\n".write(to: newTargetParent.appendingPathComponent("created.txt"), atomically: true, encoding: .utf8)
do {
    _ = try mutationGuard.verify(newTargetSnapshot)
    preconditionFailure("Mutation Guard inserted leaf must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("expected target leaf absence"), "unexpected inserted leaf error: \(error)")
}
do {
    _ = try mutationGuard.captureNewTarget(relativePath: "missing-parent/created.txt")
    preconditionFailure("Mutation Guard missing parent must fail closed")
} catch {
    precondition(error.localizedDescription.lowercased().contains("disappeared"), "unexpected missing parent error: \(error)")
}

let symlinkParent = mutationGuardRoot.appendingPathComponent("symlink-parent")
try FileManager.default.createDirectory(at: symlinkParent, withIntermediateDirectories: true)
try "symlink\n".write(to: symlinkParent.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)
let symlinkSnapshot = try mutationGuard.captureExisting(relativePath: "symlink-parent/child.txt")
let symlinkReal = mutationGuardRoot.appendingPathComponent("symlink-parent-real")
try FileManager.default.moveItem(at: symlinkParent, to: symlinkReal)
try FileManager.default.createSymbolicLink(at: symlinkParent, withDestinationURL: symlinkReal)
do {
    _ = try mutationGuard.verify(symlinkSnapshot)
    preconditionFailure("Mutation Guard ancestor symlink swap must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("symlink"), "unexpected symlink swap error: \(error)")
}
try FileManager.default.removeItem(at: symlinkParent)

let guardRootSwap = root.appendingPathComponent("mutation-guard-root-swap")
try FileManager.default.createDirectory(at: guardRootSwap.appendingPathComponent("parent"), withIntermediateDirectories: true)
try "root\n".write(to: guardRootSwap.appendingPathComponent("parent/file.txt"), atomically: true, encoding: .utf8)
let rootSwapResolver = try SafePathResolver(rootPath: guardRootSwap.path)
let rootSwapGuard = AuthorizedPathSnapshotService(resolver: rootSwapResolver)
let rootSwapSnapshot = try rootSwapGuard.captureExisting(relativePath: "parent/file.txt")
let guardRootSwapOld = root.appendingPathComponent("mutation-guard-root-swap-old")
try FileManager.default.moveItem(at: guardRootSwap, to: guardRootSwapOld)
try FileManager.default.createDirectory(at: guardRootSwap.appendingPathComponent("parent"), withIntermediateDirectories: true)
try "root\n".write(to: guardRootSwap.appendingPathComponent("parent/file.txt"), atomically: true, encoding: .utf8)
do {
    _ = try rootSwapGuard.verify(rootSwapSnapshot)
    preconditionFailure("Mutation Guard root authority replacement must fail")
} catch {
    precondition(error.localizedDescription.lowercased().contains("ancestor identity changed"), "unexpected root replacement error: \(error)")
}
print("swift-mutation-guard: ok")

let localAuthToken = String(repeating: "a", count: 64)

do {
    let invalidPortServer = try LocalMCPServer(
        port: 0, allowedDirectory: root.path, gitUserName: "", gitUserEmail: "",
        enableCommands: false, localAuthToken: localAuthToken, log: { _ in }
    )
    try invalidPortServer.start()
    preconditionFailure("port 0 must be rejected")
} catch {
    // Expected: the tunnel needs a stable non-zero local port.
}

let safeGitServer = try LocalMCPServer(
    port: 18089,
    allowedDirectory: root.path,
    gitUserName: "Test User",
    gitUserEmail: "test@example.com",
    enableCommands: false,
    localAuthToken: localAuthToken,
    log: { _ in }
)
let repositorySourceBaseline = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo")
let narrowSourceBaseline = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["a.txt"])
precondition(repositorySourceBaseline["provider_version"] as? String == "source-state-v1")
precondition(narrowSourceBaseline["scope"] as? String == "relevant_files")
precondition(narrowSourceBaseline["head_oid"] is NSNull)
let narrowJSON = String(decoding: try JSONSerialization.data(withJSONObject: narrowSourceBaseline, options: [.sortedKeys]), as: UTF8.self)
precondition(!narrowJSON.contains("alpha") && !narrowJSON.contains("a.txt"), "SourceStateRef must persist no raw source content/path")

try "BRAVO\n".write(to: sourceRepo.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
let narrowAfterUnrelatedTracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["a.txt"])
let repositoryAfterTracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo")
precondition(narrowAfterUnrelatedTracked["source_state_id"] as? String == narrowSourceBaseline["source_state_id"] as? String)
precondition(repositoryAfterTracked["source_state_id"] as? String != repositorySourceBaseline["source_state_id"] as? String)

try "ALPHA\n".write(to: sourceRepo.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
let narrowAfterRelevantTracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["a.txt"])
precondition(narrowAfterRelevantTracked["source_state_id"] as? String != narrowSourceBaseline["source_state_id"] as? String)

let missingRelevant = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["u.txt"])
try "untracked relevant\n".write(to: sourceRepo.appendingPathComponent("u.txt"), atomically: true, encoding: .utf8)
let relevantUntracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["u.txt"])
precondition(relevantUntracked["source_state_id"] as? String != missingRelevant["source_state_id"] as? String)

let narrowBeforeUnrelatedUntracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["a.txt"])
try "unrelated untracked\n".write(to: sourceRepo.appendingPathComponent("unrelated.txt"), atomically: true, encoding: .utf8)
let narrowAfterUnrelatedUntracked = try safeGitServer.captureSourceStateRefForTest(repoPath: "source-state-repo", relevantPaths: ["a.txt"])
precondition(narrowAfterUnrelatedUntracked["source_state_id"] as? String == narrowBeforeUnrelatedUntracked["source_state_id"] as? String)
print("swift-file-version-source-state: ok")

let server = try LocalMCPServer(
    port: 18088,
    allowedDirectory: root.path,
    gitUserName: "Test User",
    gitUserEmail: "test@example.com",
    enableCommands: true,
    localAuthToken: localAuthToken,
    log: { _ in },
    execEnvironmentAllowList: ["FMG005_OVERRIDE"]
)
let boundedServer = try LocalMCPServer(
    port: 18090,
    allowedDirectory: root.path,
    gitUserName: "Test User",
    gitUserEmail: "test@example.com",
    enableCommands: false,
    localAuthToken: localAuthToken,
    log: { _ in },
    limits: LocalMCPServerLimits(
        maxConcurrentConnections: 2,
        readIdleTimeout: 0.5,
        headerReadTimeout: 1.0
    )
)
try safeGitServer.start()
try server.start()
try boundedServer.start()
// The shell harness owns this process lifetime and terminates it after all
// transport tests. Do not use a wall-clock timer here: as the suite grows, a
// fixed lifetime turns later parser/fuzz checks into false crash reports.
while true {
    RunLoop.current.run(until: Date().addingTimeInterval(3_600))
}
SWIFT

swiftc -framework Network -framework Security -o "$TMP_DIR/server-test" \
    macos/ProcessRunner.swift \
    macos/ExecProcessEnvironmentAuthority.swift \
    macos/LogicalChatCorrelation.swift \
    macos/ToolCatalog.swift \
    macos/ServerPolicy.swift \
    macos/ToolResultEnvelope.swift \
    macos/ToolExecutionContext.swift \
    macos/AuthenticatedCursorCodec.swift \
    macos/FileVersionService.swift \
    macos/AuthorizedPathSnapshot.swift \
    macos/LocalMCPServer.swift \
    "$TMP_DIR/main.swift"
mkdir -p "$TMP_DIR/git-template"
printf 'outside-template-marker\n' > "$TMP_DIR/git-template/copied-from-template"
GIT_TEMPLATE_DIR="$TMP_DIR/git-template" "$TMP_DIR/server-test" &
SERVER_PID=$!
python3 - <<'PY'
import socket
import time

ports = (18088, 18089, 18090)
deadline = time.monotonic() + 15.0
pending = set(ports)
while pending and time.monotonic() < deadline:
    for port in tuple(pending):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                pending.remove(port)
        except OSError:
            pass
    if pending:
        time.sleep(0.05)
if pending:
    raise SystemExit(f"macOS server fixtures did not become ready on ports: {sorted(pending)}")
print("macos-server-fixture-ready: ok")
PY

BASE_URL="http://127.0.0.1:18088/mcp"
SAFE_BASE_URL="http://127.0.0.1:18089/mcp"
SERVER_ROOT="${TMPDIR%/}/filemcp-server-test"
LOCAL_AUTH_TOKEN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
CATALOG_HASH="$(python3 -c 'import hashlib, pathlib; t=pathlib.Path("contracts/tool_catalog.v1.json").read_text(encoding="utf-8-sig").replace("\r\n","\n").replace("\r","\n"); print(hashlib.sha256(t.encode("utf-8")).hexdigest())')"
CATALOG_VERSION="1.2.0"
INSTRUCTION_VERSION="1.0.0"

python3 - <<'PY'
import socket
import time

HOST = "127.0.0.1"
PORT = 18090
TOKEN = "a" * 64

def connect():
    sock = socket.create_connection((HOST, PORT), timeout=2)
    sock.settimeout(2)
    return sock

def closed(sock, timeout=1.5):
    sock.settimeout(timeout)
    try:
        return sock.recv(1) == b""
    except (ConnectionResetError, BrokenPipeError, OSError):
        return True
    except socket.timeout:
        return False

first = connect()
second = connect()
first.sendall(b"G")
second.sendall(b"G")
time.sleep(0.10)

excess = connect()
if not closed(excess):
    raise SystemExit("macOS connection cap did not reject excess client")
excess.close()

first.close()
time.sleep(0.15)

body = b'{"jsonrpc":"2.0","id":900,"method":"tools/list","params":{}}'
request = (
    f"POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{PORT}\r\n"
    "Content-Type: application/json\r\n"
    f"X-FileMCP-Local-Token: {TOKEN}\r\n"
    f"Content-Length: {len(body)}\r\n\r\n"
).encode() + body
valid = connect()
valid.sendall(request)
valid.shutdown(socket.SHUT_WR)
response = b""
while True:
    chunk = valid.recv(8192)
    if not chunk:
        break
    response += chunk
valid.close()
if b"HTTP/1.1 200 OK" not in response:
    raise SystemExit("macOS connection slot was not reusable after release")
second.close()
time.sleep(0.10)

idle = connect()
time.sleep(0.80)
if not closed(idle):
    raise SystemExit("macOS idle connection did not time out")
idle.close()

trickle = connect()
trickle_closed = False
started = time.monotonic()
for _ in range(20):
    try:
        trickle.sendall(b"G")
    except (BrokenPipeError, ConnectionResetError, OSError):
        trickle_closed = True
        break
    time.sleep(0.10)
    if time.monotonic() - started > 1.6:
        break
if not trickle_closed:
    trickle_closed = closed(trickle, timeout=0.8)
trickle.close()
if not trickle_closed:
    raise SystemExit("macOS absolute header deadline did not stop trickle client")

print("macos-http-connection-bounds: ok")
PY

UNAUTHENTICATED="$(command curl -sS -i -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":389,"method":"ping","params":{}}')"
printf '%s' "$UNAUTHENTICATED" | grep -q 'HTTP/1.1 401 Unauthorized'
printf '%s' "$UNAUTHENTICATED" | grep -q 'Unauthorized'

DISCOVERY_PATH="$(command curl -sS -i 'http://127.0.0.1:18088/.well-known/oauth-protected-resource/mcp')"
printf '%s' "$DISCOVERY_PATH" | grep -q 'HTTP/1.1 404 Not Found'
printf '%s' "$DISCOVERY_PATH" | grep -q 'Not found'

DISCOVERY_ROOT="$(command curl -sS -i 'http://127.0.0.1:18088/.well-known/oauth-protected-resource')"
printf '%s' "$DISCOVERY_ROOT" | grep -q 'HTTP/1.1 404 Not Found'

UNAUTHENTICATED_UNKNOWN_PATH="$(command curl -sS -i 'http://127.0.0.1:18088/not-found')"
printf '%s' "$UNAUTHENTICATED_UNKNOWN_PATH" | grep -q 'HTTP/1.1 401 Unauthorized'

UNAUTHENTICATED_DISCOVERY_POST="$(command curl -sS -i -X POST 'http://127.0.0.1:18088/.well-known/oauth-protected-resource/mcp')"
printf '%s' "$UNAUTHENTICATED_DISCOVERY_POST" | grep -q 'HTTP/1.1 401 Unauthorized'

DOCTOR_RESULT="$(CONTROL_PLANE_API_KEY=dummy-key "$TUNNEL_BIN" doctor \
    --control-plane.tunnel-id tunnel_0123456789abcdef0123456789abcdef \
    --mcp.server-url "$BASE_URL" \
    --health.listen-addr 127.0.0.1:0 2>&1)"
printf '%s' "$DOCTOR_RESULT" | grep -Eq 'CHECK oauth_metadata +PASS OAuth metadata not advertised'
printf '%s' "$DOCTOR_RESULT" | grep -q 'RESULT ok'
echo "tunnel-client-doctor-no-auth-oauth-discovery: ok"

WRONG_LOCAL_TOKEN="$(command curl -sS -i -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'X-FileMCP-Local-Token: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
    -d '{"jsonrpc":"2.0","id":388,"method":"ping","params":{}}')"
printf '%s' "$WRONG_LOCAL_TOKEN" | grep -q 'HTTP/1.1 401 Unauthorized'

curl() {
    command curl -H "X-FileMCP-Local-Token: $LOCAL_AUTH_TOKEN" "$@"
}

SAFE_TOOLS="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":390,"method":"tools/list","params":{}}')"
if printf '%s' "$SAFE_TOOLS" | grep -q '"name":"run_command"'; then
    echo "run_command must not be exposed while command execution is disabled" >&2
    exit 1
fi
if printf '%s' "$SAFE_TOOLS" | grep -q '"name":"exec_process"'; then
    echo "exec_process must not be exposed while restricted policy is active" >&2
    exit 1
fi

FULL_TOOLS="$(curl -fsS -X POST "$BASE_URL"     -H 'Content-Type: application/json'     -d '{"jsonrpc":"2.0","id":3891,"method":"tools/list","params":{}}')"
printf '%s' "$FULL_TOOLS" | grep -q '"name":"exec_process"'
printf '%s' "$FULL_TOOLS" | grep -q '"name":"run_command"'

printf '%s' "$SAFE_TOOLS" | grep -q '"name":"filemcp_observability_connect"'
printf '%s' "$SAFE_TOOLS" | grep -q '"_filemcp_chat"'

CHAT_CONNECT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":391,"method":"tools/call","params":{"name":"filemcp_observability_connect","arguments":{}}}')"
CHAT_HANDLE="$(printf '%s' "$CHAT_CONNECT" | plutil -extract result.structuredContent.chat_instance_id raw -expect string -o - -)"
printf '%s' "$CHAT_HANDLE" | grep -Eq '^chat_[A-Za-z0-9_-]{43}$'
printf '%s' "$CHAT_CONNECT" | plutil -extract result.structuredContent.resumed raw -expect bool -o - - | grep -qx 'false'

CHAT_RESUME="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":392,\"method\":\"tools/call\",\"params\":{\"name\":\"filemcp_observability_connect\",\"arguments\":{\"chat_instance_id\":\"$CHAT_HANDLE\"}}}")"
printf '%s' "$CHAT_RESUME" | plutil -extract result.structuredContent.resumed raw -expect bool -o - - | grep -qx 'true'

CHAT_BAD_ARG="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":393,"method":"tools/call","params":{"name":"filemcp_observability_connect","arguments":{"unexpected":true}}}')"
printf '%s' "$CHAT_BAD_ARG" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$CHAT_BAD_ARG" | grep -q 'Unknown argument'

CORRELATED_READ="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":394,\"method\":\"tools/call\",\"params\":{\"name\":\"read_file\",\"arguments\":{\"relative_path\":\"hello.txt\",\"_filemcp_chat\":\"$CHAT_HANDLE\"}}}")"
printf '%s' "$CORRELATED_READ" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$CORRELATED_READ" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx 'hello swift'

UNKNOWN_CHAT_HANDLE="chat_$(printf 'A%.0s' {1..43})"
UNBOUND_READ="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":395,\"method\":\"tools/call\",\"params\":{\"name\":\"read_file\",\"arguments\":{\"relative_path\":\"hello.txt\",\"_filemcp_chat\":\"$UNKNOWN_CHAT_HANDLE\"}}}")"
printf '%s' "$UNBOUND_READ" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$UNBOUND_READ" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx 'hello swift'
echo "logical-chat-facade-legacy: ok"

EXEC_ARGV="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":430,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/bin/echo","arguments":["$HOME;echo hacked"],"timeout_seconds":5,"output_limit_bytes":10000}}}')"
if ! printf '%s' "$EXEC_ARGV" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'; then
    echo "exec_process argv response: $EXEC_ARGV" >&2
    exit 1
fi
printf '%s' "$EXEC_ARGV" | plutil -extract result.structuredContent.terminal_state raw -expect string -o - - | grep -qx 'exited'
printf '%s' "$EXEC_ARGV" | plutil -extract result.structuredContent.exit_code raw -expect integer -o - - | grep -qx '0'
printf '%s' "$EXEC_ARGV" | plutil -extract result.structuredContent.stdout raw -expect string -o - - | grep -Fqx '$HOME;echo hacked'
echo "mcp-exec-argv: ok"

EXEC_CWD="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":431,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/bin/pwd","arguments":[],"cwd":"exec-work","timeout_seconds":5}}}')"
printf '%s' "$EXEC_CWD" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
EXEC_CWD_ACTUAL="$(printf '%s' "$EXEC_CWD" | plutil -extract result.structuredContent.stdout raw -expect string -o - - | tr -d '\r\n')"
EXEC_CWD_EXPECTED="$(cd "$SERVER_ROOT/exec-work" && pwd -P)"
if [ "$EXEC_CWD_ACTUAL" != "$EXEC_CWD_EXPECTED" ]; then
    echo "exec_process cwd mismatch: actual=$EXEC_CWD_ACTUAL expected=$EXEC_CWD_EXPECTED" >&2
    exit 1
fi
echo "mcp-exec-cwd: ok"

EXEC_CWD_ESCAPE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":432,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/bin/pwd","arguments":[],"cwd":"../filemcp-server-outside","timeout_seconds":5}}}')"
printf '%s' "$EXEC_CWD_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EXEC_CWD_ESCAPE" | grep -q 'outside the shared directory'
echo "mcp-exec-cwd-escape: ok"

EXEC_NONZERO="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":433,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/false","arguments":[],"timeout_seconds":5}}}')"
printf '%s' "$EXEC_NONZERO" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$EXEC_NONZERO" | plutil -extract result.structuredContent.terminal_state raw -expect string -o - - | grep -qx 'exited'
printf '%s' "$EXEC_NONZERO" | plutil -extract result.structuredContent.exit_code raw -expect integer -o - - | grep -qx '1'
echo "mcp-exec-nonzero: ok"

EXEC_TIMEOUT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":434,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/bin/sleep","arguments":["5"],"timeout_seconds":1}}}')"
printf '%s' "$EXEC_TIMEOUT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$EXEC_TIMEOUT" | plutil -extract result.structuredContent.terminal_state raw -expect string -o - - | grep -qx 'timed_out'
printf '%s' "$EXEC_TIMEOUT" | plutil -extract result.structuredContent.timed_out raw -expect bool -o - - | grep -qx 'true'
echo "mcp-exec-timeout: ok"

EXEC_CANCELLED="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":4341,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/bin/sleep","arguments":["5"],"timeout_seconds":5},"_meta":{"io.filemcp/budget":{"timeoutMs":100}}}}')"
printf '%s' "$EXEC_CANCELLED" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$EXEC_CANCELLED" | plutil -extract result.structuredContent.terminal_state raw -expect string -o - - | grep -qx 'cancelled'
printf '%s' "$EXEC_CANCELLED" | plutil -extract result.structuredContent.cancelled raw -expect bool -o - - | grep -qx 'true'
echo "mcp-exec-budget-cancel: ok"

EXEC_BOUNDED="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":435,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/yes","arguments":["FMG005"],"timeout_seconds":1,"output_limit_bytes":1000}}}')"
printf '%s' "$EXEC_BOUNDED" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$EXEC_BOUNDED" | plutil -extract result.structuredContent.stdout_truncated raw -expect bool -o - - | grep -qx 'true'
EXEC_OMITTED="$(printf '%s' "$EXEC_BOUNDED" | plutil -extract result.structuredContent.stdout_omitted_bytes raw -expect integer -o - -)"
[ "$EXEC_OMITTED" -gt 0 ]
echo "mcp-exec-output-bound: ok"

EXEC_NUL="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":436,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/printf","arguments":["bad\u0000argument"],"timeout_seconds":5}}}')"
printf '%s' "$EXEC_NUL" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EXEC_NUL" | grep -q 'NUL byte'
echo "mcp-exec-nul: ok"

EXEC_ARGV_LIMIT_BODY="$(python3 - <<'PY'
import json
print(json.dumps({"jsonrpc":"2.0","id":4361,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/printf","arguments":["a"*20000,"b"*20000],"timeout_seconds":5}}}))
PY
)"
EXEC_ARGV_LIMIT="$(curl -fsS -X POST "$BASE_URL" -H 'Content-Type: application/json' --data-binary "$EXEC_ARGV_LIMIT_BODY")"
printf '%s' "$EXEC_ARGV_LIMIT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EXEC_ARGV_LIMIT" | grep -q 'total argument size'
echo "mcp-exec-argv-limit: ok"

EXEC_ENV_FORBIDDEN="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":437,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/env","arguments":[],"environment":{"FMG005_FORBIDDEN":"blocked"},"timeout_seconds":5}}}')"
printf '%s' "$EXEC_ENV_FORBIDDEN" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EXEC_ENV_FORBIDDEN" | grep -q 'not locally allowed'
echo "mcp-exec-env-deny: ok"

EXEC_ENV_ALLOWED="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":438,"method":"tools/call","params":{"name":"exec_process","arguments":{"executable":"/usr/bin/env","arguments":[],"environment":{"FMG005_OVERRIDE":"request-value"},"timeout_seconds":5}}}')"
printf '%s' "$EXEC_ENV_ALLOWED" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$EXEC_ENV_ALLOWED" | plutil -extract result.structuredContent.stdout raw -expect string -o - - | grep -q '^FMG005_OVERRIDE=request-value$'
echo "mcp-exec-env-allow: ok"

echo "macos-exec-process: ok"

NEGATIVE_LENGTH="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: -1\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$NEGATIVE_LENGTH" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$NEGATIVE_LENGTH" | grep -q 'Invalid Content-Length header'
kill -0 "$SERVER_PID"

OVERSIZED_LENGTH="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: 8000001\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$OVERSIZED_LENGTH" | grep -q 'HTTP/1.1 413 Payload Too Large'
kill -0 "$SERVER_PID"

MALFORMED_LENGTH="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: nope\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$MALFORMED_LENGTH" | grep -q 'HTTP/1.1 400 Bad Request'
kill -0 "$SERVER_PID"

SIGNED_LENGTH="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: +1\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$SIGNED_LENGTH" | grep -q 'HTTP/1.1 400 Bad Request'
kill -0 "$SERVER_PID"

DUPLICATE_LENGTH="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$DUPLICATE_LENGTH" | grep -q 'HTTP/1.1 400 Bad Request'
kill -0 "$SERVER_PID"

DUPLICATE_MCP_METHOD="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nMcp-Method: ping\r\nMcp-Method: tools/list\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$DUPLICATE_MCP_METHOD" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$DUPLICATE_MCP_METHOD" | grep -q 'Duplicate mcp-method header'
kill -0 "$SERVER_PID"

TRANSFER_ENCODING="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$TRANSFER_ENCODING" | grep -q 'HTTP/1.1 400 Bad Request'
kill -0 "$SERVER_PID"

MALFORMED_HEADER_NAME="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nBad Header: value\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$MALFORMED_HEADER_NAME" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$MALFORMED_HEADER_NAME" | grep -q 'Malformed request header'
kill -0 "$SERVER_PID"

HEADER_NAME_OWS="$(printf 'POST /mcp HTTP/1.1\r\nHost : 127.0.0.1:18088\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$HEADER_NAME_OWS" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$HEADER_NAME_OWS" | grep -q 'Malformed request header'
kill -0 "$SERVER_PID"

INVALID_HOST_PORT="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:99999\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$INVALID_HOST_PORT" | grep -q 'HTTP/1.1 403 Forbidden'
kill -0 "$SERVER_PID"

EXTRA_BODY_BYTES="$(printf 'POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nX-FileMCP-Local-Token: %s\r\nContent-Type: application/json\r\nContent-Length: 0\r\n\r\nJUNK' "$LOCAL_AUTH_TOKEN" | nc 127.0.0.1 18088)"
printf '%s' "$EXTRA_BODY_BYTES" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$EXTRA_BODY_BYTES" | grep -q 'Unexpected bytes after request body'
kill -0 "$SERVER_PID"

MISSING_HOST="$(printf 'POST /mcp HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$MISSING_HOST" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$MISSING_HOST" | grep -q 'Missing Host header'
kill -0 "$SERVER_PID"

EARLY_FORBIDDEN_HOST="$(printf 'POST /mcp HTTP/1.1\r\nHost: evil.example\r\nContent-Type: application/json\r\nContent-Length: 8000000\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$EARLY_FORBIDDEN_HOST" | grep -q 'HTTP/1.1 403 Forbidden'
printf '%s' "$EARLY_FORBIDDEN_HOST" | grep -q 'Forbidden host'
kill -0 "$SERVER_PID"

MALFORMED_REQUEST_LINE="$(printf 'POST /mcp\r\nHost: 127.0.0.1:18088\r\nContent-Length: 0\r\n\r\n' | nc 127.0.0.1 18088)"
printf '%s' "$MALFORMED_REQUEST_LINE" | grep -q 'HTTP/1.1 400 Bad Request'
printf '%s' "$MALFORMED_REQUEST_LINE" | grep -q 'Malformed request line'
kill -0 "$SERVER_PID"

# Repeated malformed framing used to be difficult to distinguish from the test
# server's fixed lifetime expiring. Keep the server alive under harness control
# and hammer deterministic malformed variants, then prove it still serves a
# valid request afterwards.
for index in $(seq 1 "$MCP_HTTP_FUZZ_ITERATIONS"); do
    case $((index % 5)) in
        0) request="POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: -${index}\r\n\r\n" ;;
        1) request="POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: application/json\r\nContent-Length: ${index}x\r\n\r\n" ;;
        2) request="POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n" ;;
        3) request="P${index} /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Length: 0\r\n\r\n" ;;
        4) request="POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nContent-Type: text/plain\r\nX-Fuzz-${index}: value\r\nContent-Length: 0\r\n\r\n" ;;
    esac
    printf '%b' "$request" | nc 127.0.0.1 18088 >/dev/null
    if [ $((index % 20)) -eq 0 ]; then
        kill -0 "$SERVER_PID"
    fi
done
POST_FUZZ_PING="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":399,"method":"ping","params":{}}')"
printf '%s' "$POST_FUZZ_PING" | grep -q '"result"'
kill -0 "$SERVER_PID"
echo "http-malformed-fuzz: ok"

INITIALIZE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}')"
printf '%s' "$INITIALIZE" | grep -q '"protocolVersion":"2025-03-26"'
printf '%s' "$INITIALIZE" | grep -q '"serverInfo"'
printf '%s' "$INITIALIZE" | grep -q '"name":"filemcp"'
echo "mcp-legacy-initialize: ok"

TOP_LEVEL_NON_OBJECT_PARAMS="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":101,"method":"initialize","params":[]}')"
printf '%s' "$TOP_LEVEL_NON_OBJECT_PARAMS" | grep -q '"code":-32602'
printf '%s' "$TOP_LEVEL_NON_OBJECT_PARAMS" | grep -q 'Invalid params: expected an object'
echo "mcp-legacy-invalid-params: ok"

CLAIMLESS_DISCOVER="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":102,"method":"server/discover","params":{}}')"
printf '%s' "$CLAIMLESS_DISCOVER" | grep -q '"code":-32601'
printf '%s' "$CLAIMLESS_DISCOVER" | grep -q 'Method not found: server.*discover'
echo "mcp-legacy-claimless-discover: ok"

DOWNGRADE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"2099-01-01","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}')"
printf '%s' "$DOWNGRADE" | grep -q '"protocolVersion":"2025-11-25"'
echo "mcp-legacy-downgrade: ok"

READ_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"read_file","arguments":{"relative_path":"hello.txt"}}}')"
printf '%s' "$READ_RESULT" | grep -q 'hello swift'

printf '%s' "$READ_RESULT" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx 'hello swift'
printf '%s' "$READ_RESULT" | plutil -extract result.structuredContent.version raw -expect string -o - - | grep -Eq '^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$'
printf '%s' "$READ_RESULT" | plutil -extract result.structuredContent.version_strength raw -expect string -o - - | grep -qx 'content'
printf '%s' "$READ_RESULT" | plutil -extract result.structuredContent.size_bytes raw -expect integer -o - - | grep -qx '11'
printf '%s' "$READ_RESULT" | python3 -c 'import json,sys,re; d=json.load(sys.stdin); e=d["result"]["_meta"]["io.filemcp/result"]; assert e["schemaVersion"]=="1.0.0" and e["status"]=="success"; assert re.fullmatch(r"op_[0-9a-f]{32}", e["operationId"]); assert e["truncation"]=={"truncated":False,"reason":"none"}; assert e["usage"]["contentItems"]==1 and e["warnings"]==[]'
echo "mcp-legacy-read-envelope: ok"

LIST_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":30,"method":"tools/call","params":{"name":"list_files","arguments":{}}}')"
printf '%s' "$LIST_RESULT" | plutil -extract result.structuredContent.result raw -expect array -o - - | grep -Eq '^[1-9][0-9]*$'
printf '%s' "$LIST_RESULT" | plutil -extract result.structuredContent.result json -o - - | grep -q '"sample.swift"'

printf '%s' "$LIST_RESULT" | plutil -extract result.structuredContent.truncated raw -expect bool -o - - | grep -qx 'false'
echo "mcp-legacy-list-baseline: ok"

BUDGET_LIST_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":309,"method":"tools/call","params":{"name":"list_files","arguments":{},"_meta":{"io.filemcp/budget":{"maxOutputItems":1}}}}')"
printf '%s' "$BUDGET_LIST_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$BUDGET_LIST_RESULT" | plutil -extract result.structuredContent.result raw -expect array -o - - | grep -qx '1'
printf '%s' "$BUDGET_LIST_RESULT" | plutil -extract result.structuredContent.truncated raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$BUDGET_LIST_RESULT" | python3 -c 'import json,sys; e=json.load(sys.stdin)["result"]["_meta"]["io.filemcp/result"]; assert e["status"]=="partial"; assert e["usage"]["outputItems"]==1; assert e["usage"]["budget"]["maxOutputItems"]==1; assert e["truncation"]["detail"]=="output_items"'
echo "mcp-legacy-budget-list: ok"

UNSUPPORTED_BUDGET_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":310,"method":"tools/call","params":{"name":"read_file","arguments":{"relative_path":"hello.txt"},"_meta":{"io.filemcp/budget":{"maxOutputItems":1}}}}')"
printf '%s' "$UNSUPPORTED_BUDGET_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$UNSUPPORTED_BUDGET_RESULT" | grep -q 'Tool budget metadata is not supported for tool: read_file'
echo "mcp-legacy-budget-unsupported: ok"

LIST_LIMIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":300,"method":"tools/call","params":{"name":"list_files","arguments":{"subpath":"list-limit"}}}')"
printf '%s' "$LIST_LIMIT_RESULT" | plutil -extract result.structuredContent.result raw -expect array -o - - | grep -qx '1000'
printf '%s' "$LIST_LIMIT_RESULT" | plutil -extract result.structuredContent.truncated raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$LIST_LIMIT_RESULT" | python3 -c 'import json,sys; e=json.load(sys.stdin)["result"]["_meta"]["io.filemcp/result"]; assert e["status"]=="partial"; assert e["truncation"]=={"truncated":True,"reason":"server_limit"}; assert e["usage"]["contentItems"]==1000'
if printf '%s' "$LIST_LIMIT_RESULT" | grep -q '\[\.\.\.truncated'; then
    echo "list_files leaked truncation marker into filename results" >&2
    exit 1
fi

FILENAME_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":301,"method":"tools/call","params":{"name":"search_filenames","arguments":{"query":"sample.swift"}}}')"
printf '%s' "$FILENAME_RESULT" | plutil -extract result.structuredContent.result json -o - - | grep -qx '\["sample.swift"\]'
if printf '%s' "$FILENAME_RESULT" | grep -q '/private'; then
    echo "search_filenames returned a non-relative canonical path" >&2
    exit 1
fi

printf '%s' "$FILENAME_RESULT" | plutil -extract result.structuredContent.truncated raw -expect bool -o - - | grep -qx 'false'

FILENAME_LIMIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":306,"method":"tools/call","params":{"name":"search_filenames","arguments":{"query":"filename-target-"}}}')"
printf '%s' "$FILENAME_LIMIT_RESULT" | plutil -extract result.structuredContent.result raw -expect array -o - - | grep -qx '200'
printf '%s' "$FILENAME_LIMIT_RESULT" | plutil -extract result.structuredContent.truncated raw -expect bool -o - - | grep -qx 'true'
if printf '%s' "$FILENAME_LIMIT_RESULT" | grep -q '\[\.\.\.search stopped'; then
    echo "search_filenames leaked truncation marker into filename results" >&2
    exit 1
fi

EMPTY_FILENAME_QUERY="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":307,"method":"tools/call","params":{"name":"search_filenames","arguments":{"query":""}}}')"
printf '%s' "$EMPTY_FILENAME_QUERY" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EMPTY_FILENAME_QUERY" | python3 -c 'import json,sys; e=json.load(sys.stdin)["result"]["_meta"]["io.filemcp/result"]; assert e["status"]=="tool_error" and e["truncation"]["truncated"] is False'
printf '%s' "$EMPTY_FILENAME_QUERY" | grep -q 'query must not be empty'

INVALID_OPTIONAL_TYPE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":302,"method":"tools/call","params":{"name":"list_files","arguments":{"subpath":123}}}')"
printf '%s' "$INVALID_OPTIONAL_TYPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$INVALID_OPTIONAL_TYPE" | grep -q 'Missing or invalid argument: subpath'

UNKNOWN_ARGUMENT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":303,"method":"tools/call","params":{"name":"read_file","arguments":{"relative_path":"hello.txt","surprise":true}}}')"
printf '%s' "$UNKNOWN_ARGUMENT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$UNKNOWN_ARGUMENT" | grep -q 'Unexpected argument: surprise'

NON_OBJECT_ARGUMENTS="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":304,"method":"tools/call","params":{"name":"read_file","arguments":[]}}')"
printf '%s' "$NON_OBJECT_ARGUMENTS" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$NON_OBJECT_ARGUMENTS" | grep -q 'Invalid arguments: expected an object'

OUT_OF_RANGE_OPTIONAL="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":305,"method":"tools/call","params":{"name":"search_content","arguments":{"query":"needle","context_lines":11}}}')"
printf '%s' "$OUT_OF_RANGE_OPTIONAL" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$OUT_OF_RANGE_OPTIONAL" | grep -q 'Argument context_lines must be &lt;= 10\|Argument context_lines must be <= 10'

SEARCH_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"search_content","arguments":{"query":"needle-target","path":"","context_lines":1,"max_results":10}}}')"
printf '%s' "$SEARCH_RESULT" | grep -q 'sample.swift'
printf '%s' "$SEARCH_RESULT" | grep -q 'line.*4'
printf '%s' "$SEARCH_RESULT" | grep -q 'needle-target'
printf '%s' "$SEARCH_RESULT" | plutil -extract result.structuredContent.matches.0.path raw -expect string -o - - | grep -qx 'sample.swift'
printf '%s' "$SEARCH_RESULT" | plutil -extract result.structuredContent.matches.0.line raw -expect integer -o - - | grep -qx '4'

CRLF_SEARCH="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":332,"method":"tools/call","params":{"name":"search_content","arguments":{"query":"needle-crlf","path":"","context_lines":1,"max_results":10}}}')"
printf '%s' "$CRLF_SEARCH" | grep -q 'crlf.txt'
printf '%s' "$CRLF_SEARCH" | sed 's/\\"/"/g' | grep -q '"line" : 3'
printf '%s' "$CRLF_SEARCH" | sed 's/\\"/"/g' | grep -q '"preview_start_line" : 2'

CRLF_RANGE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":333,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"crlf.txt","start_line":2,"end_line":3}}}')"
printf '%s' "$CRLF_RANGE" | sed 's/\\"/"/g' | grep -q '"total_lines" : 4'
printf '%s' "$CRLF_RANGE" | sed 's/\\"/"/g' | grep -q '"end_line" : 3'
printf '%s' "$CRLF_RANGE" | grep -q 'line-two'
printf '%s' "$CRLF_RANGE" | grep -q 'needle-crlf'

RANGE_MISSING_START="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":334,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"sample.swift","end_line":7}}}')"
printf '%s' "$RANGE_MISSING_START" | grep -q '"isError":true'
printf '%s' "$RANGE_MISSING_START" | grep -q 'Missing or invalid argument: start_line'

RANGE_FRACTIONAL_START="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":337,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"sample.swift","start_line":1.5,"end_line":7}}}')"
printf '%s' "$RANGE_FRACTIONAL_START" | grep -q '"isError":true'
printf '%s' "$RANGE_FRACTIONAL_START" | grep -q 'Missing or invalid argument: start_line'

BINARY_SCAN="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":335,"method":"tools/call","params":{"name":"search_content","arguments":{"query":"not-present","path":"binary-only","context_lines":1,"max_results":10}}}')"
printf '%s' "$BINARY_SCAN" | sed 's/\\"/"/g' | grep -q '"bytes_scanned" : 1024'
printf '%s' "$BINARY_SCAN" | sed 's/\\"/"/g' | grep -q '"files_scanned" : 0'

EOF_RANGE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":336,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"trailing-newline.txt","start_line":1,"end_line":2}}}')"
printf '%s' "$EOF_RANGE" | sed 's/\\"/"/g' | grep -q '"total_lines" : 2'
printf '%s' "$EOF_RANGE" | grep -q 'has_after.*false'
printf '%s' "$EOF_RANGE" | grep -q 'truncated.*false'
printf '%s' "$EOF_RANGE" | grep -q 'second'

SEARCH_ESCAPE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":331,"method":"tools/call","params":{"name":"search_content","arguments":{"query":"must stay private","path":"","context_lines":1,"max_results":10}}}')"
if printf '%s' "$SEARCH_ESCAPE" | grep -q 'secret.txt'; then
    echo "search_content escaped through symlink" >&2
    exit 1
fi

RANGE_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"sample.swift","start_line":3,"end_line":7}}}')"
printf '%s' "$RANGE_RESULT" | grep -q 'start_line.*3'
printf '%s' "$RANGE_RESULT" | grep -q 'end_line.*7'
printf '%s' "$RANGE_RESULT" | grep -q 'has_before.*true'
printf '%s' "$RANGE_RESULT" | grep -q 'needle-target'
printf '%s' "$RANGE_RESULT" | grep -q 'func beta'
printf '%s' "$RANGE_RESULT" | plutil -extract result.structuredContent.start_line raw -expect integer -o - - | grep -qx '3'
printf '%s' "$RANGE_RESULT" | plutil -extract result.structuredContent.end_line raw -expect integer -o - - | grep -qx '7'
printf '%s' "$RANGE_RESULT" | plutil -extract result.structuredContent.version raw -expect string -o - - | grep -Eq '^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$'
printf '%s' "$RANGE_RESULT" | plutil -extract result.structuredContent.version_strength raw -expect string -o - - | grep -qx 'content'

RANGE_LIMIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":341,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"large-range.txt","start_line":1,"end_line":1000}}}')"
printf '%s' "$RANGE_LIMIT_RESULT" | sed 's/\\"/"/g' | grep -q '"end_line" : 398'
printf '%s' "$RANGE_LIMIT_RESULT" | grep -q 'truncated.*true'
printf '%s' "$RANGE_LIMIT_RESULT" | grep -q 'has_after.*true'
printf '%s' "$RANGE_LIMIT_RESULT" | grep -q 'LINE-0398'
if printf '%s' "$RANGE_LIMIT_RESULT" | grep -q 'LINE-0399'; then
    echo "read_file_range returned a partial line past end_line" >&2
    exit 1
fi

RANGE_CONTINUATION="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":342,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"large-range.txt","start_line":399,"end_line":1000}}}')"
printf '%s' "$RANGE_CONTINUATION" | sed 's/\\"/"/g' | grep -q '"start_line" : 399'
printf '%s' "$RANGE_CONTINUATION" | grep -q 'LINE-0399'

LONG_LINE_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":338,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"long-line.txt","start_line":1,"end_line":1}}}')"
printf '%s' "$LONG_LINE_RESULT" | grep -q '"isError":true'
printf '%s' "$LONG_LINE_RESULT" | grep -q '80,000 character response limit'

LINE_LIMIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":339,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"many-lines.txt","start_line":1,"end_line":1200}}}')"
printf '%s' "$LINE_LIMIT_RESULT" | sed 's/\\"/"/g' | grep -q '"end_line" : 1000'
printf '%s' "$LINE_LIMIT_RESULT" | grep -q 'truncated.*true'
printf '%s' "$LINE_LIMIT_RESULT" | grep -q 'has_after.*true'
printf '%s' "$LINE_LIMIT_RESULT" | grep -q 'SHORT-1000'
if printf '%s' "$LINE_LIMIT_RESULT" | grep -q 'SHORT-1001'; then
    echo "read_file_range exceeded the 1000-line cap" >&2
    exit 1
fi

LINE_LIMIT_CONTINUATION="$(curl -fsS -X POST "$BASE_URL" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":340,"method":"tools/call","params":{"name":"read_file_range","arguments":{"relative_path":"many-lines.txt","start_line":1001,"end_line":1200}}}')"
printf '%s' "$LINE_LIMIT_CONTINUATION" | grep -q 'SHORT-1001'

ESCAPE_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":31,"method":"tools/call","params":{"name":"read_file","arguments":{"relative_path":"escape/secret.txt"}}}')"
printf '%s' "$ESCAPE_RESULT" | grep -q '"isError":true'
printf '%s' "$ESCAPE_RESULT" | grep -q 'outside the shared directory'

WRITE_ESCAPE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"write_file","arguments":{"relative_path":"escape/new.txt","content":"blocked"}}}')"
printf '%s' "$WRITE_ESCAPE" | grep -q '"isError":true'
printf '%s' "$WRITE_ESCAPE" | grep -q 'outside the shared directory'

DELETE_FILE_LINK="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":321,"method":"tools/call","params":{"name":"delete_file","arguments":{"relative_path":"delete-file-link"}}}')"
printf '%s' "$DELETE_FILE_LINK" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
[ -f "$SERVER_ROOT/delete-target.txt" ]
[ ! -L "$SERVER_ROOT/delete-file-link" ]

DELETE_DIR_LINK="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":322,"method":"tools/call","params":{"name":"delete_directory","arguments":{"relative_path":"delete-dir-link"}}}')"
printf '%s' "$DELETE_DIR_LINK" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$DELETE_DIR_LINK" | grep -q 'Use delete_file for symlinks'
[ -d "$SERVER_ROOT/delete-target-dir" ]
[ -L "$SERVER_ROOT/delete-dir-link" ]

DELETE_DIR_LINK_AS_FILE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":323,"method":"tools/call","params":{"name":"delete_file","arguments":{"relative_path":"delete-dir-link"}}}')"
printf '%s' "$DELETE_DIR_LINK_AS_FILE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
[ -d "$SERVER_ROOT/delete-target-dir" ]
[ ! -L "$SERVER_ROOT/delete-dir-link" ]

DELETE_OUTSIDE_LINK="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":324,"method":"tools/call","params":{"name":"delete_file","arguments":{"relative_path":"delete-outside-link"}}}')"
printf '%s' "$DELETE_OUTSIDE_LINK" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
[ -f "${TMPDIR%/}/filemcp-server-outside/secret.txt" ]
[ ! -L "$SERVER_ROOT/delete-outside-link" ]

echo "symlink-delete-semantics: ok"

GIT_INIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":400,"method":"tools/call","params":{"name":"git_init","arguments":{"repo_path":"git-fixture"}}}')"
printf '%s' "$GIT_INIT_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$GIT_INIT_RESULT" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx 'Initialized Git repository: git-fixture'
if printf '%s' "$GIT_INIT_RESULT" | grep -q "$SERVER_ROOT"; then
    echo "git_init leaked the absolute shared-root path" >&2
    exit 1
fi

printf 'first\n' > "$TMP_DIR/git-content.txt"
GIT_WRITE_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":401,"method":"tools/call","params":{"name":"write_file","arguments":{"relative_path":"git-fixture/file with space.txt","content":"first\n"}}}')"
printf '%s' "$GIT_WRITE_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'

GIT_ADD_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":402,"method":"tools/call","params":{"name":"git_add","arguments":{"repo_path":"git-fixture","paths":"file with space.txt"}}}')"
printf '%s' "$GIT_ADD_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$GIT_ADD_RESULT" | grep -q 'Staged: file with space.txt'

GIT_COMMIT_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":403,"method":"tools/call","params":{"name":"git_commit","arguments":{"repo_path":"git-fixture","message":"initial fixture"}}}')"
printf '%s' "$GIT_COMMIT_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'

GIT_STATUS_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":404,"method":"tools/call","params":{"name":"git_status","arguments":{"repo_path":"git-fixture"}}}')"
printf '%s' "$GIT_STATUS_RESULT" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx '(working tree clean)'

GIT_LOG_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":405,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"git-fixture","count":1}}}')"
printf '%s' "$GIT_LOG_RESULT" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -q 'initial fixture'

GIT_UPDATE_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":406,"method":"tools/call","params":{"name":"write_file","arguments":{"relative_path":"git-fixture/file with space.txt","content":"second\n"}}}')"
printf '%s' "$GIT_UPDATE_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'

GIT_DIFF_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":407,"method":"tools/call","params":{"name":"git_diff","arguments":{"repo_path":"git-fixture","paths":"\"file with space.txt\""}}}')"
printf '%s' "$GIT_DIFF_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$GIT_DIFF_RESULT" | grep -q -- '-first'
printf '%s' "$GIT_DIFF_RESULT" | grep -q -- '+second'

GIT_BAD_QUOTE="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":408,"method":"tools/call","params":{"name":"git_diff","arguments":{"repo_path":"git-fixture","paths":"\"unterminated"}}}')"
printf '%s' "$GIT_BAD_QUOTE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$GIT_BAD_QUOTE" | grep -q 'Unterminated quote in Git paths'

SAFE_INIT_RESULT="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":409,"method":"tools/call","params":{"name":"git_init","arguments":{"repo_path":"safe-init-template"}}}')"
printf '%s' "$SAFE_INIT_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
if [ -e "$SERVER_ROOT/safe-init-template/.git/copied-from-template" ]; then
    echo "git_init copied an external Git template while command execution was disabled" >&2
    exit 1
fi

echo "git-tools-integration: ok"

SAFE_HOOK_REPO="$SERVER_ROOT/safe-hook-repo"
mkdir -p "$SAFE_HOOK_REPO"
git -C "$SAFE_HOOK_REPO" init -q -b main
printf 'one\n' > "$SAFE_HOOK_REPO/hook.txt"
git -C "$SAFE_HOOK_REPO" add hook.txt
git -C "$SAFE_HOOK_REPO" -c user.name=test -c user.email=test@example.com commit -qm initial
printf 'two\n' >> "$SAFE_HOOK_REPO/hook.txt"
git -C "$SAFE_HOOK_REPO" add hook.txt
HOOK_MARKER="$TMP_DIR/pre-commit-ran"
cat > "$SAFE_HOOK_REPO/.git/hooks/pre-commit" <<EOF
#!/bin/sh
printf hook > '$HOOK_MARKER'
EOF
chmod +x "$SAFE_HOOK_REPO/.git/hooks/pre-commit"
SAFE_COMMIT="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":410,"method":"tools/call","params":{"name":"git_commit","arguments":{"repo_path":"safe-hook-repo","message":"safe commit"}}}')"
printf '%s' "$SAFE_COMMIT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
if [ -e "$HOOK_MARKER" ]; then
    echo "git_commit executed a repository hook while command execution was disabled" >&2
    exit 1
fi

SAFE_FILTER_REPO="$SERVER_ROOT/safe-filter-repo"
mkdir -p "$SAFE_FILTER_REPO"
git -C "$SAFE_FILTER_REPO" init -q -b main
FILTER_MARKER="$TMP_DIR/filter-ran"
FILTER_SCRIPT="$TMP_DIR/filter-command.sh"
cat > "$FILTER_SCRIPT" <<EOF
#!/bin/sh
cat
printf filter > '$FILTER_MARKER'
EOF
chmod +x "$FILTER_SCRIPT"
git -C "$SAFE_FILTER_REPO" config filter.audit.clean "$FILTER_SCRIPT"
git -C "$SAFE_FILTER_REPO" config filter.audit.smudge cat
printf '*.txt filter=audit\n' > "$SAFE_FILTER_REPO/.gitattributes"
printf 'filtered\n' > "$SAFE_FILTER_REPO/filtered.txt"
SAFE_ADD_FILTER="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":411,"method":"tools/call","params":{"name":"git_add","arguments":{"repo_path":"safe-filter-repo","paths":"filtered.txt"}}}')"
printf '%s' "$SAFE_ADD_FILTER" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$SAFE_ADD_FILTER" | grep -q 'uses Git content filter'
if [ -e "$FILTER_MARKER" ]; then
    echo "git_add executed a content filter while command execution was disabled" >&2
    exit 1
fi

SAFE_DIFF_REPO="$SERVER_ROOT/safe-diff-repo"
mkdir -p "$SAFE_DIFF_REPO"
git -C "$SAFE_DIFF_REPO" init -q -b main
printf 'before\n' > "$SAFE_DIFF_REPO/diff.txt"
git -C "$SAFE_DIFF_REPO" add diff.txt
git -C "$SAFE_DIFF_REPO" -c user.name=test -c user.email=test@example.com commit -qm initial
printf 'after\n' > "$SAFE_DIFF_REPO/diff.txt"
DIFF_MARKER="$TMP_DIR/external-diff-ran"
DIFF_SCRIPT="$TMP_DIR/external-diff.sh"
cat > "$DIFF_SCRIPT" <<EOF
#!/bin/sh
printf diff > '$DIFF_MARKER'
EOF
chmod +x "$DIFF_SCRIPT"
git -C "$SAFE_DIFF_REPO" config diff.external "$DIFF_SCRIPT"
SAFE_DIFF="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":412,"method":"tools/call","params":{"name":"git_diff","arguments":{"repo_path":"safe-diff-repo"}}}')"
printf '%s' "$SAFE_DIFF" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$SAFE_DIFF" | grep -q -- '-before'
printf '%s' "$SAFE_DIFF" | grep -q -- '+after'
if [ -e "$DIFF_MARKER" ]; then
    echo "git_diff executed an external diff command while command execution was disabled" >&2
    exit 1
fi

OUTSIDE_WORKTREE="$TMP_DIR/outside-worktree"
SAFE_ESCAPE_REPO="$SERVER_ROOT/safe-worktree-escape"
mkdir -p "$SAFE_ESCAPE_REPO" "$OUTSIDE_WORKTREE"
git -C "$SAFE_ESCAPE_REPO" init -q -b main
printf 'inside\n' > "$SAFE_ESCAPE_REPO/escape.txt"
git -C "$SAFE_ESCAPE_REPO" add escape.txt
git -C "$SAFE_ESCAPE_REPO" -c user.name=test -c user.email=test@example.com commit -qm initial
cp "$SAFE_ESCAPE_REPO/escape.txt" "$OUTSIDE_WORKTREE/escape.txt"
git -C "$SAFE_ESCAPE_REPO" config core.worktree "$OUTSIDE_WORKTREE"
printf 'outside-worktree-secret\n' > "$OUTSIDE_WORKTREE/escape.txt"
WORKTREE_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":413,"method":"tools/call","params":{"name":"git_diff","arguments":{"repo_path":"safe-worktree-escape","paths":"escape.txt"}}}')"
printf '%s' "$WORKTREE_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$WORKTREE_ESCAPE" | grep -q 'Git worktree is outside or different'
if printf '%s' "$WORKTREE_ESCAPE" | grep -q 'outside-worktree-secret'; then
    echo "git_diff leaked content from an out-of-root core.worktree" >&2
    exit 1
fi

OUTSIDE_GITDIR="$TMP_DIR/outside-gitdir"
mkdir -p "$OUTSIDE_GITDIR/source" "$SERVER_ROOT/safe-gitdir-escape"
git -C "$OUTSIDE_GITDIR/source" init -q -b main
printf 'history-secret\n' > "$OUTSIDE_GITDIR/source/history.txt"
git -C "$OUTSIDE_GITDIR/source" add history.txt
git -C "$OUTSIDE_GITDIR/source" -c user.name=test -c user.email=test@example.com commit -qm outside-history-secret
printf 'gitdir: %s/.git\n' "$OUTSIDE_GITDIR/source" > "$SERVER_ROOT/safe-gitdir-escape/.git"
GITDIR_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":414,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"safe-gitdir-escape"}}}')"
printf '%s' "$GITDIR_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$GITDIR_ESCAPE" | grep -q 'Git directory is outside the shared directory'
if printf '%s' "$GITDIR_ESCAPE" | grep -q 'outside-history-secret'; then
    echo "git_log leaked history from an out-of-root gitdir" >&2
    exit 1
fi

SAFE_EMBEDDED_REPO="$SERVER_ROOT/safe-embedded-repo"
mkdir -p "$SAFE_EMBEDDED_REPO/nested"
git -C "$SAFE_EMBEDDED_REPO" init -q -b main
printf 'gitdir: %s/.git\n' "$OUTSIDE_GITDIR/source" > "$SAFE_EMBEDDED_REPO/nested/.git"
EMBEDDED_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":426,"method":"tools/call","params":{"name":"git_add","arguments":{"repo_path":"safe-embedded-repo","paths":"nested"}}}')"
printf '%s' "$EMBEDDED_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$EMBEDDED_ESCAPE" | grep -q 'Git directory is outside the shared directory'

SAFE_ALTERNATE_REPO="$SERVER_ROOT/safe-alternate-escape"
mkdir -p "$SAFE_ALTERNATE_REPO"
git -C "$SAFE_ALTERNATE_REPO" init -q -b main
mkdir -p "$SAFE_ALTERNATE_REPO/.git/objects/info"
printf '%s/.git/objects\n' "$OUTSIDE_GITDIR/source" > "$SAFE_ALTERNATE_REPO/.git/objects/info/alternates"
ALTERNATE_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":415,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"safe-alternate-escape"}}}')"
printf '%s' "$ALTERNATE_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$ALTERNATE_ESCAPE" | grep -q 'alternate object directory is outside the shared directory'

SAFE_QUOTED_ALTERNATE_REPO="$SERVER_ROOT/safe-quoted-alternate-escape"
mkdir -p "$SAFE_QUOTED_ALTERNATE_REPO"
git -C "$SAFE_QUOTED_ALTERNATE_REPO" init -q -b main
mkdir -p "$SAFE_QUOTED_ALTERNATE_REPO/.git/objects/info"
printf '"%s/.git/objects"\n' "$OUTSIDE_GITDIR/source" > "$SAFE_QUOTED_ALTERNATE_REPO/.git/objects/info/alternates"
QUOTED_ALTERNATE_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":419,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"safe-quoted-alternate-escape"}}}')"
printf '%s' "$QUOTED_ALTERNATE_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$QUOTED_ALTERNATE_ESCAPE" | grep -q 'quoted Git alternate object paths are not supported safely'

SAFE_ALTERNATES_METADATA_REPO="$SERVER_ROOT/safe-alternates-metadata-escape"
mkdir -p "$SAFE_ALTERNATES_METADATA_REPO"
git -C "$SAFE_ALTERNATES_METADATA_REPO" init -q -b main
OUTSIDE_ALTERNATES_INFO="$TMP_DIR/outside-alternates-info"
mkdir -p "$OUTSIDE_ALTERNATES_INFO"
printf '%s/.git/objects\n' "$OUTSIDE_GITDIR/source" > "$OUTSIDE_ALTERNATES_INFO/alternates"
rm -rf "$SAFE_ALTERNATES_METADATA_REPO/.git/objects/info"
ln -s "$OUTSIDE_ALTERNATES_INFO" "$SAFE_ALTERNATES_METADATA_REPO/.git/objects/info"
ALTERNATES_METADATA_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":420,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"safe-alternates-metadata-escape"}}}')"
printf '%s' "$ALTERNATES_METADATA_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$ALTERNATES_METADATA_ESCAPE" | grep -q 'Git alternates metadata is outside the shared directory'

SAFE_FSMONITOR_REPO="$SERVER_ROOT/safe-fsmonitor-repo"
mkdir -p "$SAFE_FSMONITOR_REPO"
git -C "$SAFE_FSMONITOR_REPO" init -q -b main
printf 'tracked\n' > "$SAFE_FSMONITOR_REPO/tracked.txt"
git -C "$SAFE_FSMONITOR_REPO" add tracked.txt
git -C "$SAFE_FSMONITOR_REPO" -c user.name=test -c user.email=test@example.com commit -qm initial
FSMONITOR_MARKER="$TMP_DIR/fsmonitor-ran"
FSMONITOR_SCRIPT="$TMP_DIR/fsmonitor.sh"
cat > "$FSMONITOR_SCRIPT" <<EOF
#!/bin/sh
printf fsmonitor > '$FSMONITOR_MARKER'
exit 0
EOF
chmod +x "$FSMONITOR_SCRIPT"
git -C "$SAFE_FSMONITOR_REPO" config core.fsmonitor "$FSMONITOR_SCRIPT"
SAFE_STATUS="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":416,"method":"tools/call","params":{"name":"git_status","arguments":{"repo_path":"safe-fsmonitor-repo"}}}')"
printf '%s' "$SAFE_STATUS" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
if [ -e "$FSMONITOR_MARKER" ]; then
    echo "git_status executed core.fsmonitor while command execution was disabled" >&2
    exit 1
fi

SAFE_CONFIG_SYMLINK_REPO="$SERVER_ROOT/safe-config-symlink"
mkdir -p "$SAFE_CONFIG_SYMLINK_REPO"
git -C "$SAFE_CONFIG_SYMLINK_REPO" init -q -b main
cp "$SAFE_CONFIG_SYMLINK_REPO/.git/config" "$TMP_DIR/outside-repo-config"
rm "$SAFE_CONFIG_SYMLINK_REPO/.git/config"
ln -s "$TMP_DIR/outside-repo-config" "$SAFE_CONFIG_SYMLINK_REPO/.git/config"
CONFIG_SYMLINK_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":425,"method":"tools/call","params":{"name":"git_status","arguments":{"repo_path":"safe-config-symlink"}}}')"
printf '%s' "$CONFIG_SYMLINK_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$CONFIG_SYMLINK_ESCAPE" | grep -q 'Git config metadata is outside the shared directory'

SAFE_CONFIG_INCLUDE_REPO="$SERVER_ROOT/safe-config-include"
mkdir -p "$SAFE_CONFIG_INCLUDE_REPO"
git -C "$SAFE_CONFIG_INCLUDE_REPO" init -q -b main
printf '[core]\n\tworktree = %s\n' "$OUTSIDE_WORKTREE" > "$TMP_DIR/outside-git-config"
git -C "$SAFE_CONFIG_INCLUDE_REPO" config include.path "$TMP_DIR/outside-git-config"
CONFIG_INCLUDE_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":423,"method":"tools/call","params":{"name":"git_status","arguments":{"repo_path":"safe-config-include"}}}')"
printf '%s' "$CONFIG_INCLUDE_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$CONFIG_INCLUDE_ESCAPE" | grep -q 'Git repository config includes are not allowed'

SAFE_GIT_SYMLINK_REPO="$SERVER_ROOT/safe-git-symlink"
mkdir -p "$SAFE_GIT_SYMLINK_REPO"
ln -s "$OUTSIDE_GITDIR/source/.git" "$SAFE_GIT_SYMLINK_REPO/.git"
GIT_SYMLINK_ESCAPE="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":424,"method":"tools/call","params":{"name":"git_log","arguments":{"repo_path":"safe-git-symlink"}}}')"
printf '%s' "$GIT_SYMLINK_ESCAPE" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$GIT_SYMLINK_ESCAPE" | grep -q '.git must be a directory or a regular gitdir metadata file'

SAFE_WORKTREE_MAIN="$SERVER_ROOT/safe-worktree-main"
SAFE_LINKED_WORKTREE="$SERVER_ROOT/safe-linked-worktree"
mkdir -p "$SAFE_WORKTREE_MAIN"
git -C "$SAFE_WORKTREE_MAIN" init -q -b main
printf 'linked\n' > "$SAFE_WORKTREE_MAIN/linked.txt"
git -C "$SAFE_WORKTREE_MAIN" add linked.txt
git -C "$SAFE_WORKTREE_MAIN" -c user.name=test -c user.email=test@example.com commit -qm initial
git -C "$SAFE_WORKTREE_MAIN" worktree add -q -b linked-branch "$SAFE_LINKED_WORKTREE"
LINKED_WORKTREE_STATUS="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":417,"method":"tools/call","params":{"name":"git_status","arguments":{"repo_path":"safe-linked-worktree"}}}')"
printf '%s' "$LINKED_WORKTREE_STATUS" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$LINKED_WORKTREE_STATUS" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx '(working tree clean)'

SAFE_CREDENTIAL_REPO="$SERVER_ROOT/safe-credential-config"
mkdir -p "$SAFE_CREDENTIAL_REPO"
git -C "$SAFE_CREDENTIAL_REPO" init -q -b main
git -C "$SAFE_CREDENTIAL_REPO" config credential.helper '!printf unsafe-helper'
CREDENTIAL_CONFIG_RESULT="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":421,"method":"tools/call","params":{"name":"git_push","arguments":{"repo_path":"safe-credential-config"}}}')"
printf '%s' "$CREDENTIAL_CONFIG_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$CREDENTIAL_CONFIG_RESULT" | grep -q 'repository-local credential helper'

SAFE_COOKIE_REPO="$SERVER_ROOT/safe-cookie-config"
mkdir -p "$SAFE_COOKIE_REPO"
git -C "$SAFE_COOKIE_REPO" init -q -b main
printf 'secret-cookie-data\n' > "$TMP_DIR/outside.cookies"
git -C "$SAFE_COOKIE_REPO" config http.cookieFile "$TMP_DIR/outside.cookies"
COOKIE_CONFIG_RESULT="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":422,"method":"tools/call","params":{"name":"git_push","arguments":{"repo_path":"safe-cookie-config"}}}')"
printf '%s' "$COOKIE_CONFIG_RESULT" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$COOKIE_CONFIG_RESULT" | grep -q "repository-controlled HTTP file setting 'http.cookiefile'"

OUTSIDE_BARE="$TMP_DIR/outside-push.git"
git init -q --bare "$OUTSIDE_BARE"
SAFE_PUSH_REPO="$SERVER_ROOT/safe-push-repo"
mkdir -p "$SAFE_PUSH_REPO"
git -C "$SAFE_PUSH_REPO" init -q -b main
printf 'push\n' > "$SAFE_PUSH_REPO/push.txt"
git -C "$SAFE_PUSH_REPO" add push.txt
git -C "$SAFE_PUSH_REPO" -c user.name=test -c user.email=test@example.com commit -qm initial
git -C "$SAFE_PUSH_REPO" remote add origin "$OUTSIDE_BARE"
git -C "$SAFE_PUSH_REPO" config branch.main.remote origin
git -C "$SAFE_PUSH_REPO" config branch.main.merge refs/heads/main
SAFE_LOCAL_PUSH="$(curl -fsS -X POST "$SAFE_BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":418,"method":"tools/call","params":{"name":"git_push","arguments":{"repo_path":"safe-push-repo"}}}')"
printf '%s' "$SAFE_LOCAL_PUSH" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$SAFE_LOCAL_PUSH" | grep -q "transport 'file' not allowed"
if git --git-dir="$OUTSIDE_BARE" show-ref --verify --quiet refs/heads/main; then
    echo "git_push wrote to an out-of-root local remote while command execution was disabled" >&2
    exit 1
fi

echo "git-safe-mode-sandbox: ok"

COMMAND_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"run_command","arguments":{"command":"printf swift-ok","timeout_seconds":5}}}')"
printf '%s' "$COMMAND_RESULT" | grep -q 'swift-ok'

printf '%s' "$COMMAND_RESULT" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -q 'exit_code: 0'

LARGE_COMMAND_RESULT="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":41,"method":"tools/call","params":{"name":"run_command","arguments":{"command":"yes x | head -c 120000","timeout_seconds":5}}}')"
printf '%s' "$LARGE_COMMAND_RESULT" | grep -q 'truncated 20000 bytes'

echo "mcp-legacy-smoke: ok"

MODERN_META='{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientInfo":{"name":"test","version":"1"},"io.modelcontextprotocol/clientCapabilities":{}}'

DISCOVER="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: server/discover' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"server/discover\",\"params\":{\"_meta\":$MODERN_META}}")"
printf '%s' "$DISCOVER" | grep -q '"supportedVersions":\["2026-07-28"\]'
printf '%s' "$DISCOVER" | grep -q '"resultType":"complete"'
printf '%s' "$DISCOVER" | grep -q '"name":"filemcp"'
printf '%s' "$DISCOVER" | grep -q 'io.modelcontextprotocol\\/serverInfo'
printf '%s' "$DISCOVER" | plutil -extract result.catalog.catalogHash raw -expect string -o - - | grep -qx "$CATALOG_HASH"
printf '%s' "$DISCOVER" | plutil -extract result.catalog.catalogVersion raw -expect string -o - - | grep -qx "$CATALOG_VERSION"
printf '%s' "$DISCOVER" | plutil -extract result.catalog.instructionVersion raw -expect string -o - - | grep -qx "$INSTRUCTION_VERSION"
printf '%s' "$DISCOVER" | plutil -extract result.catalog.buildIdentity raw -expect string -o - - | grep -qx '0.4.0-swift'

TOOLS="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/list' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"tools/list\",\"params\":{\"_meta\":$MODERN_META}}")"
printf '%s' "$TOOLS" | grep -q '"resultType":"complete"'
printf '%s' "$TOOLS" | grep -q '"cacheScope":"private"'
printf '%s' "$TOOLS" | grep -q '"name":"read_file"'
printf '%s' "$TOOLS" | grep -q '"name":"read_file_range"'
printf '%s' "$TOOLS" | grep -q '"name":"search_content"'
printf '%s' "$TOOLS" | grep -q '"outputSchema"'
printf '%s' "$TOOLS" | grep -q '"name":"filemcp_observability_connect"'
printf '%s' "$TOOLS" | grep -q '"_filemcp_chat"'
printf '%s' "$TOOLS" | plutil -extract result.catalog.catalogHash raw -expect string -o - - | grep -qx "$CATALOG_HASH"
printf '%s' "$TOOLS" | plutil -extract result.catalog.catalogVersion raw -expect string -o - - | grep -qx "$CATALOG_VERSION"
printf '%s' "$TOOLS" | plutil -extract result.catalog.instructionVersion raw -expect string -o - - | grep -qx "$INSTRUCTION_VERSION"
printf '%s' "$DISCOVER" | grep -q 'filemcp_observability_connect'
printf '%s' "$DISCOVER" | grep -q '_filemcp_chat'

MODERN_CHAT_RESUME="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/call' \
    -H 'Mcp-Name: filemcp_observability_connect' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":111,\"method\":\"tools/call\",\"params\":{\"name\":\"filemcp_observability_connect\",\"arguments\":{\"chat_instance_id\":\"$CHAT_HANDLE\"},\"_meta\":$MODERN_META}}")"
printf '%s' "$MODERN_CHAT_RESUME" | grep -q '"resultType":"complete"'
printf '%s' "$MODERN_CHAT_RESUME" | plutil -extract result.structuredContent.resumed raw -expect bool -o - - | grep -qx 'true'
echo "logical-chat-facade-modern: ok"
printf '%s' "$TOOLS" | plutil -extract result.tools.0.outputSchema.properties.result.type raw -expect string -o - - | grep -qx 'array'
printf '%s' "$TOOLS" | plutil -extract result.tools.1.outputSchema.properties.result.type raw -expect string -o - - | grep -qx 'string'
printf '%s' "$TOOLS" | plutil -extract result.tools.2.outputSchema.properties.content.type raw -expect string -o - - | grep -qx 'string'
printf '%s' "$TOOLS" | plutil -extract result.tools.0.annotations.openWorldHint raw -expect bool -o - - | grep -qx 'false'
printf '%s' "$TOOLS" | plutil -extract result.tools.5.annotations.destructiveHint raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$TOOLS" | plutil -extract result.tools.14.annotations.openWorldHint raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$TOOLS" | plutil -extract result.tools.15.annotations.openWorldHint raw -expect bool -o - - | grep -qx 'true'

MODERN_CALL="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/call' \
    -H 'Mcp-Name: =?base64?cmVhZF9maWxl?=' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"tools/call\",\"params\":{\"name\":\"read_file\",\"arguments\":{\"relative_path\":\"hello.txt\"},\"_meta\":$MODERN_META}}")"
printf '%s' "$MODERN_CALL" | grep -q 'hello swift'
printf '%s' "$MODERN_CALL" | grep -q '"resultType":"complete"'
printf '%s' "$MODERN_CALL" | plutil -extract result.structuredContent.result raw -expect string -o - - | grep -qx 'hello swift'
printf '%s' "$MODERN_CALL" | python3 -c 'import json,sys,re; d=json.load(sys.stdin); m=d["result"]["_meta"]; assert "io.modelcontextprotocol/serverInfo" in m; e=m["io.filemcp/result"]; assert e["schemaVersion"]=="1.0.0" and e["status"]=="success"; assert re.fullmatch(r"op_[0-9a-f]{32}", e["operationId"]); assert e["truncation"]=={"truncated":False,"reason":"none"}; assert e["usage"]["contentItems"]==1 and e["warnings"]==[]'


MODERN_TOOL_ERROR="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/call' \
    -H 'Mcp-Name: =?base64?cmVhZF9maWxl?=' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":121,\"method\":\"tools/call\",\"params\":{\"name\":\"read_file\",\"arguments\":{\"relative_path\":\"missing-file.txt\"},\"_meta\":$MODERN_META}}")"
printf '%s' "$MODERN_TOOL_ERROR" | plutil -extract result.isError raw -expect bool -o - - | grep -qx 'true'
printf '%s' "$MODERN_TOOL_ERROR" | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d["result"]["_meta"]; assert "io.modelcontextprotocol/serverInfo" in m; e=m["io.filemcp/result"]; assert e["schemaVersion"]=="1.0.0" and e["status"]=="tool_error"; assert e["truncation"]["truncated"] is False'

UNKNOWN_TOOL="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/call' \
    -H 'Mcp-Name: does_not_exist' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":13,\"method\":\"tools/call\",\"params\":{\"name\":\"does_not_exist\",\"arguments\":{},\"_meta\":$MODERN_META}}")"
printf '%s' "$UNKNOWN_TOOL" | grep -q '"code":-32602'
printf '%s' "$UNKNOWN_TOOL" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "error" in d and "result" not in d'

STATUS="$(curl -sS -o "$TMP_DIR/mismatch.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: tools/list-wrong' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":14,\"method\":\"tools/list\",\"params\":{\"_meta\":$MODERN_META}}")"
[ "$STATUS" = "400" ]
grep -q '"code":-32020' "$TMP_DIR/mismatch.json"

STATUS="$(curl -sS -o "$TMP_DIR/version-mismatch.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2099-01-01' \
    -H 'Mcp-Method: tools/list' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":141,\"method\":\"tools/list\",\"params\":{\"_meta\":$MODERN_META}}")"
[ "$STATUS" = "400" ]
grep -q '"code":-32020' "$TMP_DIR/version-mismatch.json"

STATUS="$(curl -sS -o "$TMP_DIR/missing-version-header.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'Mcp-Method: server/discover' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":142,\"method\":\"server/discover\",\"params\":{\"_meta\":$MODERN_META}}")"
[ "$STATUS" = "400" ]
grep -q '"code":-32020' "$TMP_DIR/missing-version-header.json"

FUTURE_META='{"io.modelcontextprotocol/protocolVersion":"2099-01-01","io.modelcontextprotocol/clientCapabilities":{}}'
STATUS="$(curl -sS -o "$TMP_DIR/version.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2099-01-01' \
    -H 'Mcp-Method: tools/list' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":15,\"method\":\"tools/list\",\"params\":{\"_meta\":$FUTURE_META}}")"
[ "$STATUS" = "400" ]
grep -q '"code":-32022' "$TMP_DIR/version.json"
grep -q '2026-07-28' "$TMP_DIR/version.json"

STATUS="$(curl -sS -o "$TMP_DIR/meta.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: ping' \
    -d '{"jsonrpc":"2.0","id":16,"method":"ping","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}')"
[ "$STATUS" = "400" ]
grep -q '"code":-32602' "$TMP_DIR/meta.json"

STATUS="$(curl -sS -o "$TMP_DIR/method.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: made/up' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":17,\"method\":\"made/up\",\"params\":{\"_meta\":$MODERN_META}}")"
[ "$STATUS" = "404" ]
grep -q '"code":-32601' "$TMP_DIR/method.json"

STATUS="$(curl -sS -o "$TMP_DIR/origin.txt" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Origin: https://evil.example' \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":18,"method":"ping","params":{}}')"
[ "$STATUS" = "403" ]
grep -q 'Forbidden origin' "$TMP_DIR/origin.txt"

STATUS="$(curl -sS -o "$TMP_DIR/origin-port.txt" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Origin: https://chatgpt.com:444' \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":180,"method":"ping","params":{}}')"
[ "$STATUS" = "403" ]
grep -q 'Forbidden origin' "$TMP_DIR/origin-port.txt"

STATUS="$(curl -sS -o "$TMP_DIR/origin-path.txt" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Origin: https://chatgpt.com/not-an-origin' \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":179,"method":"ping","params":{}}')"
[ "$STATUS" = "403" ]
grep -q 'Forbidden origin' "$TMP_DIR/origin-path.txt"

STATUS="$(curl -sS -o "$TMP_DIR/host.txt" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Host: evil.example' \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":181,"method":"ping","params":{}}')"
[ "$STATUS" = "403" ]
grep -q 'Forbidden host' "$TMP_DIR/host.txt"

STATUS="$(curl -sS -o "$TMP_DIR/content-type.txt" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: text/plain' \
    -d '{"jsonrpc":"2.0","id":182,"method":"ping","params":{}}')"
[ "$STATUS" = "415" ]
grep -q 'Content-Type must be application/json' "$TMP_DIR/content-type.txt"

MALFORMED_CLIENT_META='{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientInfo":"bad","io.modelcontextprotocol/clientCapabilities":{}}'
STATUS="$(curl -sS -o "$TMP_DIR/client-info.json" -w '%{http_code}' -X POST "$BASE_URL" \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: ping' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":183,\"method\":\"ping\",\"params\":{\"_meta\":$MALFORMED_CLIENT_META}}")"
[ "$STATUS" = "400" ]
grep -q '"code":-32602' "$TMP_DIR/client-info.json"
grep -q 'Invalid _meta.io.modelcontextprotocol.*clientInfo' "$TMP_DIR/client-info.json"

ALLOWED_ORIGIN="$(curl -fsS -X POST "$BASE_URL" \
    -H 'Origin: https://chatgpt.com' \
    -H 'Content-Type: application/json' \
    -H 'MCP-Protocol-Version: 2026-07-28' \
    -H 'Mcp-Method: ping' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":19,\"method\":\"ping\",\"params\":{\"_meta\":$MODERN_META}}")"
printf '%s' "$ALLOWED_ORIGIN" | grep -q '"resultType":"complete"'

echo "mcp-modern-2026-07-28: ok"

stop_server
