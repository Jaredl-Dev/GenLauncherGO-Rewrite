namespace GenLauncherGO.UI.Features.Startup.Models;

/// <summary>
///     Identifies which replacement path the shutdown sequence must start.
/// </summary>
internal enum LauncherRestartKind
{
    None,
    Normal,
    ApplicationUpdate
}
