using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json.Nodes;
using FileMCP.Core;

namespace FileMCP.Core.Tests;

internal static class Program
{
    private static int _assertions;

    public static async Task<int> Main(string[] args)
    {
        if (args.Length > 0 && args[0] is "init" or "doctor" or "run")
            return await RunFakeTunnelClientAsync(args);

        if (!OperatingSystem.IsWindows())
        {
            Console.WriteLine("windows-tests: skipped (Windows required)");
            return 0;
        }

        var root = Path.Combine(Path.GetTempPath(), "filemcp-windows-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            TestObservabilityContracts();
            await TestWorkspaceUsageMeterAsync();
            await TestSettingsAndCredentialsAsync(root);
            await TestProcessRunnerAsync(root);
            await TestFilesystemAndToolsAsync(root);
            await TestGitSafetyAsync(root);
            await TestHttpAndMcpAsync(root);
            await TestRuntimeAsync(root);
            Console.WriteLine($"windows-core-tests: ok ({_assertions} assertions)");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            var annotation = ex.ToString()
                .Replace("%", "%25", StringComparison.Ordinal)
                .Replace("\r", "%0D", StringComparison.Ordinal)
                .Replace("\n", "%0A", StringComparison.Ordinal);
            Console.Error.WriteLine($"::error file=windows/tests/FileMCP.Core.Tests/Program.cs,title=Windows integration failure::{annotation}");
            return 1;
        }
        finally
        {
            try { Directory.Delete(root, true); } catch { }
        }
    }

