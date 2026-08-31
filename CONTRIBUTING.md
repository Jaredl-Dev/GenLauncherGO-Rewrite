# Contributing to GenLauncherGO

Contributions are welcome. Fork the repository, create a branch, make and test your changes, then open a pull request
with a clear description.

## Development setup

The repository selects the .NET 10 SDK through `global.json`, starting at version `10.0.300` and allowing later
feature bands.

Run the Avalonia project from the repository root:

```powershell
dotnet run --project ./GenLauncherGO.UI/GenLauncherGO.UI.csproj
```

For a full launcher UI session, run the executable outside all supported game installations. Startup validation
blocks the launcher when it is placed inside one.

## Required quality gates

Run the standard repository checks before submitting a change:

```powershell
dotnet build GenLauncherGO.sln
dotnet format GenLauncherGO.sln --verify-no-changes
dotnet test GenLauncherGO.sln
```

The Windows CI workflow builds Release, verifies formatting, runs the critical-behavior test suite, and builds and
inspects the supported Velopack portable archive. A separate weekly workflow audits vulnerable and deprecated
dependencies.

## Testing policy

Admit a test only if it would catch a realistic regression in important observable behavior, an external contract, or a
safety invariant, or prevent a costly failure. The existing recovery, path-safety, compatibility, persistence, race,
and workflow tests set the bar.

Never admit tests for coverage, code existence, implementation mirroring, routine properties or guards, framework
behavior, private helpers, DI details, or exhaustive low-value permutations. Prefer the fewest representative scenarios;
overlap only where destructive file-system or security boundaries require defense in depth.

Before implementation, identify the qualifying tests and their value, or state why none qualify. Write and narrowly run
each test first; red must be the intended behavioral failure, not a compilation, setup, unrelated, environmental, or
flaky failure. Only a characterization test required for a behavior-preserving refactor may bypass red, and that
exception must be explained before editing. After red, rerun the target to green and then run the wider suite. Record
the red and green commands and outcomes, or the no-test rationale, in the pull request.

## Symbolic-link safety tests

Symbolic-link tests are required in CI and fail the workflow if the runner cannot execute them. Local accounts that
cannot create symbolic links report those tests as explicit skips. To enforce the same fail-closed behavior locally,
enable Windows Developer Mode or use an elevated terminal, then run:

```powershell
$env:GENLAUNCHERGO_REQUIRE_SYMBOLIC_LINK_TESTS = "true"
dotnet test GenLauncherGO.sln
Remove-Item Env:GENLAUNCHERGO_REQUIRE_SYMBOLIC_LINK_TESTS
```

## Coverage

Optionally generate a local coverage report:

```powershell
dotnet msbuild ./eng/coverage.proj -target:Coverage
```

The HTML report is written to `artifacts/coverage/index.html`. Coverage is informational: CI does not enforce a
percentage because executing a line does not establish that its behavior is meaningfully protected.

## Publishing

`VersionPrefix` in `GenLauncherGO.UI/GenLauncherGO.UI.csproj` is the only version value to edit. The packaging script
asks MSBuild for the resulting `Version`, package ID, and canonical GitHub update repository URL, publishes the
supported self-contained Windows x64 payload, and packages it with the repository-pinned Velopack tool.

To publish a release, update `VersionPrefix` through the normal pull-request workflow and merge it to `master`. After
CI passes, open **Actions**, select **Publish release**, choose `master`, and run the workflow.

The workflow verifies, packages, and uploads the release as a draft using the matching `v<VersionPrefix>` tag. Review
the generated notes and assets, test the portable archive when appropriate, then publish the draft from GitHub. Draft
releases are not offered to launcher update clients.

Do not create the tag or release manually, and do not reuse a published version.

The packaging script remains available for local verification. Use bootstrap mode only when deliberately building a
feed with no predecessor:

```powershell
./eng/package-release.ps1 -Bootstrap
```

For a local build of an ordinary later release, let the script download the previous release metadata and packages so
Velopack can create a delta when appropriate:

```powershell
./eng/package-release.ps1
```

If releases are being bridged from another GitHub repository, use its repository URL for that one packaging run:

```powershell
./eng/package-release.ps1 -PreviousReleaseRepositoryUrl https://github.com/OWNER/REPOSITORY
```

The local script writes the full package, `GenLauncherGO-win-Portable.zip`, `releases.win.json`, and an optional delta
package to `artifacts/release`. It does not upload anything and rejects installer or MSI output; releases must remain
portable-only with no shortcuts or uninstall registration. The GitHub workflow is the sole publishing path.

The archive check enforces the portable root layout (`GenLauncherGO.exe`, `Update.exe`, `.portable`, and the `current`
payload/version files) and rejects packaged user data. Follow the [two-version local-feed smoke test](docs/portable-update-smoke.md)
before publishing a change to the updater or release process.

## Architecture

The solution deliberately uses three production projects, one test project, and one test-only analyzer project, with
no `src` folder:

| Project | Responsibility |
| --- | --- |
| `GenLauncherGO.Core` | Dependency-light contracts, launcher rules, models, and path identities |
| `GenLauncherGO.Infrastructure` | Disk, network, archive, process, persistence, integrity, and package-provider implementations |
| `GenLauncherGO.UI` | Native Avalonia presentation, user workflows, localization, and the dependency-injection composition root |
| `GenLauncherGO.Tests` | Observable behavior, compatibility, recovery, and file-system safety tests |
| `GenLauncherGO.TestAnalyzers` | Test-only analyzer enforcing the repository's test-method naming convention |

Dependencies point inward: UI can reference Core and Infrastructure, Infrastructure can reference Core, and Core does
not reference Avalonia or implementation packages. Interfaces represent intentional project or side-effect
boundaries; feature-internal code normally uses sealed concrete types.

Mutable paths carry their owning root so file operations can reject traversal and reparse-point escapes.

## Backend compatibility

GenLauncherGO consumes an external backend tied to [p0ls3r](https://github.com/p0ls3r) and the original GenLauncher
project. This repository does not control that backend, so its legacy remote YAML names and structure are preserved
exactly at the Infrastructure boundary and mapped into the application's internal models. Do not rename or reshape
that manifest contract without a deliberate compatibility plan coordinated with the backend maintainers.

## Submitting changes

Keep changes focused, preserve existing behavior unless the change deliberately updates it, and include tests for
observable behavior or safety invariants. In the pull request, explain what changed and list the verification you ran.
