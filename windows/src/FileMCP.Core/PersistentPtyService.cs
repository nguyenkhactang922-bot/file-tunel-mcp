using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Win32.SafeHandles;

namespace FileMCP.Core;

internal sealed class PersistentPtyOptions
{
    public int MaxSessions { get; init; } = 8;
    public int MaxRingBytes { get; init; } = 1 * 1024 * 1024;
    public int SpillChunkBytes { get; init; } = 128 * 1024;
    public TimeSpan DefaultIdleTtl { get; init; } = TimeSpan.FromMinutes(10);
    public TimeSpan MaxIdleTtl { get; init; } = TimeSpan.FromHours(1);
    public TimeSpan DefaultMaxLifetime { get; init; } = TimeSpan.FromHours(1);
    public TimeSpan MaxLifetime { get; init; } = TimeSpan.FromHours(4);
    public TimeSpan SpillTtl { get; init; } = TimeSpan.FromMinutes(15);
}

internal interface IPtyNativeHost : IAsyncDisposable
{
    int ProcessId { get; }
    bool IsRunning { get; }
    Stream Input { get; }
    Stream Output { get; }
    Task<int> WaitForExitAsync();
    void Resize(int columns, int rows);
    Task SignalAsync(string signal, CancellationToken cancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
}

internal sealed class PersistentPtyService : IAsyncDisposable
{
    private readonly SafePathResolver _resolver;
    private readonly ExecProcessEnvironmentAuthority _environmentAuthority;
    private readonly Func<ArtifactContentStore> _artifactFactory;
    private readonly Func<string, IReadOnlyList<string>, string, IReadOnlyDictionary<string, string>, int, int, IPtyNativeHost> _hostFactory;
    private readonly PersistentPtyOptions _options;
    private readonly string _workspaceAuthorityId;
    private readonly Dictionary<string, Session> _sessions = new(StringComparer.Ordinal);
    private readonly object _gate = new();
    private readonly Timer _sweeper;
    private bool _disposed;

    internal PersistentPtyService(
        SafePathResolver resolver,
        ExecProcessEnvironmentAuthority environmentAuthority,
        Func<ArtifactContentStore> artifactFactory,
        PersistentPtyOptions? options = null,
        Func<string, IReadOnlyList<string>, string, IReadOnlyDictionary<string, string>, int, int, IPtyNativeHost>? hostFactory = null)
    {
        _resolver = resolver;
        _environmentAuthority = environmentAuthority;
        _artifactFactory = artifactFactory;
        _options = options ?? new PersistentPtyOptions();
        ValidateOptions(_options);
        _workspaceAuthorityId = ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root);
        _hostFactory = hostFactory ?? ((exe, args, cwd, env, columns, rows) =>
        {
            if (!OperatingSystem.IsWindows())
                throw new FileMcpException("Windows ConPTY host is unavailable on this platform");
            return WindowsConPtyHost.Start(exe, args, cwd, env, columns, rows);
        });
        _sweeper = new Timer(_ => _ = SweepAsync(), null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
    }

    internal async Task<JsonObject> StartAsync(
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> environmentOverrides,
        int columns,
        int rows,
        int idleTtlSeconds,
        int maxLifetimeSeconds,
        bool spillOutput,
        CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        cancellationToken.ThrowIfCancellationRequested();
        await SweepAsync().ConfigureAwait(false);

        if (string.IsNullOrWhiteSpace(executable) || executable.Contains('\0'))
            throw new FileMcpException("PTY executable must be a non-empty string without NUL bytes");
        if (arguments.Count > 256 || arguments.Any(item => item.Contains('\0')))
            throw new FileMcpException("PTY arguments are invalid or exceed 256 entries");
        ValidateSize(columns, rows);

        var workingDirectory = _resolver.Resolve(cwd);
        if (!Directory.Exists(workingDirectory))
            throw new FileMcpException($"No such PTY working directory: {(string.IsNullOrEmpty(cwd) ? "." : cwd)}");

        var idleTtl = ResolveTtl(idleTtlSeconds, _options.DefaultIdleTtl, _options.MaxIdleTtl, "idle_ttl_seconds");
        var maxLifetime = ResolveTtl(maxLifetimeSeconds, _options.DefaultMaxLifetime, _options.MaxLifetime, "max_lifetime_seconds");
        var environment = _environmentAuthority.Build(environmentOverrides);

        lock (_gate)
        {
            if (_sessions.Values.Count(s => !s.Terminal) >= _options.MaxSessions)
                throw new FileMcpException($"PTY session limit reached ({_options.MaxSessions})");
        }

        var host = _hostFactory(executable, arguments, workingDirectory, environment, columns, rows);
        var id = "pty_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(18)).ToLowerInvariant();
        var now = DateTimeOffset.UtcNow;
        var session = new Session(
            id,
            host,
            now,
            idleTtl,
            maxLifetime,
            _options,
            spillOutput,
            _workspaceAuthorityId,
            _artifactFactory);

        lock (_gate) _sessions.Add(id, session);
        session.Start();

        return new JsonObject
        {
            ["session_id"] = id,
            ["pid"] = host.ProcessId,
            ["state"] = "running",
            ["columns"] = columns,
            ["rows"] = rows,
            ["idle_ttl_seconds"] = (int)idleTtl.TotalSeconds,
            ["max_lifetime_seconds"] = (int)maxLifetime.TotalSeconds,
            ["ring_limit_bytes"] = _options.MaxRingBytes,
            ["spill_output"] = spillOutput,
            ["actual_pty"] = true,
            ["pty_backend"] = "windows-conpty",
            ["grants_authority"] = false,
        };
    }