    private static void TestObservabilityContracts()
    {
        Assert(McpTokenEstimator.EstimatorId == "bytes_div_4_v1", "token estimator id");
        Assert(McpTokenEstimator.EstimateFromUtf8Bytes(0) == 0, "token estimate zero");
        Assert(McpTokenEstimator.EstimateFromUtf8Bytes(1) == 1, "token estimate one byte");
        Assert(McpTokenEstimator.EstimateFromUtf8Bytes(4) == 1, "token estimate four bytes");
        Assert(McpTokenEstimator.EstimateFromUtf8Bytes(5) == 2, "token estimate rounds up");
        Assert(McpTokenEstimator.EstimateFromUtf8Bytes(long.MaxValue) > 0, "token estimate avoids overflow");
        try
        {
            _ = McpTokenEstimator.EstimateFromUtf8Bytes(-1);
            throw new Exception("Assertion failed: negative token bytes rejected");
        }
        catch (ArgumentOutOfRangeException)
        {
            Assert(true, "negative token bytes rejected");
        }

        var cases = new (string Name, ToolUsageCategory Category, bool Task)[]
        {
            ("list_files", ToolUsageCategory.Read, false),
            ("read_file", ToolUsageCategory.Read, false),
            ("read_file_range", ToolUsageCategory.Read, false),
            ("search_content", ToolUsageCategory.Read, false),
            ("search_filenames", ToolUsageCategory.Read, false),
            ("write_file", ToolUsageCategory.Write, true),
            ("delete_file", ToolUsageCategory.Write, true),
            ("delete_directory", ToolUsageCategory.Write, true),
            ("run_command", ToolUsageCategory.Command, true),
            ("git_init", ToolUsageCategory.Git, true),
            ("git_status", ToolUsageCategory.Git, false),
            ("git_log", ToolUsageCategory.Git, false),
            ("git_diff", ToolUsageCategory.Git, false),
            ("git_add", ToolUsageCategory.Git, true),
            ("git_commit", ToolUsageCategory.Git, true),
            ("git_push", ToolUsageCategory.Git, true),
            ("list_codex_skills", ToolUsageCategory.Skill, false),
            ("load_codex_skill", ToolUsageCategory.Skill, false),
        };
        foreach (var item in cases)
        {
            var classification = ToolUsageClassifier.Classify(item.Name);
            Assert(classification.IsKnownTool, $"classifier knows {item.Name}");
            Assert(classification.Category == item.Category, $"classifier category {item.Name}");
            Assert(classification.IsExecutionTask == item.Task, $"classifier task flag {item.Name}");
        }
        var unknown = ToolUsageClassifier.Classify("future_tool");
        Assert(!unknown.IsKnownTool && unknown.Category == ToolUsageCategory.Other && !unknown.IsExecutionTask, "classifier unknown tool");
        var nullTool = ToolUsageClassifier.Classify(null);
        Assert(!nullTool.IsKnownTool && nullTool.Category == ToolUsageCategory.Other, "classifier null tool");

        var counters = new UsageCounters(1, 2, 3, 10, 20, 3, 5, 0, 1, 1, 0, 0, 0, 0, 7, 4);
        Assert(counters.TotalPayloadBytes == 30, "usage counters total bytes");
        Assert(counters.TotalTokensEst == 8, "usage counters total token estimate");
        Console.WriteLine("windows-observability-contracts: ok");
    }
    private static async Task TestWorkspaceUsageMeterAsync()
    {
        var meter = new WorkspaceUsageMeter("d");
        Assert(meter.WorkspaceKey == "D", "usage meter normalizes workspace key");
        meter.RecordRequest(5);
        meter.RecordResponse(9);
        meter.RecordToolCall("write_file", isError: true, latencyTicks: 7);
        var first = meter.Snapshot();
        Assert(first.McpRequests == 1 && first.ToolCalls == 1 && first.ExecutionTasks == 1, "usage meter basic counts");
        Assert(first.RequestBytes == 5 && first.ResponseBytes == 9, "usage meter basic bytes");
        Assert(first.TokensInEst == 2 && first.TokensOutEst == 3, "usage meter basic token estimates");
        Assert(first.Errors == 1 && first.WriteCalls == 1, "usage meter basic category and error");
        Assert(first.TotalLatencyTicks == 7 && first.MaxLatencyTicks == 7, "usage meter basic latency");
        var firstDelta = meter.DrainDelta();
        Assert(firstDelta == first, "usage meter first delta equals first lifetime snapshot");
        Assert(meter.DrainDelta().IsZero, "usage meter drain resets pending only");
        Assert(meter.Snapshot() == first, "usage meter drain preserves lifetime snapshot");

        var concurrent = new WorkspaceUsageMeter("E");
        const int workers = 8;
        const int perWorker = 2_000;
        var done = 0;
        UsageCounters drained = default;
        var drainTask = Task.Run(async () =>
        {
            var total = default(UsageCounters);
            while (Volatile.Read(ref done) == 0)
            {
                total += concurrent.DrainDelta();
                await Task.Yield();
            }
            total += concurrent.DrainDelta();
            drained = total;
        });

        var producers = Enumerable.Range(0, workers).Select(_ => Task.Run(() =>
        {
            for (var i = 0; i < perWorker; i++)
            {
                concurrent.RecordRequest(5);
                concurrent.RecordResponse(9);
                concurrent.RecordToolCall("write_file", i % 10 == 0, (i % 17) + 1);
            }
        })).ToArray();
        await Task.WhenAll(producers);
        Volatile.Write(ref done, 1);
        await drainTask;

        var expectedCalls = workers * perWorker;
        var errorsPerWorker = ((perWorker - 1) / 10) + 1;
        var latencyPerWorker = Enumerable.Range(0, perWorker).Sum(i => (long)((i % 17) + 1));
        var lifetime = concurrent.Snapshot();
        Assert(lifetime.McpRequests == expectedCalls, "usage meter concurrent request count");
        Assert(lifetime.ToolCalls == expectedCalls && lifetime.ExecutionTasks == expectedCalls, "usage meter concurrent tool/task count");
        Assert(lifetime.RequestBytes == expectedCalls * 5L && lifetime.ResponseBytes == expectedCalls * 9L, "usage meter concurrent bytes");
        Assert(lifetime.TokensInEst == expectedCalls * 2L && lifetime.TokensOutEst == expectedCalls * 3L, "usage meter concurrent token estimates");
        Assert(lifetime.Errors == workers * errorsPerWorker, "usage meter concurrent errors");
        Assert(lifetime.WriteCalls == expectedCalls && lifetime.ReadCalls == 0 && lifetime.OtherCalls == 0, "usage meter concurrent category");
        Assert(lifetime.TotalLatencyTicks == workers * latencyPerWorker && lifetime.MaxLatencyTicks == 17, "usage meter concurrent latency");
        Assert(drained == lifetime, "usage meter concurrent drains lose no increments");
        Assert(concurrent.DrainDelta().IsZero, "usage meter pending empty after concurrent drain");

        var defensive = new WorkspaceUsageMeter("F");
        defensive.RecordRequest(-1);
        defensive.RecordResponse(-2);
        defensive.RecordToolCall(null, false, -3);
        var defensiveSnapshot = defensive.Snapshot();
        Assert(defensiveSnapshot.McpRequests == 1 && defensiveSnapshot.RequestBytes == 0 && defensiveSnapshot.ResponseBytes == 0, "usage meter clamps invalid byte metrics without breaking request path");
        Assert(defensiveSnapshot.ToolCalls == 1 && defensiveSnapshot.OtherCalls == 1 && defensiveSnapshot.TotalLatencyTicks == 0, "usage meter defensive unknown tool/latency");
        Console.WriteLine("windows-observability-meter: ok");
    }
    private static Task TestSettingsAndCredentialsAsync(string root)
    {
        var settingsDir = Path.Combine(root, "settings");
        var store = new SettingsStore(settingsDir);
        var settings = new FileMcpSettings
        {
            TunnelId = "tunnel_" + new string('a', 32), Profile = "windows-test", Port = 18080,
            AllowedDirectory = Path.Combine(root, "workspace"), HealthAddress = "127.0.0.1:0",
            GitUserName = "FileMCP Test", GitUserEmail = "filemcp@example.invalid", EnableCommands = true,
        };
        store.Save(settings); var loaded = store.Load();
        Assert(loaded.TunnelId == settings.TunnelId && loaded.Profile == settings.Profile && loaded.EnableCommands, "settings roundtrip");
        Assert(loaded.Workspaces.Count == 4 && loaded.Workspaces.Select(item => item.Key).SequenceEqual(new[] { "C", "D", "E", "F" }), "multi-workspace defaults");
        Assert(loaded.Workspaces.Count(item => item.Enabled) == 1 && loaded.Workspaces.Any(item => item.Enabled && item.AllowedDirectory == settings.AllowedDirectory), "legacy workspace mapped to matching drive");
        Assert(loaded.Workspaces.Select(item => item.Port).Distinct().Count() == 4, "workspace ports unique");
        Assert(loaded.Workspaces.Select(item => item.Profile).Distinct(StringComparer.OrdinalIgnoreCase).Count() == 4, "workspace profiles unique");
        Assert(!File.ReadAllText(Path.Combine(settingsDir, "settings.json")).Contains("apiKey", StringComparison.OrdinalIgnoreCase), "settings contain no API key");

        var target = "FileMCP/tests/" + Guid.NewGuid().ToString("N");
        var credentials = new WindowsCredentialStore(target);
        try
        {
            credentials.SaveApiKey("sk-test-filemcp");
            Assert(credentials.HasSavedApiKey, "credential exists");
            Assert(credentials.ReadApiKey() == "sk-test-filemcp", "credential roundtrip");
            credentials.DeleteApiKey();
            Assert(!credentials.HasSavedApiKey, "credential delete");
        }
        finally { try { credentials.DeleteApiKey(); } catch { } }
        Console.WriteLine("windows-settings-credentials: ok");
        return Task.CompletedTask;
    }

