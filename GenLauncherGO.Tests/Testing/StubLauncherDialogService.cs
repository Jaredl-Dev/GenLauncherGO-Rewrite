using Avalonia.Controls;
using GenLauncherGO.UI.Features.Dialogs.Contracts;
using GenLauncherGO.UI.Features.Dialogs.Models;

namespace GenLauncherGO.Tests.Testing;

internal static class StubLauncherDialogService
{
    /// <summary>
    ///     Creates a dialog service that answers every warning confirmation with <paramref name="confirmed" />.
    /// </summary>
    public static ILauncherDialogService AnsweringWarningConfirmations(bool confirmed)
    {
        ILauncherDialogService dialogService = Substitute.For<ILauncherDialogService>();
        dialogService.ShowWarningConfirmationAsync(
                Arg.Any<LauncherInfoDialogRequest>(),
                Arg.Any<string?>(),
                Arg.Any<Window?>())
            .Returns(confirmed);
        return dialogService;
    }
}
