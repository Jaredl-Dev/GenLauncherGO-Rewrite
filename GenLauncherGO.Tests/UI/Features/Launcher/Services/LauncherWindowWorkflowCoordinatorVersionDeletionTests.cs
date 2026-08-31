using GenLauncherGO.Core.Integrity.Models;
using GenLauncherGO.Core.Mods.Models;
using GenLauncherGO.UI.Features.Dialogs.Contracts;
using GenLauncherGO.UI.Features.Launcher.Services;
using GenLauncherGO.UI.Features.Mods;

namespace GenLauncherGO.Tests.UI.Features.Launcher.Services;

public sealed partial class LauncherWindowWorkflowCoordinatorTests
{
    [Fact]
    public void DeleteVersionWhenRemoval_IsDeclinedPreservesInstalledContent()
    {
        StaTestRunner.Run(async () =>
        {
            ILauncherDialogService dialogService = Substitute.For<ILauncherDialogService>();
            FakeLauncherContentCatalog catalog = CreateCatalog();
            LauncherContentActionCoordinator coordinator = CreateContentActionCoordinator(
                dialogService: dialogService,
                catalog: catalog);
            ModificationViewModel viewModel = CreateTile(
                new LauncherContent(CreateVersion("Shockwave", ContentSourceKind.Manual)));
            ModificationVersionSelection versionSelection = new(
                viewModel.LatestVersion,
                viewModel);
            WorkflowFixture fixture = new(catalog);
            fixture.AddTile(viewModel);

            await coordinator.DeleteVersionAsync(fixture.Context, versionSelection);

            catalog.DiscardedContents.Should().BeEmpty();
            catalog.UninstalledVersions.Should().BeEmpty();
            fixture.ViewModel.ModsListSource.Should().ContainSingle()
                .Which.Should().BeSameAs(viewModel);
        });
    }
}
