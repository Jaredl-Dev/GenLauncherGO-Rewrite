using System;
using GenLauncherGO.Core.Startup;

namespace GenLauncherGO.Core.Settings.Models;

public sealed record LauncherCustomExecutable
{
    public LauncherCustomExecutable(string displayName, string executablePath)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(displayName);

        DisplayName = displayName.Trim();
        ExecutablePath = LauncherFileSystemLayout.NormalizeExecutablePath(executablePath);
    }

    public string DisplayName { get; }

    public string ExecutablePath { get; }
}