    internal async Task<JsonObject> ReadAsync(
        string sessionId,
        string cursor,
        int maxBytes,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var session = GetSession(sessionId);
        if (maxBytes is < 1 or > 256 * 1024)
            throw new FileMcpException("PTY max_bytes must be 1..262144");
        if (context is not null && !context.TryContinue())
            throw new OperationCanceledException("PTY read cancelled or budget exhausted", context.CancellationToken);
        cancellationToken.ThrowIfCancellationRequested();

        var requested = string.IsNullOrEmpty(cursor)
            ? session.EarliestOffset
            : ParseCursor(cursor);
        var result = await session.ReadAsync(requested, maxBytes, cancellationToken).ConfigureAwait(false);
        if (context is not null && !context.TryOutputItem())
            context.MarkTruncated("output_items");

        var spillRefs = new JsonArray();
        foreach (var item in result.SpillRefs) spillRefs.Add(item);

        return new JsonObject
        {
            ["session_id"] = sessionId,
            ["state"] = result.State,
            ["start_cursor"] = Cursor(result.StartOffset),
            ["next_cursor"] = Cursor(result.NextOffset),
            ["earliest_cursor"] = Cursor(result.EarliestOffset),
            ["end_cursor"] = Cursor(result.EndOffset),
            ["cursor_evicted"] = result.CursorEvicted,
            ["data_base64"] = Convert.ToBase64String(result.Bytes),
            ["text"] = Encoding.UTF8.GetString(result.Bytes),
            ["exit_code"] = result.ExitCode,
            ["spill_pending"] = result.SpillPending,
            ["spill_refs"] = spillRefs,
            ["grants_authority"] = false,
        };
    }

    internal async Task<JsonObject> WriteAsync(string sessionId, string data, CancellationToken cancellationToken)
    {
        var session = GetSession(sessionId);
        if (data.Length > 64 * 1024) throw new FileMcpException("PTY write is limited to 65536 characters per call");
        cancellationToken.ThrowIfCancellationRequested();
        var bytes = Encoding.UTF8.GetBytes(data);
        await session.WriteAsync(bytes, cancellationToken).ConfigureAwait(false);
        return new JsonObject
        {
            ["session_id"] = sessionId,
            ["written_bytes"] = bytes.Length,
            ["state"] = session.State,
            ["grants_authority"] = false,
        };
    }

    internal JsonObject Resize(string sessionId, int columns, int rows)
    {
        ValidateSize(columns, rows);
        var session = GetSession(sessionId);
        session.Resize(columns, rows);
        return new JsonObject
        {
            ["session_id"] = sessionId,
            ["columns"] = columns,
            ["rows"] = rows,
            ["state"] = session.State,
            ["grants_authority"] = false,
        };
    }

    internal async Task<JsonObject> SignalAsync(string sessionId, string signal, CancellationToken cancellationToken)
    {
        var session = GetSession(sessionId);
        if (signal is not ("ctrl_c" or "terminate"))
            throw new FileMcpException("PTY signal must be ctrl_c or terminate");
        await session.SignalAsync(signal, cancellationToken).ConfigureAwait(false);
        return new JsonObject
        {
            ["session_id"] = sessionId,
            ["signal"] = signal,
            ["state"] = session.State,
            ["grants_authority"] = false,
        };
    }

    internal async Task<JsonObject> StopAsync(string sessionId, CancellationToken cancellationToken)
    {
        var session = GetSession(sessionId);
        await session.StopAsync("stopped", cancellationToken).ConfigureAwait(false);
        return session.Metadata();
    }

