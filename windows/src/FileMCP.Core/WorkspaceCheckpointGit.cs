using System.Diagnostics;

namespace FileMCP.Core;

internal sealed partial class LocalTools
{
    private async Task<byte[]?> ReadGitIndexBlobAsync(string repo, string relativePath, CancellationToken cancellationToken)
    {
        var listed = await RunGitAsync(
            repo,
            ["ls-files", "-s", "--", relativePath],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            trimOutput: true,
            cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrWhiteSpace(listed)) return null;

        string? oid = null;
        foreach (var line in listed.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var tab = line.IndexOf('\t');
            if (tab <= 0) continue;
            var metadata = line[..tab].Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (metadata.Length < 3 || metadata[2] != "0") continue;
            if (metadata[1].Length is < 7 or > 128 || !metadata[1].All(Uri.IsHexDigit))
                throw new FileMcpException("Checkpoint could not validate staged Git blob identity");
            oid = metadata[1];
            break;
        }
        if (oid is null) return null;
        return await RunGitBlobAsync(repo, oid, cancellationToken).ConfigureAwait(false);
    }

    private async Task<byte[]> RunGitBlobAsync(string repo, string oid, CancellationToken cancellationToken)
    {
        await _gitSlots.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var environment = SanitizedGitEnvironment();
            environment["GIT_TERMINAL_PROMPT"] = "0";
            if (!_enableCommands)
            {
                environment["GIT_ASKPASS"] = "";
                environment["SSH_ASKPASS"] = "";
                environment["GIT_SSH_COMMAND"] = "ssh.exe -F none -o BatchMode=yes -o ProxyCommand=none -o ProxyJump=none";
                environment["GIT_PAGER"] = "cat";
            }

            var info = new ProcessStartInfo
            {
                FileName = "git.exe",
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };
            foreach (var value in new[] { "-C", repo, "--no-pager" }.Concat(SafeGitConfigurationArguments()).Concat(["cat-file", "blob", oid]))
                info.ArgumentList.Add(value);
            info.Environment.Clear();
            foreach (var pair in environment) info.Environment[pair.Key] = pair.Value;

            using var process = new Process { StartInfo = info };
            if (!process.Start()) throw new FileMcpException("Could not launch git for checkpoint staged content");
            process.StandardInput.Close();

            await using var output = new MemoryStream();
            var copyTask = process.StandardOutput.BaseStream.CopyToAsync(output, cancellationToken);
            var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(120));
            try
            {
                await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                ProcessRunner.KillProcessTree(process);
                if (cancellationToken.IsCancellationRequested) throw;
                throw new FileMcpException("git checkpoint blob read timed out after 120 seconds");
            }
            await copyTask.ConfigureAwait(false);
            var error = await errorTask.ConfigureAwait(false);
            if (process.ExitCode != 0)
                throw new FileMcpException(string.IsNullOrWhiteSpace(error) ? "git checkpoint blob read failed" : error.Trim());
            if (output.Length > 64L * 1024 * 1024)
                throw new FileMcpException("Checkpoint staged file exceeds hard safety read limit");
            return output.ToArray();
        }
        finally
        {
            _gitSlots.Release();
        }
    }
}
