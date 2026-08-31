[CmdletBinding()]
param(
    [switch]$Bootstrap,
    [string]$PreviousReleaseRepositoryUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$projectPath = Join-Path $repositoryRoot "GenLauncherGO.UI\GenLauncherGO.UI.csproj"
$toolManifestPath = Join-Path $repositoryRoot ".config\dotnet-tools.json"
$iconPath = Join-Path $repositoryRoot "GenLauncherGO.UI\Shared\Resources\Icons\GenLauncherGo.ico"
$artifactsDirectory = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
$publishDirectory = Join-Path $artifactsDirectory "velopack-publish"
$workingReleaseDirectory = Join-Path $artifactsDirectory "velopack-work"
$uploadDirectory = Join-Path $artifactsDirectory "release"
$publishProfile = "WinX64SelfContained"
$channel = "win"

function Reset-OwnedDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $relativePath = [IO.Path]::GetRelativePath($artifactsDirectory, $fullPath)
    if ([IO.Path]::IsPathRooted($relativePath) -or
        $relativePath -eq ".." -or
        $relativePath.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)) {
        throw "Refusing to reset a directory outside $artifactsDirectory`: $fullPath"
    }

    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

function Invoke-DotNet {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$Description
    )

    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

if ($Bootstrap -and -not [string]::IsNullOrWhiteSpace($PreviousReleaseRepositoryUrl)) {
    throw "-PreviousReleaseRepositoryUrl cannot be combined with -Bootstrap because a bootstrap release has no predecessor."
}

Push-Location $repositoryRoot
try {
    $metadataJson = & dotnet msbuild $projectPath `
        "-p:PublishProfile=$publishProfile" `
        "-getProperty:Version" `
        "-getProperty:VelopackUpdateRepositoryUrl" `
        "-getProperty:AssemblyName" `
        "-getProperty:RuntimeIdentifier" `
        "-getProperty:VelopackVersion"
    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild project metadata evaluation failed with exit code $LASTEXITCODE."
    }

    $metadata = $metadataJson | ConvertFrom-Json
    $version = [string]$metadata.Properties.Version
    $repositoryUrl = [string]$metadata.Properties.VelopackUpdateRepositoryUrl
    $packageId = [string]$metadata.Properties.AssemblyName
    $runtime = [string]$metadata.Properties.RuntimeIdentifier
    $velopackLibraryVersion = [string]$metadata.Properties.VelopackVersion
    if ([string]::IsNullOrWhiteSpace($version) -or
        [string]::IsNullOrWhiteSpace($repositoryUrl) -or
        [string]::IsNullOrWhiteSpace($packageId) -or
        [string]::IsNullOrWhiteSpace($runtime) -or
        [string]::IsNullOrWhiteSpace($velopackLibraryVersion)) {
        throw "Version, VelopackUpdateRepositoryUrl, AssemblyName, RuntimeIdentifier, and VelopackVersion must all be defined by the UI project."
    }

    $toolManifest = Get-Content -LiteralPath $toolManifestPath -Raw | ConvertFrom-Json
    $velopackToolVersion = [string]$toolManifest.tools.vpk.version
    if (-not [string]::Equals(
            $velopackLibraryVersion,
            $velopackToolVersion,
            [StringComparison]::Ordinal)) {
        throw "Velopack library version $velopackLibraryVersion does not match vpk tool version $velopackToolVersion."
    }

    Invoke-DotNet -Arguments @("tool", "restore") -Description "dotnet tool restore"

    Reset-OwnedDirectory $publishDirectory
    Reset-OwnedDirectory $workingReleaseDirectory
    Reset-OwnedDirectory $uploadDirectory

    if (-not $Bootstrap) {
        $previousRepositoryUrl = if ([string]::IsNullOrWhiteSpace($PreviousReleaseRepositoryUrl)) {
            $repositoryUrl
        }
        else {
            $PreviousReleaseRepositoryUrl
        }

        Invoke-DotNet -Arguments @(
            "tool", "run", "vpk", "--", "download", "github",
            "--repoUrl", $previousRepositoryUrl,
            "--outputDir", $workingReleaseDirectory,
            "--channel", $channel
        ) -Description "vpk previous-release download"
    }

    Invoke-DotNet -Arguments @(
        "publish", $projectPath,
        "-p:PublishProfile=$publishProfile",
        "--output", $publishDirectory
    ) -Description "dotnet publish"

    $launcherPath = Join-Path $publishDirectory "$packageId.exe"
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
        throw "Expected the published launcher executable at $launcherPath."
    }

    Invoke-DotNet -Arguments @(
        "tool", "run", "vpk", "--", "pack",
        "--packId", $packageId,
        "--packVersion", $version,
        "--packDir", $publishDirectory,
        "--mainExe", "$packageId.exe",
        "--runtime", $runtime,
        "--channel", $channel,
        "--icon", $iconPath,
        "--packTitle", "GenLauncherGO",
        "--packAuthors", "GenLauncherGO",
        "--noInst", "true",
        "--shortcuts", "None",
        "--msi", "false",
        "--outputDir", $workingReleaseDirectory
    ) -Description "vpk pack"

    $requiredAssetNames = @(
        "$packageId-$version-full.nupkg",
        "$packageId-$channel-Portable.zip",
        "releases.$channel.json"
    )
    foreach ($assetName in $requiredAssetNames) {
        $assetPath = Join-Path $workingReleaseDirectory $assetName
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            throw "Velopack did not produce the required release asset $assetName."
        }

        Copy-Item -LiteralPath $assetPath -Destination $uploadDirectory
    }

    $deltaPath = Join-Path $workingReleaseDirectory "$packageId-$version-delta.nupkg"
    if (Test-Path -LiteralPath $deltaPath -PathType Leaf) {
        Copy-Item -LiteralPath $deltaPath -Destination $uploadDirectory
    }

    $portableArchivePath = Join-Path $uploadDirectory "$packageId-$channel-Portable.zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $portableArchive = [System.IO.Compression.ZipFile]::OpenRead($portableArchivePath)
    try {
        $archiveEntries = @($portableArchive.Entries | ForEach-Object {
            $_.FullName.Replace('\', '/').TrimStart('/')
        })
    }
    finally {
        $portableArchive.Dispose()
    }

    $expectedArchiveEntries = @(
        ".portable",
        "$packageId.exe",
        "Update.exe",
        "current/$packageId.exe",
        "current/sq.version"
    )
    $archiveDifference = @(Compare-Object `
        -ReferenceObject ($expectedArchiveEntries | Sort-Object) `
        -DifferenceObject ($archiveEntries | Sort-Object))
    if ($archiveDifference.Count -ne 0) {
        throw "The portable archive does not have the expected root stub, updater, marker, current app, and version metadata layout."
    }

    if ($archiveEntries | Where-Object { $_ -match '(^|/)GenLauncherGO Data(/|$)' }) {
        throw "The portable archive must not contain the user-owned GenLauncherGO Data directory."
    }

    $forbiddenAssets = @(Get-ChildItem -LiteralPath $uploadDirectory -File | Where-Object {
        $_.Name -match '(?i)(Setup\.exe$|\.msi$)'
    })
    if ($forbiddenAssets.Count -ne 0) {
        throw "Portable-only packaging unexpectedly produced an installer or MSI asset."
    }

    Write-Host "Created upload-ready Velopack release for version $version in $uploadDirectory"
    Get-ChildItem -LiteralPath $uploadDirectory -File | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Name)"
    }
}
finally {
    Pop-Location
}