    internal JsonObject List()
    {
        Session[] snapshot;
        lock (_gate) snapshot = _sessions.Values.OrderBy(s => s.CreatedUtc).ToArray();
        return new JsonObject
        {
            ["sessions"] = new JsonArray(snapshot.Select(s => (JsonNode)s.Metadata()).ToArray()),
            ["count"] = snapshot.Length,
            ["workspace_scoped"] = true,
            ["restart_resume_supported"] = false,
            ["grants_authority"] = false,
        };
    }

    internal async Task StopAllAsync()
    {
        Session[] snapshot;
        lock (_gate) snapshot = _sessions.Values.ToArray();
        foreach (var session in snapshot)
        {
            try { await session.StopAsync("server_stopped", CancellationToken.None).ConfigureAwait(false); }
            catch { }
        }
    }

    internal Task SweepNowForTestsAsync() => SweepAsync();

    private Session GetSession(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Length > 128)
            throw new FileMcpException("Invalid PTY session id");
        lock (_gate)
        {
            if (!_sessions.TryGetValue(id, out var session))
                throw new FileMcpException("Unknown or expired PTY session");
            session.Touch();
            return session;
        }
    }

    private async Task SweepAsync()
    {
        if (_disposed) return;
        Session[] snapshot;
        lock (_gate) snapshot = _sessions.Values.ToArray();
        var now = DateTimeOffset.UtcNow;
        foreach (var session in snapshot)
        {
            if (session.Terminal)
            {
                if (now - session.LastActivityUtc > TimeSpan.FromMinutes(2))
                {
                    lock (_gate) _sessions.Remove(session.Id);
                    await session.DisposeAsync().ConfigureAwait(false);
                }
                continue;
            }
            if (now - session.LastActivityUtc > session.IdleTtl)
                await session.StopAsync("idle_expired", CancellationToken.None).ConfigureAwait(false);
            else if (now - session.CreatedUtc > session.MaxLifetime)
                await session.StopAsync("lifetime_expired", CancellationToken.None).ConfigureAwait(false);
        }
    }

    private static TimeSpan ResolveTtl(int seconds, TimeSpan fallback, TimeSpan maximum, string name)
    {
        if (seconds == 0) return fallback;
        if (seconds < 1 || seconds > (int)maximum.TotalSeconds)
            throw new FileMcpException($"{name} must be 1..{(int)maximum.TotalSeconds}");
        return TimeSpan.FromSeconds(seconds);
    }

    private static void ValidateSize(int columns, int rows)
    {
        if (columns is < 1 or > 500 || rows is < 1 or > 300)
            throw new FileMcpException("PTY size must be columns 1..500 and rows 1..300");
    }

    private static long ParseCursor(string cursor)
    {
        if (!long.TryParse(cursor, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out var value) || value < 0)
            throw new FileMcpException("Invalid PTY cursor");
        return value;
    }

    private static string Cursor(long value) => value.ToString(System.Globalization.CultureInfo.InvariantCulture);

