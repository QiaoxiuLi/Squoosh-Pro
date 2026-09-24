param(
    [string]$Version = "0.2.0",
    [string]$Configuration = "Release",
    [string]$RuntimeIdentifier = "win-x64",
    [string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$project = Join-Path $repoRoot "apps\windows\SquooshPro.Windows\SquooshPro.Windows.csproj"
if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    $ArtifactRoot = Join-Path $repoRoot "Artifacts\WindowsRelease"
}
$packageName = "Squoosh-Pro-$Version-Windows-x64"
$publishDirectory = Join-Path $ArtifactRoot $packageName

$dotnetCommand = Get-Command dotnet.exe -ErrorAction SilentlyContinue
$portableDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
if ($null -eq $dotnetCommand -and (Test-Path $portableDotnet)) {
    $env:DOTNET_ROOT = Split-Path $portableDotnet
    $env:PATH = "$($env:DOTNET_ROOT);$($env:PATH)"
    $dotnetCommand = Get-Command dotnet.exe -ErrorAction Stop
}
if ($null -eq $dotnetCommand) {
    throw ".NET SDK 8 is required to build Squoosh Pro."
}
$dotnetRoot = Split-Path $dotnetCommand.Source
$sdkVersion = (& $dotnetCommand.Source --version).Trim()
$sdkDirectory = Join-Path $dotnetRoot "sdk\$sdkVersion\Sdks"
if (Test-Path $sdkDirectory) {
    $env:DOTNET_ROOT = $dotnetRoot
    $env:MSBuildSDKsPath = $sdkDirectory
}

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
$msbuild = $null
if (Test-Path $vswhere) {
    $installationPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installationPath)) {
        $candidate = Join-Path $installationPath "MSBuild\Current\Bin\MSBuild.exe"
        if (Test-Path $candidate) { $msbuild = $candidate }
    }
}
if ($null -eq $msbuild) {
    $customBuildTools = "C:\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $customBuildTools) { $msbuild = $customBuildTools }
}
if ($null -eq $msbuild) {
    $msbuild = (Get-Command msbuild.exe -ErrorAction Stop).Source
}

if (Test-Path $publishDirectory) {
    Remove-Item $publishDirectory -Recurse -Force
}
New-Item $publishDirectory -ItemType Directory -Force | Out-Null

$properties = @(
    "/p:Configuration=$Configuration",
    "/p:Platform=x64",
    "/p:RuntimeIdentifier=$RuntimeIdentifier",
    "/p:SelfContained=true",
    "/p:WindowsAppSDKSelfContained=true",
    "/p:Version=$Version"
)

& $msbuild $project /restore @properties /m
if ($LASTEXITCODE -ne 0) { throw "Windows release build failed." }

& $msbuild $project /t:Publish @properties "/p:PublishDir=$publishDirectory" /m
if ($LASTEXITCODE -ne 0) { throw "Windows release publish failed." }

& (Join-Path $PSScriptRoot "package-release.ps1") -PublishedDirectory $publishDirectory -Version $Version -OutputRoot $ArtifactRoot
if ($LASTEXITCODE -ne 0) { throw "Windows release packaging failed." }