    private static async Task TestProcessRunnerAsync(string root)
    {
        var timeout = await ProcessRunner.RunAsync("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 10"], timeoutSeconds: 1);
        Assert(timeout.TimedOut, "process timeout");

        var bounded = await ProcessRunner.RunAsync("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "'x' * 150000"], timeoutSeconds: 5, outputLimitBytes: 10_000);
        Assert(bounded.Stdout.Contains("[...truncated ", StringComparison.Ordinal), "bounded process output");

        var pidFile = Path.Combine(root, "child.pid");
        var escaped = pidFile.Replace("'", "''", StringComparison.Ordinal);
        var script = "$p=Start-Process powershell.exe -ArgumentList '-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 20' -PassThru; Set-Content -LiteralPath '" + escaped + "' -Value $p.Id";
        var parent = await ProcessRunner.RunAsync("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script], timeoutSeconds: 5);
        Assert(parent.ExitCode == 0 && File.Exists(pidFile), "descendant fixture");
        await Task.Delay(500);
        var childPid = int.Parse(File.ReadAllText(pidFile).Trim());
        var childAlive = false;
        try { using var child = Process.GetProcessById(childPid); childAlive = !child.HasExited; } catch (ArgumentException) { }
        Assert(!childAlive, "job object descendant cleanup");
        Console.WriteLine("windows-process-runner: ok");
    }

    private static async Task TestFilesystemAndToolsAsync(string root)
    {
        var workspace = Path.Combine(root, "files"); Directory.CreateDirectory(workspace);
        var safe = new LocalTools(workspace, "FileMCP Test", "filemcp@example.invalid", false);
        var full = new LocalTools(workspace, "FileMCP Test", "filemcp@example.invalid", true);
        Assert(safe.ToolDefinitions.Count == 15 && !safe.HasTool("run_command"), "safe tool count");
        Assert(full.ToolDefinitions.Count == 16 && full.HasTool("run_command"), "full tool count");

        var volumeRoot = Path.GetPathRoot(workspace) ?? throw new Exception("Workspace volume root unavailable");
        var volumeSafe = new LocalTools(volumeRoot, "FileMCP Test", "filemcp@example.invalid", false);
        var volumeFull = new LocalTools(volumeRoot, "FileMCP Test", "filemcp@example.invalid", true);
        var volumeWorkspace = Path.GetRelativePath(volumeRoot, workspace).Replace('\\', '/');
        var volumeFile = volumeWorkspace + "/volume-root.txt";
        await volumeSafe.CallAsync("write_file", Obj(("relative_path", volumeFile), ("content", "volume-root-ok\n")));
        var volumeRead = await volumeSafe.CallAsync("read_file", Obj(("relative_path", volumeFile)));
        Assert(volumeRead.StructuredContent["result"]!.GetValue<string>().Contains("volume-root-ok"), "volume-root read/write descendant");
        var volumeList = await volumeSafe.CallAsync("list_files", Obj(("subpath", volumeWorkspace)));
        Assert(volumeList.StructuredContent["result"]!.AsArray().Any(n => n!.GetValue<string>() == "volume-root.txt"), "volume-root list descendant");
        var volumeSearch = await volumeSafe.CallAsync("search_content", Obj(("query", "volume-root-ok"), ("path", volumeWorkspace)));
        Assert(volumeSearch.StructuredContent["matches"]!.AsArray().Count == 1, "volume-root search descendant");
        var volumeCommand = await volumeFull.CallAsync("run_command", Obj(("command", "Write-Output volume-root-command-ok"), ("cwd", volumeWorkspace), ("timeout_seconds", 5)));
        Assert(volumeCommand.StructuredContent["result"]!.GetValue<string>().Contains("volume-root-command-ok"), "volume-root command cwd descendant");
        await AssertThrowsAsync(() => volumeSafe.CallAsync("delete_directory", Obj(("relative_path", ""))), "shared root directory", "volume-root deletion refused");
        await volumeSafe.CallAsync("delete_file", Obj(("relative_path", volumeFile)));

        await safe.CallAsync("write_file", Obj(("relative_path", "docs/note.txt"), ("content", "alpha\nbeta\ngamma\n")));
        var read = await safe.CallAsync("read_file", Obj(("relative_path", "docs/note.txt")));
        Assert(read.StructuredContent["result"]!.GetValue<string>().Contains("beta"), "read file");
        var range = await safe.CallAsync("read_file_range", Obj(("relative_path", "docs/note.txt"), ("start_line", 2), ("end_line", 3)));
        Assert(range.StructuredContent["content"]!.GetValue<string>() == "beta\ngamma", "read range");
        var search = await safe.CallAsync("search_content", Obj(("query", "beta"), ("path", "docs")));
        Assert(search.StructuredContent["matches"]!.AsArray().Count == 1, "search content");
        var names = await safe.CallAsync("search_filenames", Obj(("query", "note")));
        Assert(names.StructuredContent["result"]!.AsArray().Count == 1, "search filename");
        var list = await safe.CallAsync("list_files", Obj(("subpath", "docs")));
        Assert(list.StructuredContent["result"]!.AsArray().Any(n => n!.GetValue<string>() == "note.txt"), "list files");

        await full.CallAsync("run_command", Obj(("command", "Write-Output windows-command-ok"), ("cwd", ""), ("timeout_seconds", 5)));
        var command = await full.CallAsync("run_command", Obj(("command", "Write-Output windows-command-ok"), ("timeout_seconds", 5)));
        Assert(command.StructuredContent["result"]!.GetValue<string>().Contains("windows-command-ok"), "run command");

        await AssertThrowsAsync(() => safe.CallAsync("read_file", Obj(("relative_path", "..\\outside.txt"))), "outside the shared directory", "lexical traversal refused");

        var outside = Path.Combine(root, "outside"); Directory.CreateDirectory(outside); File.WriteAllText(Path.Combine(outside, "secret.txt"), "outside-secret");
        var junction = Path.Combine(workspace, "escape");
        var mklink = await ProcessRunner.RunAsync("cmd.exe", ["/d", "/c", "mklink", "/J", junction, outside], timeoutSeconds: 5);
        Assert(mklink.ExitCode == 0, $"junction fixture: exit={mklink.ExitCode} stdout={mklink.Stdout} stderr={mklink.Stderr}");
        await AssertThrowsAsync(() => safe.CallAsync("read_file", Obj(("relative_path", "escape/secret.txt"))), "outside the shared directory", "junction read refused");
        await AssertThrowsAsync(() => safe.CallAsync("delete_directory", Obj(("relative_path", "escape"))), "Use delete_file", "junction directory delete refused");
        await safe.CallAsync("delete_file", Obj(("relative_path", "escape")));
        Assert(!Directory.Exists(junction) && File.Exists(Path.Combine(outside, "secret.txt")), "junction delete removes link only");
        await safe.CallAsync("delete_file", Obj(("relative_path", "docs/note.txt")));
        await safe.CallAsync("delete_directory", Obj(("relative_path", "docs")));
        Assert(!Directory.Exists(Path.Combine(workspace, "docs")), "delete directory");
        Console.WriteLine("windows-filesystem-tools: ok");
    }

    private static async Task TestGitSafetyAsync(string root)
    {
        var gitVersion = await ProcessRunner.RunAsync("git.exe", ["--version"], timeoutSeconds: 10);
        Assert(gitVersion.ExitCode == 0, "git available");
        var workspace = Path.Combine(root, "git"); Directory.CreateDirectory(workspace);
        var tools = new LocalTools(workspace, "FileMCP Test", "filemcp@example.invalid", false);
        await tools.CallAsync("git_init", Obj(("repo_path", "repo")));
        await tools.CallAsync("write_file", Obj(("relative_path", "repo/a.txt"), ("content", "one\n")));
        await tools.CallAsync("git_add", Obj(("repo_path", "repo"), ("paths", "a.txt")));
        await tools.CallAsync("git_commit", Obj(("repo_path", "repo"), ("message", "initial")));
        var log = await tools.CallAsync("git_log", Obj(("repo_path", "repo"), ("count", 5)));
        Assert(log.StructuredContent["result"]!.GetValue<string>().Contains("initial"), "git log");

        var repo = Path.Combine(workspace, "repo");
        var hooksDirectory = Path.Combine(repo, ".git", "hooks");
        Directory.CreateDirectory(hooksDirectory);
        var hook = Path.Combine(hooksDirectory, "pre-commit");
        File.WriteAllText(hook, "#!/bin/sh\ntouch hook-ran\n", new UTF8Encoding(false));
        File.AppendAllText(Path.Combine(repo, "a.txt"), "two\n");
        await tools.CallAsync("git_add", Obj(("repo_path", "repo"), ("paths", "a.txt")));
        await tools.CallAsync("git_commit", Obj(("repo_path", "repo"), ("message", "safe commit")));
        Assert(!File.Exists(Path.Combine(repo, "hook-ran")), "git hooks suppressed");

        await GitCli(repo, ["config", "filter.audit.clean", "cat"]);
        await GitCli(repo, ["config", "filter.audit.smudge", "cat"]);
        File.WriteAllText(Path.Combine(repo, ".gitattributes"), "*.filter filter=audit\n");
        File.WriteAllText(Path.Combine(repo, "blocked.filter"), "filtered\n");
        await AssertThrowsAsync(() => tools.CallAsync("git_add", Obj(("repo_path", "repo"), ("paths", "blocked.filter"))), "content filter", "git filter refused");

        var include = Path.Combine(root, "outside-gitconfig"); File.WriteAllText(include, "[user]\nname = outside\n");
        await GitCli(repo, ["config", "include.path", include]);
        await AssertThrowsAsync(() => tools.CallAsync("git_status", Obj(("repo_path", "repo"))), "config includes", "git config include refused");
        await GitCli(repo, ["config", "--unset-all", "include.path"]);

        var linkedMain = Path.Combine(workspace, "linked-main");
        var linkedWorktree = Path.Combine(workspace, "linked-worktree");
        Directory.CreateDirectory(linkedMain);
        await GitCli(linkedMain, ["init", "-b", "main"]);
        File.WriteAllText(Path.Combine(linkedMain, "linked.txt"), "linked\n");
        await GitCli(linkedMain, ["add", "linked.txt"]);
        await GitCli(linkedMain, ["-c", "user.name=FileMCP Test", "-c", "user.email=filemcp@example.invalid", "commit", "-m", "linked initial"]);
        await GitCli(linkedMain, ["worktree", "add", "-b", "linked-branch", linkedWorktree]);
        var linkedStatus = await tools.CallAsync("git_status", Obj(("repo_path", "linked-worktree")));
        Assert(linkedStatus.StructuredContent["result"]!.GetValue<string>() == "(working tree clean)", "linked worktree inside shared root");

        var escapeRepo = Path.Combine(workspace, "worktree-escape");
        var outsideWorktree = Path.Combine(root, "outside-worktree");
        Directory.CreateDirectory(escapeRepo); Directory.CreateDirectory(outsideWorktree);
        await GitCli(escapeRepo, ["init", "-b", "main"]);
        await GitCli(escapeRepo, ["config", "core.worktree", outsideWorktree]);
        await AssertThrowsAsync(() => tools.CallAsync("git_status", Obj(("repo_path", "worktree-escape"))), "worktree is outside or different", "core.worktree escape refused");

        var bare = Path.Combine(root, "outside.git");
        var initBare = await ProcessRunner.RunAsync("git.exe", ["init", "--bare", bare], timeoutSeconds: 20); Assert(initBare.ExitCode == 0, "bare remote fixture");
        await GitCli(repo, ["remote", "add", "origin", bare]);
        await GitCli(repo, ["config", "branch.main.remote", "origin"]); await GitCli(repo, ["config", "branch.main.merge", "refs/heads/main"]);
        await AssertThrowsAsync(() => tools.CallAsync("git_push", Obj(("repo_path", "repo"))), "transport 'file' not allowed", "local file push refused");
        Console.WriteLine("windows-git-safe-mode: ok");
    }

    private static async Task TestHttpAndMcpAsync(string root)
    {
        var workspace = Path.Combine(root, "http"); Directory.CreateDirectory(workspace); File.WriteAllText(Path.Combine(workspace, "hello.txt"), "hello");
        var port = FreePort(); var token = new string('a', 64);
        await using var server = new LocalMcpServer((ushort)port, workspace, "", "", false, token, _ => { });
        await server.StartAsync();

        var fuzzIterations = int.TryParse(Environment.GetEnvironmentVariable("MCP_HTTP_FUZZ_ITERATIONS"), out var configuredFuzz) ? Math.Max(1, configuredFuzz) : 160;
        var random = new Random(0xF11E);
        for (var index = 0; index < fuzzIterations; index++)
        {
            var bytes = new byte[random.Next(0, 2048)];
            random.NextBytes(bytes);
            _ = server.ParseHttpRequest(bytes);
        }
        Assert(true, $"HTTP malformed fuzz ({fuzzIterations} iterations)");
        var authBeforeBodyRequest = Encoding.ASCII.GetBytes(
            $"POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nContent-Length: 1000000\r\n\r\n");
        var authBeforeBody = server.ParseHttpRequest(authBeforeBodyRequest);
        Assert(authBeforeBody.Status == HttpParseStatus.Failure && authBeforeBody.FailureStatus == 401, "local auth rejected before request body");

        var unauthorized = await SendHttpAsync(port, "POST", "/mcp", new Dictionary<string, string> { ["Content-Type"] = "application/json" }, "");
        Assert(unauthorized.StartsWith("HTTP/1.1 401 Unauthorized", StringComparison.Ordinal), "local auth required");

        var discoveryPath = await SendHttpAsync(port, "GET", "/.well-known/oauth-protected-resource/mcp", new Dictionary<string, string>(), "");
        Assert(discoveryPath.StartsWith("HTTP/1.1 404 Not Found", StringComparison.Ordinal) && HttpBody(discoveryPath) == "Not found", "OAuth discovery path is public and not advertised");

        var discoveryRoot = await SendHttpAsync(port, "GET", "/.well-known/oauth-protected-resource", new Dictionary<string, string>(), "");
        Assert(discoveryRoot.StartsWith("HTTP/1.1 404 Not Found", StringComparison.Ordinal), "OAuth discovery root is public and not advertised");

        var unauthorizedUnknownPath = await SendHttpAsync(port, "GET", "/not-found", new Dictionary<string, string>(), "");
        Assert(unauthorizedUnknownPath.StartsWith("HTTP/1.1 401 Unauthorized", StringComparison.Ordinal), "unknown paths still require local auth");

        var unauthorizedDiscoveryPost = await SendHttpAsync(port, "POST", "/.well-known/oauth-protected-resource/mcp", new Dictionary<string, string>(), "");
        Assert(unauthorizedDiscoveryPost.StartsWith("HTTP/1.1 401 Unauthorized", StringComparison.Ordinal), "only GET OAuth discovery bypasses local auth");

        var legacy = await SendHttpAsync(port, "POST", "/mcp", AuthHeaders(token), "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}");
        var legacyBody = JsonNode.Parse(HttpBody(legacy))!.AsObject();
        var legacyTools = legacyBody["result"]!["tools"]!.AsArray();
        Assert(legacyTools.Count == 17, "legacy tools list");
        Assert(legacyTools.Any(t => t!["name"]!.GetValue<string>() == "list_codex_skills"), "legacy list_codex_skills exposed");
        Assert(legacyTools.Any(t => t!["name"]!.GetValue<string>() == "load_codex_skill"), "legacy load_codex_skill exposed");

        var skillDir = Path.Combine(workspace, ".agents", "skills", "speckit-analyze");
        Directory.CreateDirectory(skillDir);
        File.WriteAllText(Path.Combine(skillDir, "SKILL.md"), "---\nname: speckit-analyze\ndescription: Analyze the current spec.\n---\n\n# Analyze\nFollow this skill exactly.\n", new UTF8Encoding(false));
        var loadSkill = await SendHttpAsync(port, "POST", "/mcp", AuthHeaders(token), "{\"jsonrpc\":\"2.0\",\"id\":21,\"method\":\"tools/call\",\"params\":{\"name\":\"load_codex_skill\",\"arguments\":{\"name\":\"speckit-analyze\"}}}");
        var loadedSkillBody = JsonNode.Parse(HttpBody(loadSkill))!.AsObject();
        var loadedSkill = loadedSkillBody["result"]!["structuredContent"]!.AsObject();
        Assert(loadedSkill["name"]!.GetValue<string>() == "speckit-analyze", "load skill name");
        Assert(loadedSkill["instructions"]!.GetValue<string>().Contains("Follow this skill exactly.", StringComparison.Ordinal), "load skill instructions");

        var invalidSkill = await SendHttpAsync(port, "POST", "/mcp", AuthHeaders(token), "{\"jsonrpc\":\"2.0\",\"id\":22,\"method\":\"tools/call\",\"params\":{\"name\":\"load_codex_skill\",\"arguments\":{\"name\":\"../escape\"}}}");
        var invalidSkillBody = JsonNode.Parse(HttpBody(invalidSkill))!.AsObject();
        Assert(invalidSkillBody["result"]!["isError"]!.GetValue<bool>(), "unsafe skill name refused");

        var modernHeaders = AuthHeaders(token); modernHeaders["MCP-Protocol-Version"] = FileMcpConstants.ModernProtocolVersion; modernHeaders["Mcp-Method"] = "tools/list";
        var modernBody = new JsonObject
        {
            ["jsonrpc"] = "2.0", ["id"] = 3, ["method"] = "tools/list",
            ["params"] = new JsonObject { ["_meta"] = new JsonObject { ["io.modelcontextprotocol/protocolVersion"] = FileMcpConstants.ModernProtocolVersion, ["io.modelcontextprotocol/clientCapabilities"] = new JsonObject(), ["io.modelcontextprotocol/clientInfo"] = new JsonObject { ["name"] = "test", ["version"] = "1" } } },
        };
        var modern = await SendHttpAsync(port, "POST", "/mcp", modernHeaders, modernBody.ToJsonString());
        var modernJson = JsonNode.Parse(HttpBody(modern))!.AsObject();
        Assert(modernJson["result"]!["resultType"]!.GetValue<string>() == "complete", "modern result type");
        Assert(modernJson["result"]!["tools"]!.AsArray().Count == 17, "modern tools list");

        var badHost = await SendHttpAsync(port, "POST", "/mcp", AuthHeaders(token), "", host: "evil.example");
        Assert(badHost.StartsWith("HTTP/1.1 403 Forbidden", StringComparison.Ordinal), "host validation");
        Console.WriteLine("windows-http-mcp: ok");
    }

    private static async Task TestRuntimeAsync(string root)
    {
        var workspace = Path.Combine(root, "runtime-workspace"); Directory.CreateDirectory(workspace);
        var profiles = Path.Combine(root, "runtime-profiles"); var capture = Path.Combine(root, "tunnel-env.txt");
        Environment.SetEnvironmentVariable("MCP_TUNNEL_CLIENT", Environment.ProcessPath);
        Environment.SetEnvironmentVariable("MCP_TEST_ENV_CAPTURE", capture);
        Environment.SetEnvironmentVariable("LOG_HTTP_RAW_UNSAFE", "true");
        Environment.SetEnvironmentVariable("MCP_SERVER_URL", "http://evil.invalid/mcp");
        var runtime = new LocalMcpRuntime(profiles); var logs = new StringBuilder(); runtime.Log += text => logs.Append(text);
        try
        {
            var config = new LocalMcpConfiguration("tunnel_" + new string('b', 32), "sk-runtime-test-secret", "runtime-test", (ushort)FreePort(), workspace, "127.0.0.1:0", "", "", false);
            await runtime.StartAsync(config);
            Assert(runtime.State.Status == LocalMcpRuntimeStatus.Running, "runtime running");
            Assert(File.Exists(Path.Combine(profiles, "runtime-test.yaml")), "isolated profile created");
            var captureText = File.ReadAllText(capture);
            Assert(captureText.Contains("X-FileMCP-Local-Token: env:FILEMCP_LOCAL_AUTH_TOKEN"), "local auth header env indirection");
            Assert(!captureText.Contains("LOG_HTTP_RAW_UNSAFE=true", StringComparison.Ordinal) && !captureText.Contains("MCP_SERVER_URL=http://evil", StringComparison.Ordinal), "dangerous tunnel env not inherited");
            Assert(!logs.ToString().Contains("sk-runtime-test-secret", StringComparison.Ordinal), "api key redacted");
            Assert(!System.Text.RegularExpressions.Regex.IsMatch(logs.ToString(), "[0-9a-f]{64}"), "local token redacted");
            Assert(logs.ToString().Contains("[Skills]", StringComparison.Ordinal), "skill scan logged on connect");
            await runtime.StopAsync();
            Assert(runtime.State.Status == LocalMcpRuntimeStatus.Stopped, "runtime stopped");
        }
        finally
        {
            await runtime.DisposeAsync();
            Environment.SetEnvironmentVariable("MCP_TUNNEL_CLIENT", null); Environment.SetEnvironmentVariable("MCP_TEST_ENV_CAPTURE", null);
            Environment.SetEnvironmentVariable("LOG_HTTP_RAW_UNSAFE", null); Environment.SetEnvironmentVariable("MCP_SERVER_URL", null);
        }
        Console.WriteLine("windows-runtime-lifecycle: ok");
    }

    private static async Task<int> RunFakeTunnelClientAsync(string[] args)
    {
        var capture = Environment.GetEnvironmentVariable("MCP_TEST_ENV_CAPTURE");
        if (!string.IsNullOrEmpty(capture))
        {
            var text = string.Join('\n', new[]
            {
                "MCP_EXTRA_HEADERS=" + Environment.GetEnvironmentVariable("MCP_EXTRA_HEADERS"),
                "MCP_DISCOVERY_EXTRA_HEADERS=" + Environment.GetEnvironmentVariable("MCP_DISCOVERY_EXTRA_HEADERS"),
                "FILEMCP_LOCAL_AUTH_TOKEN=" + Environment.GetEnvironmentVariable("FILEMCP_LOCAL_AUTH_TOKEN"),
                "LOG_HTTP_RAW_UNSAFE=" + Environment.GetEnvironmentVariable("LOG_HTTP_RAW_UNSAFE"),
                "MCP_SERVER_URL=" + Environment.GetEnvironmentVariable("MCP_SERVER_URL"),
            });
            File.WriteAllText(capture, text);
        }
        var token = Environment.GetEnvironmentVariable("FILEMCP_LOCAL_AUTH_TOKEN") ?? ""; var apiKey = Environment.GetEnvironmentVariable("CONTROL_PLANE_API_KEY") ?? "";
        if (args[0] == "init")
        {
            var profile = ValueAfter(args, "--profile"); var profileDir = ValueAfter(args, "--profile-dir");
            Directory.CreateDirectory(profileDir); File.WriteAllText(Path.Combine(profileDir, profile + ".yaml"), "control_plane:\n  api_key: env:CONTROL_PLANE_API_KEY\n");
            Console.WriteLine("init-ok " + apiKey + " " + token); return 0;
        }
        if (args[0] == "doctor") { Console.WriteLine("doctor-ok " + apiKey + " " + token); return 0; }
        Console.WriteLine("run-ok " + apiKey + " " + token);
        await Task.Delay(Timeout.InfiniteTimeSpan); return 0;
    }

    private static string ValueAfter(string[] args, string key) { var index = Array.IndexOf(args, key); return index >= 0 && index + 1 < args.Length ? args[index + 1] : throw new InvalidOperationException("missing " + key); }
    private static async Task GitCli(string repo, string[] args) { var all = new List<string> { "-C", repo }; all.AddRange(args); var result = await ProcessRunner.RunAsync("git.exe", all, timeoutSeconds: 20); if (result.ExitCode != 0) throw new Exception("git fixture failed: " + result.Stderr); }
    private static JsonObject Obj(params (string Key, object Value)[] values) { var obj = new JsonObject(); foreach (var (key, value) in values) obj[key] = JsonValue.Create(value); return obj; }
    private static void Assert(bool condition, string message) { _assertions++; if (!condition) throw new Exception("Assertion failed: " + message); }
    private static async Task AssertThrowsAsync(Func<Task> action, string contains, string message) { try { await action(); } catch (Exception ex) when (ex.Message.Contains(contains, StringComparison.OrdinalIgnoreCase)) { Assert(true, message); return; } throw new Exception("Assertion failed: " + message); }
    private static int FreePort() { var listener = new TcpListener(IPAddress.Loopback, 0); listener.Start(); var port = ((IPEndPoint)listener.LocalEndpoint).Port; listener.Stop(); return port; }
    private static Dictionary<string, string> AuthHeaders(string token) => new(StringComparer.OrdinalIgnoreCase) { ["Content-Type"] = "application/json", [FileMcpConstants.LocalAuthHeaderName] = token };
    private static async Task<string> SendHttpAsync(int port, string method, string path, Dictionary<string, string> headers, string body, string? host = null)
    {
        var bytes = Encoding.UTF8.GetBytes(body); using var client = new TcpClient(); await client.ConnectAsync(IPAddress.Loopback, port); var stream = client.GetStream();
        var builder = new StringBuilder($"{method} {path} HTTP/1.1\r\nHost: {host ?? $"127.0.0.1:{port}"}\r\n"); foreach (var pair in headers) builder.Append(pair.Key).Append(": ").Append(pair.Value).Append("\r\n"); builder.Append("Content-Length: ").Append(bytes.Length).Append("\r\n\r\n");
        var head = Encoding.UTF8.GetBytes(builder.ToString()); await stream.WriteAsync(head); await stream.WriteAsync(bytes); client.Client.Shutdown(SocketShutdown.Send);
        using var memory = new MemoryStream(); var buffer = new byte[8192]; int read; while ((read = await stream.ReadAsync(buffer)) > 0) memory.Write(buffer, 0, read); return Encoding.UTF8.GetString(memory.ToArray());
    }
    private static string HttpBody(string response) { var index = response.IndexOf("\r\n\r\n", StringComparison.Ordinal); return index >= 0 ? response[(index + 4)..] : response; }
}
