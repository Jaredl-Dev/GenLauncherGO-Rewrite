using System.Threading;
using GenLauncherGO.Core.Integrity.Models;
using GenLauncherGO.Core.Launching.Contracts;
using GenLauncherGO.Core.Launching.Models;
using GenLauncherGO.Core.Mods.Models;
using GenLauncherGO.UI.Features.Dialogs.Contracts;
using GenLauncherGO.UI.Features.Dialogs.Models;
using GenLauncherGO.UI.Features.Launcher.Models;
using GenLauncherGO.UI.Features.Launcher.Services;
using GenLauncherGO.UI.Features.Mods;

namespace GenLauncherGO.Tests.UI.Features.Launcher.Services;

public sealed partial class LauncherWindowWorkflowCoordinatorTests
{
    [Fact]
    public void LaunchAsyncWhenExecutable_IsUnavailableShowsErrorAndDoesNotLaunch()
    {
        StaTestRunner.Run(async () =>
        {
            IGameExecutableDiscoveryService executableDiscovery = Substitute.For<IGameExecutableDiscoveryService>();
            executableDiscovery.IsExecutableAvailable(Arg.Any<string?>()).Returns(false);
            ILauncherDialogService dialogService = Substitute.For<ILauncherDialogService>();
            IGameProcessLauncher processLauncher = Substitute.For<IGameProcessLauncher>();
            LauncherWindowWorkflowCoordinator coordinator = CreateCoordinator(
                dialogService: dialogService,
                executableDiscovery: executableDiscovery,
                gameProcessLauncher: processLauncher);
            WorkflowFixture fixture = new();
            fixture.ViewModel.SelectedGameClientOption = new ExecutableOption(
                "Generals",
                "generals.exe",
                false,
                true);

            await coordinator.LaunchAsync(
                GameLaunchTargetKind.GameClient,
                fixture.Context,
                CancellationToken.None);

            await dialogService.Received(1).ShowErrorAsync(
                Arg.Any<LauncherInfoDialogRequest>(),
                fixture.Owner);
            await processLauncher.DidNotReceive().StartAsync(
                Arg.Any<GameLaunchRequest>(),
                Arg.Any<CancellationToken>());
        });
    }

    [Fact]
    public void LaunchAsyncForGameWhenProcessSucceeds_EnablesSelectedModificationSupport()
    {
        StaTestRunner.Run(async () =>
        {
            LauncherContentVersion selectedVersion = CreateVersion("Shockwave", ContentSourceKind.Manual);
            FakeLauncherContentCatalog catalog = CreateCatalog();
            catalog.Data.AddOrUpdate(selectedVersion);
            LauncherWindowWorkflowCoordinator coordinator = CreateCoordinator(catalog: catalog);
            WorkflowFixture fixture = new(catalog);
            ModificationViewModel selectedTile = CreateTile(catalog.Data.GetSelectedMod()!);
            fixture.AddTile(selectedTile);
            selectedTile.IsSelected = true;
            fixture.ViewModel.SelectedGameClientOption = new ExecutableOption(
                "Generals",
                "generals.exe",
                true,
                true);

            await coordinator.LaunchAsync(
                GameLaunchTargetKind.GameClient,
                fixture.Context,
                CancellationToken.None);

            selectedTile.SupportButtonBlinking.Should().BeTrue();
        });
    }
}