    private static void ValidateOptions(PersistentPtyOptions options)
    {
        if (options.MaxSessions is < 1 or > 32) throw new ArgumentOutOfRangeException(nameof(options.MaxSessions));
        if (options.MaxRingBytes is < 64 * 1024 or > 8 * 1024 * 1024) throw new ArgumentOutOfRangeException(nameof(options.MaxRingBytes));
        if (options.SpillChunkBytes is < 16 * 1024 || options.SpillChunkBytes > options.MaxRingBytes) throw new ArgumentOutOfRangeException(nameof(options.SpillChunkBytes));
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(PersistentPtyService));
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        _sweeper.Dispose();
        await StopAllAsync().ConfigureAwait(false);
        Session[] snapshot;
        lock (_gate)
        {
            snapshot = _sessions.Values.ToArray();
            _sessions.Clear();
        }
        foreach (var session in snapshot) await session.DisposeAsync().ConfigureAwait(false);
    }

    private sealed class Session : IAsyncDisposable
    {
        private readonly IPtyNativeHost _host;
        private readonly PersistentPtyOptions _options;
        private readonly bool _spillOutput;
        private readonly string _workspaceAuthorityId;
        private readonly Func<ArtifactContentStore> _artifactFactory;
        private readonly object _gate = new();
        private readonly List<byte> _ring = [];
        private readonly List<byte> _spillAccumulator = [];
        private readonly List<string> _spillRefs = [];
        private readonly List<Task> _spillTasks = [];
        private readonly CancellationTokenSource _readerCts = new();
        private Task? _readerTask;
        private Task? _waitTask;
        private long _baseOffset;
        private long _endOffset;
        private int? _exitCode;
        private string _state = "running";
        private bool _disposed;

        internal Session(
            string id,
            IPtyNativeHost host,
            DateTimeOffset createdUtc,
            TimeSpan idleTtl,
            TimeSpan maxLifetime,
            PersistentPtyOptions options,
            bool spillOutput,
            string workspaceAuthorityId,
            Func<ArtifactContentStore> artifactFactory)
        {
            Id = id;
            _host = host;
            CreatedUtc = createdUtc;
            LastActivityUtc = createdUtc;
            IdleTtl = idleTtl;
            MaxLifetime = maxLifetime;
            _options = options;
            _spillOutput = spillOutput;
            _workspaceAuthorityId = workspaceAuthorityId;
            _artifactFactory = artifactFactory;
        }

        internal string Id { get; }
        internal DateTimeOffset CreatedUtc { get; }
        internal DateTimeOffset LastActivityUtc { get; private set; }
        internal TimeSpan IdleTtl { get; }
        internal TimeSpan MaxLifetime { get; }
        internal bool Terminal { get { lock (_gate) return _state != "running"; } }
        internal string State { get { lock (_gate) return _state; } }
        internal long EarliestOffset { get { lock (_gate) return _baseOffset; } }

        internal void Start()
        {
            _readerTask = Task.Run(ReadLoopAsync);
            _waitTask = Task.Run(WaitLoopAsync);
        }

        internal void Touch() { lock (_gate) LastActivityUtc = DateTimeOffset.UtcNow; }

        private async Task ReadLoopAsync()
        {
            var buffer = new byte[16 * 1024];
            try
            {
                while (!_readerCts.IsCancellationRequested)
                {
                    var read = await _host.Output.ReadAsync(buffer.AsMemory(), _readerCts.Token).ConfigureAwait(false);
                    if (read <= 0) break;
                    await AppendAsync(buffer.AsMemory(0, read), _readerCts.Token).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException) { }
            catch (ObjectDisposedException) { }
            catch (IOException) { }
        }

        private async Task WaitLoopAsync()
        {
            int code;
            try { code = await _host.WaitForExitAsync().ConfigureAwait(false); }
            catch { code = -1; }
            lock (_gate)
            {
                _exitCode = code;
                if (_state == "running") _state = "exited";
                LastActivityUtc = DateTimeOffset.UtcNow;
            }
            await FlushSpillAsync(CancellationToken.None).ConfigureAwait(false);
        }

        private async Task AppendAsync(ReadOnlyMemory<byte> data, CancellationToken cancellationToken)
        {
            byte[]? spill = null;
            long spillStart = 0;
            lock (_gate)
            {
                LastActivityUtc = DateTimeOffset.UtcNow;
                var appended = data.ToArray();
                _ring.AddRange(appended);
                _endOffset += appended.Length;
                var overflow = Math.Max(0, _ring.Count - _options.MaxRingBytes);
                if (overflow > 0)
                {
                    if (_spillOutput)
                    {
                        spillStart = _baseOffset;
                        _spillAccumulator.AddRange(_ring.GetRange(0, overflow));
                    }
                    _ring.RemoveRange(0, overflow);
                    _baseOffset += overflow;
                    if (_spillOutput && _spillAccumulator.Count >= _options.SpillChunkBytes)
                    {
                        spill = _spillAccumulator.ToArray();
                        _spillAccumulator.Clear();
                    }
                }
            }
            if (spill is not null)
            {
                var task = SpillAsync(spill, spillStart, cancellationToken);
                lock (_gate) _spillTasks.Add(task);
                await task.ConfigureAwait(false);
            }
        }

        private async Task SpillAsync(byte[] bytes, long startOffset, CancellationToken cancellationToken)
        {
            try
            {
                await using var input = new MemoryStream(bytes, writable: false);
                var descriptor = await _artifactFactory().PutAsync(
                    input,
                    _workspaceAuthorityId,
                    ArtifactContentClasses.PtyOutput,
                    "application/octet-stream",
                    _options.SpillTtl,
                    leaseId: Id,
                    leaseTtl: _options.SpillTtl,
                    cancellationToken: cancellationToken).ConfigureAwait(false);
                lock (_gate) _spillRefs.Add(descriptor.ContentRef);
            }
            catch
            {
                // Spill is best-effort. The bounded RAM ring remains authoritative for live reads.
            }
        }

        internal async Task<PtyReadResult> ReadAsync(long requestedOffset, int maxBytes, CancellationToken cancellationToken)
        {
            await Task.Yield();
            cancellationToken.ThrowIfCancellationRequested();
            lock (_gate)
            {
                LastActivityUtc = DateTimeOffset.UtcNow;
                if (requestedOffset > _endOffset) throw new FileMcpException("PTY cursor is beyond current output");
                var evicted = requestedOffset < _baseOffset;
                var effective = Math.Max(requestedOffset, _baseOffset);
                var index = checked((int)(effective - _baseOffset));
                var count = Math.Min(maxBytes, _ring.Count - index);
                var bytes = count > 0 ? _ring.GetRange(index, count).ToArray() : [];
                var next = effective + count;
                return new PtyReadResult(
                    bytes,
                    effective,
                    next,
                    _baseOffset,
                    _endOffset,
                    evicted,
                    _state,
                    _exitCode,
                    _spillRefs.ToArray(),
                    _spillTasks.Any(t => !t.IsCompleted));
            }
        }

        internal async Task WriteAsync(byte[] bytes, CancellationToken cancellationToken)
        {
            if (Terminal) throw new FileMcpException("PTY session is not running");
            Touch();
            await _host.Input.WriteAsync(bytes.AsMemory(), cancellationToken).ConfigureAwait(false);
            await _host.Input.FlushAsync(cancellationToken).ConfigureAwait(false);
        }

        internal void Resize(int columns, int rows)
        {
            if (Terminal) throw new FileMcpException("PTY session is not running");
            Touch();
            _host.Resize(columns, rows);
        }

        internal async Task SignalAsync(string signal, CancellationToken cancellationToken)
        {
            if (Terminal) throw new FileMcpException("PTY session is not running");
            Touch();
            await _host.SignalAsync(signal, cancellationToken).ConfigureAwait(false);
        }

        internal async Task StopAsync(string state, CancellationToken cancellationToken)
        {
            bool shouldStop;
            lock (_gate)
            {
                shouldStop = _state == "running";
                if (shouldStop) _state = state;
                LastActivityUtc = DateTimeOffset.UtcNow;
            }
            if (shouldStop)
            {
                try { await _host.StopAsync(cancellationToken).ConfigureAwait(false); } catch { }
            }
            await FlushSpillAsync(CancellationToken.None).ConfigureAwait(false);
            await DeleteSpillsAsync().ConfigureAwait(false);
        }

        private async Task FlushSpillAsync(CancellationToken cancellationToken)
        {
            byte[]? tail = null;
            lock (_gate)
            {
                if (_spillOutput && _spillAccumulator.Count > 0)
                {
                    tail = _spillAccumulator.ToArray();
                    _spillAccumulator.Clear();
                }
            }
            if (tail is not null)
            {
                var task = SpillAsync(tail, _baseOffset - tail.Length, cancellationToken);
                lock (_gate) _spillTasks.Add(task);
            }
            Task[] tasks;
            lock (_gate) tasks = _spillTasks.ToArray();
            try { await Task.WhenAll(tasks).ConfigureAwait(false); } catch { }
        }

        private async Task DeleteSpillsAsync()
        {
            string[] refs;
            lock (_gate) refs = _spillRefs.ToArray();
            foreach (var contentRef in refs)
            {
                try
                {
                    await _artifactFactory().DeleteAsync(
                        contentRef,
                        _workspaceAuthorityId,
                        ArtifactContentClasses.IsKnown,
                        CancellationToken.None).ConfigureAwait(false);
                }
                catch { }
            }
            lock (_gate) _spillRefs.Clear();
        }

        internal JsonObject Metadata()
        {
            lock (_gate)
            {
                return new JsonObject
                {
                    ["session_id"] = Id,
                    ["pid"] = _host.ProcessId,
                    ["state"] = _state,
                    ["created_epoch_ms"] = CreatedUtc.ToUnixTimeMilliseconds(),
                    ["last_activity_epoch_ms"] = LastActivityUtc.ToUnixTimeMilliseconds(),
                    ["earliest_cursor"] = Cursor(_baseOffset),
                    ["end_cursor"] = Cursor(_endOffset),
                    ["exit_code"] = _exitCode,
                    ["spill_ref_count"] = _spillRefs.Count,
                    ["actual_pty"] = true,
                    ["restart_resume_supported"] = false,
                    ["grants_authority"] = false,
                };
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (_disposed) return;
            _disposed = true;
            _readerCts.Cancel();
            try { await StopAsync("disposed", CancellationToken.None).ConfigureAwait(false); } catch { }
            if (_readerTask is not null) try { await _readerTask.ConfigureAwait(false); } catch { }
            if (_waitTask is not null) try { await _waitTask.ConfigureAwait(false); } catch { }
            await _host.DisposeAsync().ConfigureAwait(false);
            _readerCts.Dispose();
        }
    }

    private sealed record PtyReadResult(
        byte[] Bytes,
        long StartOffset,
        long NextOffset,
        long EarliestOffset,
        long EndOffset,
        bool CursorEvicted,
        string State,
        int? ExitCode,
        IReadOnlyList<string> SpillRefs,
        bool SpillPending);
}

internal sealed class WindowsConPtyHost : IPtyNativeHost
{
    private readonly IntPtr _pseudoConsole;
    private readonly SafeFileHandle _processHandle;
    private readonly SafeFileHandle _jobHandle;
    private readonly FileStream _input;
    private readonly FileStream _output;
    private readonly Task<int> _waitTask;
    private int _stopped;

    private WindowsConPtyHost(
        IntPtr pseudoConsole,
        SafeFileHandle processHandle,
        SafeFileHandle jobHandle,
        int processId,
        FileStream input,
        FileStream output)
    {
        _pseudoConsole = pseudoConsole;
        _processHandle = processHandle;
        _jobHandle = jobHandle;
        ProcessId = processId;
        _input = input;
        _output = output;
        _waitTask = Task.Run(WaitCore);
    }

    public int ProcessId { get; }
    public bool IsRunning => !_waitTask.IsCompleted;
    public Stream Input => _input;
    public Stream Output => _output;
    public Task<int> WaitForExitAsync() => _waitTask;

    internal static WindowsConPtyHost Start(
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> environment,
        int columns,
        int rows)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException();

        SafeFileHandle? inputRead = null;
        SafeFileHandle? inputWrite = null;
        SafeFileHandle? outputRead = null;
        SafeFileHandle? outputWrite = null;
        IntPtr pseudoConsole = IntPtr.Zero;
        IntPtr attributeList = IntPtr.Zero;
        SafeFileHandle? processHandle = null;
        SafeFileHandle? jobHandle = null;

        try
        {
            if (!Native.CreatePipe(out inputRead, out inputWrite, IntPtr.Zero, 0) ||
                !Native.CreatePipe(out outputRead, out outputWrite, IntPtr.Zero, 0))
                ThrowLast("Could not create ConPTY pipes");

            var hr = Native.CreatePseudoConsole(new Native.Coord((short)columns, (short)rows),
                inputRead!.DangerousGetHandle(), outputWrite!.DangerousGetHandle(), 0, out pseudoConsole);
            if (hr != 0) throw new FileMcpException($"CreatePseudoConsole failed: 0x{hr:x8}");

            IntPtr attrSize = IntPtr.Zero;
            _ = Native.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attrSize);
            attributeList = Marshal.AllocHGlobal(attrSize);
            if (!Native.InitializeProcThreadAttributeList(attributeList, 1, 0, ref attrSize))
                ThrowLast("Could not initialize ConPTY process attributes");
            if (!Native.UpdateProcThreadAttribute(
                    attributeList, 0, (IntPtr)Native.ProcThreadAttributePseudoConsole,
                    pseudoConsole, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                ThrowLast("Could not bind ConPTY process attribute");

            var startup = new Native.StartupInfoEx
            {
                // Match the Windows Terminal ConPTY launch contract: explicitly
                // request standard-handle setup while leaving hStd* zero so the
                // pseudoconsole supplies the attached client's terminal handles
                // instead of preserving redirected parent stdio.
                StartupInfo = new Native.StartupInfo
                {
                    cb = Marshal.SizeOf<Native.StartupInfoEx>(),
                    dwFlags = Native.StartfUseStdHandles,
                },
                lpAttributeList = attributeList,
            };
            var commandLine = new StringBuilder(BuildCommandLine(executable, arguments));
            var environmentBlock = BuildEnvironmentBlock(environment);
            var envPtr = Marshal.StringToHGlobalUni(environmentBlock);
            try
            {
                var flags = Native.ExtendedStartupInfoPresent | Native.CreateUnicodeEnvironment | Native.CreateSuspended;
                if (!Native.CreateProcessW(
                        null, commandLine, IntPtr.Zero, IntPtr.Zero, false, flags,
                        envPtr, cwd, ref startup, out var pi))
                    ThrowLast($"Could not launch PTY process {executable}");

                // The ConPTY-side pipe handles must remain alive until after the
                // attached child is created. Close them now; ConHost owns its copies.
                inputRead?.Dispose(); inputRead = null;
                outputWrite?.Dispose(); outputWrite = null;

                processHandle = new SafeFileHandle(pi.hProcess, ownsHandle: true);
                using var threadHandle = new SafeFileHandle(pi.hThread, ownsHandle: true);
                jobHandle = CreateKillOnCloseJob();
                if (!Native.AssignProcessToJobObject(jobHandle, processHandle))
                    ThrowLast("Could not assign PTY process to ownership job");
                if (Native.ResumeThread(threadHandle) == uint.MaxValue)
                    ThrowLast("Could not resume PTY process");

                var input = new FileStream(inputWrite!, FileAccess.Write, 16 * 1024, isAsync: false);
                inputWrite = null;
                var output = new FileStream(outputRead!, FileAccess.Read, 16 * 1024, isAsync: false);
                outputRead = null;
                return new WindowsConPtyHost(
                    pseudoConsole,
                    processHandle!,
                    jobHandle!,
                    unchecked((int)pi.dwProcessId),
                    input,
                    output);
            }
            finally
            {
                Marshal.FreeHGlobal(envPtr);
            }
        }
        catch (EntryPointNotFoundException)
        {
            throw new FileMcpException("Windows ConPTY is unavailable on this Windows build; redirected stdio fallback is intentionally refused");
        }
        catch
        {
            if (pseudoConsole != IntPtr.Zero) Native.ClosePseudoConsole(pseudoConsole);
            processHandle?.Dispose();
            jobHandle?.Dispose();
            inputRead?.Dispose();
            inputWrite?.Dispose();
            outputRead?.Dispose();
            outputWrite?.Dispose();
            throw;
        }
        finally
        {
            if (attributeList != IntPtr.Zero)
            {
                Native.DeleteProcThreadAttributeList(attributeList);
                Marshal.FreeHGlobal(attributeList);
            }
        }
    }

    public void Resize(int columns, int rows)
    {
        var hr = Native.ResizePseudoConsole(_pseudoConsole, new Native.Coord((short)columns, (short)rows));
        if (hr != 0) throw new FileMcpException($"ResizePseudoConsole failed: 0x{hr:x8}");
    }

    public async Task SignalAsync(string signal, CancellationToken cancellationToken)
    {
        if (signal == "terminate")
        {
            await StopAsync(cancellationToken).ConfigureAwait(false);
            return;
        }

        // ETX is interpreted by the console host as Ctrl+C for the attached terminal.
        await _input.WriteAsync(new byte[] { 0x03 }, cancellationToken).ConfigureAwait(false);
        await _input.FlushAsync(cancellationToken).ConfigureAwait(false);
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        if (Interlocked.Exchange(ref _stopped, 1) == 0)
            _ = Native.TerminateJobObject(_jobHandle, 1);
        return Task.CompletedTask;
    }

    private int WaitCore()
    {
        _ = Native.WaitForSingleObject(_processHandle, Native.Infinite);
        if (!Native.GetExitCodeProcess(_processHandle, out var code)) return -1;
        return unchecked((int)code);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync(CancellationToken.None).ConfigureAwait(false);
        try { _input.Dispose(); } catch { }
        try { _output.Dispose(); } catch { }
        if (_pseudoConsole != IntPtr.Zero) Native.ClosePseudoConsole(_pseudoConsole);
        _jobHandle.Dispose();
        _processHandle.Dispose();
    }

    private static SafeFileHandle CreateKillOnCloseJob()
    {
        var handle = Native.CreateJobObjectW(IntPtr.Zero, null);
        if (handle.IsInvalid) ThrowLast("Could not create PTY ownership job");
        var info = new Native.JobObjectExtendedLimitInformation
        {
            BasicLimitInformation = new Native.JobObjectBasicLimitInformation
            {
                LimitFlags = Native.JobObjectLimitKillOnJobClose,
            },
        };
        var size = Marshal.SizeOf<Native.JobObjectExtendedLimitInformation>();
        var ptr = Marshal.AllocHGlobal(size);
        try
        {
            Marshal.StructureToPtr(info, ptr, false);
            if (!Native.SetInformationJobObject(handle, 9, ptr, (uint)size))
                ThrowLast("Could not configure PTY ownership job");
        }
        finally { Marshal.FreeHGlobal(ptr); }
        return handle;
    }

    private static string BuildEnvironmentBlock(IReadOnlyDictionary<string, string> environment)
    {
        return string.Join('\0', environment.OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase).Select(p => p.Key + "=" + p.Value)) + "\0\0";
    }

    private static string BuildCommandLine(string executable, IReadOnlyList<string> arguments)
    {
        return string.Join(" ", new[] { QuoteWindowsArgument(executable) }.Concat(arguments.Select(QuoteWindowsArgument)));
    }

    private static string QuoteWindowsArgument(string value)
    {
        if (value.Length == 0) return "\"\"";
        if (!value.Any(ch => char.IsWhiteSpace(ch) || ch == '"')) return value;
        var sb = new StringBuilder("\"");
        var slashes = 0;
        foreach (var ch in value)
        {
            if (ch == '\\') { slashes++; continue; }
            if (ch == '"')
            {
                sb.Append('\\', slashes * 2 + 1).Append('"');
                slashes = 0;
                continue;
            }
            sb.Append('\\', slashes).Append(ch);
            slashes = 0;
        }
        sb.Append('\\', slashes * 2).Append('"');
        return sb.ToString();
    }

    private static void ThrowLast(string message)
    {
        var error = Marshal.GetLastWin32Error();
        throw new FileMcpException($"{message}: {new Win32Exception(error).Message}");
    }

    private static class Native
    {
        internal const long ProcThreadAttributePseudoConsole = 0x00020016;
        internal const uint ExtendedStartupInfoPresent = 0x00080000;
        internal const uint CreateUnicodeEnvironment = 0x00000400;
        internal const uint CreateSuspended = 0x00000004;
        internal const uint CreateNewProcessGroup = 0x00000200;
        internal const int StartfUseStdHandles = 0x00000100;
        internal const uint JobObjectLimitKillOnJobClose = 0x00002000;
        internal const uint Infinite = 0xFFFFFFFF;

        [StructLayout(LayoutKind.Sequential)]
        internal readonly struct Coord
        {
            internal readonly short X;
            internal readonly short Y;
            internal Coord(short x, short y) { X = x; Y = y; }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct StartupInfo
        {
            internal int cb;
            internal string? lpReserved;
            internal string? lpDesktop;
            internal string? lpTitle;
            internal int dwX;
            internal int dwY;
            internal int dwXSize;
            internal int dwYSize;
            internal int dwXCountChars;
            internal int dwYCountChars;
            internal int dwFillAttribute;
            internal int dwFlags;
            internal short wShowWindow;
            internal short cbReserved2;
            internal IntPtr lpReserved2;
            internal IntPtr hStdInput;
            internal IntPtr hStdOutput;
            internal IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct StartupInfoEx
        {
            internal StartupInfo StartupInfo;
            internal IntPtr lpAttributeList;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct ProcessInformation
        {
            internal IntPtr hProcess;
            internal IntPtr hThread;
            internal uint dwProcessId;
            internal uint dwThreadId;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct IoCounters
        {
            internal ulong ReadOperationCount;
            internal ulong WriteOperationCount;
            internal ulong OtherOperationCount;
            internal ulong ReadTransferCount;
            internal ulong WriteTransferCount;
            internal ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct JobObjectBasicLimitInformation
        {
            internal long PerProcessUserTimeLimit;
            internal long PerJobUserTimeLimit;
            internal uint LimitFlags;
            internal UIntPtr MinimumWorkingSetSize;
            internal UIntPtr MaximumWorkingSetSize;
            internal uint ActiveProcessLimit;
            internal UIntPtr Affinity;
            internal uint PriorityClass;
            internal uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct JobObjectExtendedLimitInformation
        {
            internal JobObjectBasicLimitInformation BasicLimitInformation;
            internal IoCounters IoInfo;
            internal UIntPtr ProcessMemoryLimit;
            internal UIntPtr JobMemoryLimit;
            internal UIntPtr PeakProcessMemoryUsed;
            internal UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreatePipe(out SafeFileHandle readPipe, out SafeFileHandle writePipe, IntPtr attributes, uint size);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern int CreatePseudoConsole(Coord size, IntPtr input, IntPtr output, uint flags, out IntPtr pseudoConsole);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern int ResizePseudoConsole(IntPtr pseudoConsole, Coord size);

        [DllImport("kernel32.dll")]
        internal static extern void ClosePseudoConsole(IntPtr pseudoConsole);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attribute, IntPtr value, IntPtr size, IntPtr previous, IntPtr returnSize);

        [DllImport("kernel32.dll")]
        internal static extern void DeleteProcThreadAttributeList(IntPtr list);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreateProcessW(
            string? applicationName,
            StringBuilder commandLine,
            IntPtr processAttributes,
            IntPtr threadAttributes,
            [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
            uint creationFlags,
            IntPtr environment,
            string currentDirectory,
            ref StartupInfoEx startupInfo,
            out ProcessInformation processInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern uint ResumeThread(SafeFileHandle thread);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern SafeFileHandle CreateJobObjectW(IntPtr attributes, string? name);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetInformationJobObject(SafeFileHandle job, int infoClass, IntPtr info, uint length);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AssignProcessToJobObject(SafeFileHandle job, SafeFileHandle process);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool TerminateJobObject(SafeFileHandle job, uint exitCode);

        [DllImport("kernel32.dll")]
        internal static extern uint WaitForSingleObject(SafeFileHandle handle, uint milliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetExitCodeProcess(SafeFileHandle process, out uint exitCode);
    }
}
