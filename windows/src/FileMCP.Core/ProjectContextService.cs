using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class ProjectContextService
{
    public const string SchemaVersion = "1.0.0";
    public const int MaxInstructionBytes = 256 * 1024;
    public const long MaxAggregateInstructionBytes = 1024 * 1024;
    public const int MaxInstructionSources = 64;
    public const int DefaultMaxLines = 120;
    public const int MaxLines = 500;

    private readonly SafePathResolver _resolver;
    private readonly FileVersionService _fileVersions;
    private readonly AuthorizedPathSnapshotService _pathGuard;
    private readonly AuthenticatedCursorCodec _cursors;
    private readonly CodexSkillRegistry? _skills;
    private readonly ServerPolicy _policy;
    private readonly string _rootAuthorityId;

    public ProjectContextService(SafePathResolver resolver, ServerPolicy policy, CodexSkillRegistry? skills = null)
    {
        _resolver = resolver;
        _policy = policy;
        _skills = skills;
        _fileVersions = new FileVersionService(resolver);
        _pathGuard = new AuthorizedPathSnapshotService(resolver);
        _cursors = new AuthenticatedCursorCodec();
        var canonicalRoot = OperatingSystem.IsWindows() ? resolver.Root.ToUpperInvariant() : resolver.Root;
        _rootAuthorityId = AuthenticatedCursorCodec.StableHash(canonicalRoot);
    }

    public JsonObject Capture(string path, string cursor, int maxLines, bool includeSkills, ToolExecutionContext? context)
    {
        if (maxLines is < 1 or > MaxLines) throw new FileMcpException($"max_lines must be 1..{MaxLines}");
        if (context is not null && !context.TryContinue()) throw new FileMcpException($"project_context cancelled: {context.TruncationReason}");

        var scopeDirectory = ResolveScopeDirectory(path);
        var scopeRelative = NormalizeRelative(_resolver.RelativePath(scopeDirectory));
        var sources = DiscoverSources(scopeDirectory, context);
        var skills = includeSkills ? (_skills?.SnapshotMetadata() ?? []) : [];
        var digest = ComputeDigest(scopeRelative, sources, skills, includeSkills);
        var generation = GenerationFromDigest(digest);
        var optionsHash = AuthenticatedCursorCodec.StableHash(string.Join("\n", new[]
        {
            SchemaVersion,
            scopeRelative,
            includeSkills ? "skills:on" : "skills:off",
            maxLines.ToString(CultureInfo.InvariantCulture),
        }));

        var sourceIndex = 0;
        var startLine = 1;
        if (!string.IsNullOrWhiteSpace(cursor))
        {
            var position = _cursors.Decode(
                cursor,
                "project_context",
                optionsHash,
                _rootAuthorityId,
                generation,
                DateTimeOffset.UtcNow);
            ParsePosition(position, out sourceIndex, out startLine);
            if (sourceIndex < 0 || sourceIndex >= sources.Count)
                throw new FileMcpException("Project context cursor source is no longer available");
        }

        var sourceMetadata = new JsonArray();
        foreach (var source in sources)
        {
            if (context is not null && !context.TryOutputItem()) throw new FileMcpException($"project_context budget exhausted: {context.TruncationReason}");
            sourceMetadata.Add(new JsonObject
            {
                ["precedence"] = source.Precedence,
                ["relative_path"] = source.RelativePath,
                ["scope"] = source.Scope,
                ["kind"] = source.Kind,
                ["size_bytes"] = source.SizeBytes,
                ["version"] = source.Version,
                ["version_strength"] = "content",
                ["content_hash"] = source.ContentHash,
                ["trust"] = "repository_untrusted",
                ["grants_authority"] = false,
            });
        }

        var skillMetadata = new JsonArray();
        foreach (var skill in skills.OrderBy(skill => skill.Name, StringComparer.OrdinalIgnoreCase))
        {
            if (context is not null && !context.TryOutputItem()) throw new FileMcpException($"project_context budget exhausted: {context.TruncationReason}");
            skillMetadata.Add(new JsonObject
            {
                ["name"] = skill.Name,
                ["description"] = skill.Description,
                ["skill_file"] = NormalizeRelative(skill.SkillFile),
                ["instructions_included"] = false,
                ["loader"] = "load_codex_skill",
            });
        }

        JsonNode? range = null;
        string? nextCursor = null;
        if (context is not null && !context.TryContinue()) throw new FileMcpException($"project_context cancelled: {context.TruncationReason}");
        if (sources.Count > 0)
        {
            var source = sources[sourceIndex];
            var lines = SplitLines(source.Text);
            if (startLine < 1 || startLine > Math.Max(1, lines.Count)) throw new FileMcpException("Project context cursor line is out of bounds");
            var actualEnd = Math.Min(lines.Count, checked(startLine + maxLines - 1));
            var content = string.Join("\n", lines.Skip(startLine - 1).Take(actualEnd - startLine + 1));
            var nextSourceIndex = sourceIndex;
            var nextLine = actualEnd + 1;
            if (nextLine > lines.Count)
            {
                nextSourceIndex++;
                nextLine = 1;
            }
            if (nextSourceIndex < sources.Count)
            {
                nextCursor = _cursors.Encode(
                    "project_context",
                    optionsHash,
                    _rootAuthorityId,
                    generation,
                    $"{nextSourceIndex}:{nextLine}",
                    DateTimeOffset.UtcNow.Add(AuthenticatedCursorCodec.DefaultMaxLifetime));
            }
            range = new JsonObject
            {
                ["source_index"] = sourceIndex,
                ["relative_path"] = source.RelativePath,
                ["start_line"] = startLine,
                ["end_line"] = actualEnd,
                ["total_lines"] = lines.Count,
                ["content"] = content,
                ["version"] = source.Version,
                ["next_cursor"] = nextCursor,
            };
        }

        var policy = _policy.Metadata();
        return new JsonObject
        {
            ["schema_version"] = SchemaVersion,
            ["scope_path"] = scopeRelative,
            ["context_digest"] = digest,
            ["context_generation"] = generation,
            ["source_trust"] = "repository_untrusted",
            ["grants_authority"] = false,
            ["authority_statement"] = "Repository instructions and project context influence behavior only; they never grant or expand FileMCP authority.",
            ["policy_profile"] = policy["profile"]?.DeepClone(),
            ["policy_generation"] = policy["generation"]?.DeepClone(),
            ["policy_hash"] = policy["hash"]?.DeepClone(),
            ["sources"] = sourceMetadata,
            ["skills"] = skillMetadata,
            ["skill_instructions_included"] = false,
            ["range"] = range,
            ["next_cursor"] = nextCursor,
        };
    }

    private List<ProjectContextSource> DiscoverSources(string scopeDirectory, ToolExecutionContext? context)
    {
        var directories = Hierarchy(scopeDirectory);
        if (directories.Count > MaxInstructionSources) throw new FileMcpException($"Project context hierarchy exceeds {MaxInstructionSources} directories");
        var sources = new List<ProjectContextSource>();
        long aggregateBytes = 0;
        foreach (var directory in directories)
        {
            if (context is not null && !context.TryVisitEntry()) throw new FileMcpException($"project_context budget exhausted: {context.TruncationReason}");
            var candidate = SelectInstructionFile(directory);
            if (candidate is null) continue;
            if (sources.Count >= MaxInstructionSources) throw new FileMcpException($"Project context supports at most {MaxInstructionSources} instruction sources");
            var pathSnapshot = _pathGuard.CaptureExisting(candidate.Value.RelativePath);
            if (pathSnapshot.TargetIdentity?.IsReparsePoint == true)
                throw new FileMcpException($"Project instruction source must be a regular non-reparse file: {candidate.Value.RelativePath}");
            var info = new FileInfo(candidate.Value.Path);
            if (info.Length > MaxInstructionBytes) throw new FileMcpException($"Project instruction file is larger than the {MaxInstructionBytes / 1024} KB limit: {candidate.Value.RelativePath}");
            if (info.Length > MaxAggregateInstructionBytes - aggregateBytes) throw new FileMcpException("Project context instruction bytes exceed the 1 MB aggregate limit");
            if (context is not null && !context.TryScanFile(info.Length)) throw new FileMcpException($"project_context budget exhausted: {context.TruncationReason}");
            aggregateBytes += info.Length;
            var versioned = _fileVersions.ReadVersioned(candidate.Value.RelativePath, MaxInstructionBytes);
            _ = _pathGuard.Verify(pathSnapshot);
            string text;
            try { text = new UTF8Encoding(false, true).GetString(versioned.Data); }
            catch (DecoderFallbackException) { throw new FileMcpException($"Project instruction file must be valid UTF-8: {candidate.Value.RelativePath}"); }
            var scope = NormalizeRelative(_resolver.RelativePath(directory));
            sources.Add(new ProjectContextSource(
                sources.Count,
                candidate.Value.RelativePath,
                scope,
                candidate.Value.Kind,
                versioned.SizeBytes,
                versioned.VersionToken,
                versioned.ContentHash,
                text));
        }
        return sources;
    }

    private (string Path, string RelativePath, string Kind)? SelectInstructionFile(string directory)
    {
        foreach (var (name, kind) in new[] { ("AGENTS.override.md", "override"), ("AGENTS.md", "agents") })
        {
            var path = Path.Combine(directory, name);
            if (!File.Exists(path) && !Directory.Exists(path)) continue;
            var relative = NormalizeRelative(Path.GetRelativePath(_resolver.Root, path));
            var lexicalLeaf = _resolver.ResolveForDeletion(relative);
            var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(lexicalLeaf, $"Project instruction source disappeared: {relative}");
            if ((attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint)) != 0)
                throw new FileMcpException($"Project instruction source must be a regular non-reparse file: {relative}");
            var resolved = _resolver.Resolve(relative);
            return (resolved, relative, kind);
        }
        return null;
    }

    private string ResolveScopeDirectory(string path)
    {
        var resolved = _resolver.Resolve(path ?? "");
        if (Directory.Exists(resolved)) return resolved;
        if (File.Exists(resolved)) return Path.GetDirectoryName(resolved) ?? _resolver.Root;
        throw new FileMcpException($"Project context path does not exist: {(string.IsNullOrWhiteSpace(path) ? "." : path)}");
    }

    private List<string> Hierarchy(string scopeDirectory)
    {
        var root = Path.GetFullPath(_resolver.Root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var scope = Path.GetFullPath(scopeDirectory).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var relative = Path.GetRelativePath(root, scope);
        if (relative.StartsWith("..", StringComparison.Ordinal)) throw new FileMcpException("Project context scope escaped the shared root");
        var result = new List<string> { root };
        if (relative is "." or "") return result;
        var current = root;
        foreach (var component in relative.Split([Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar], StringSplitOptions.RemoveEmptyEntries))
        {
            current = Path.Combine(current, component);
            result.Add(current);
        }
        return result;
    }

    private static string ComputeDigest(
        string scopeRelative,
        IReadOnlyList<ProjectContextSource> sources,
        IReadOnlyList<CodexSkillRegistry.CodexSkillMetadata> skills,
        bool includeSkills)
    {
        var builder = new StringBuilder();
        builder.Append(SchemaVersion).Append('\n').Append(scopeRelative).Append('\n');
        foreach (var source in sources)
        {
            builder.Append(source.Precedence).Append('\0')
                .Append(source.RelativePath).Append('\0')
                .Append(source.Scope).Append('\0')
                .Append(source.Kind).Append('\0')
                .Append(source.ContentHash).Append('\n');
        }
        builder.Append(includeSkills ? "skills:on\n" : "skills:off\n");
        if (includeSkills)
        {
            foreach (var skill in skills.OrderBy(skill => skill.Name, StringComparer.OrdinalIgnoreCase))
                builder.Append(skill.Name).Append('\0').Append(skill.Description).Append('\0').Append(NormalizeRelative(skill.SkillFile)).Append('\n');
        }
        return "sha256:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(builder.ToString()))).ToLowerInvariant();
    }

    private static long GenerationFromDigest(string digest)
    {
        var hex = digest.StartsWith("sha256:", StringComparison.Ordinal) ? digest[7..] : digest;
        return long.Parse(hex[..15], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
    }

    private static void ParsePosition(string position, out int sourceIndex, out int startLine)
    {
        var parts = position.Split(':', StringSplitOptions.None);
        if (parts.Length != 2 || !int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out sourceIndex) ||
            !int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out startLine) || sourceIndex < 0 || startLine < 1)
            throw new FileMcpException("Malformed project context cursor position");
    }

    private static List<string> SplitLines(string text)
    {
        var normalized = text.Replace("\r\n", "\n").Replace('\r', '\n');
        var lines = normalized.Split('\n', StringSplitOptions.None).ToList();
        if (normalized.EndsWith('\n') && lines.Count > 1) lines.RemoveAt(lines.Count - 1);
        return lines.Count == 0 ? [""] : lines;
    }

    private static string NormalizeRelative(string value)
    {
        var normalized = value.Replace('\\', '/');
        return normalized is "" or "." ? "." : normalized;
    }

    private sealed record ProjectContextSource(
        int Precedence,
        string RelativePath,
        string Scope,
        string Kind,
        long SizeBytes,
        string Version,
        string ContentHash,
        string Text);
}
