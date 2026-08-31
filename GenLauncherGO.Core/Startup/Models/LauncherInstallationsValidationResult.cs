using System;
using GenLauncherGO.Core.Settings.Models;

namespace GenLauncherGO.Core.Startup.Models;

/// <summary>
///     Describes validated per-game paths and the complete canonical installation-set outcome.
/// </summary>
public sealed record LauncherInstallationsValidationResult
{
    internal LauncherInstallationsValidationResult(
        GameInstallationValidationResult generalsValidation,
        GameInstallationValidationResult zeroHourValidation,
        LauncherInstallations canonicalInstallations,
        bool hasOverlappingPaths,
        bool isValid)
    {
        GeneralsValidation = generalsValidation ?? throw new ArgumentNullException(nameof(generalsValidation));
        ZeroHourValidation = zeroHourValidation ?? throw new ArgumentNullException(nameof(zeroHourValidation));
        CanonicalInstallations = canonicalInstallations ??
                                 throw new ArgumentNullException(nameof(canonicalInstallations));
        HasOverlappingPaths = hasOverlappingPaths;
        IsValid = isValid;
    }

    public GameInstallationValidationResult GeneralsValidation { get; }

    public GameInstallationValidationResult ZeroHourValidation { get; }

    public LauncherInstallations CanonicalInstallations { get; }

    public bool HasOverlappingPaths { get; }

    public bool IsValid { get; }
}
