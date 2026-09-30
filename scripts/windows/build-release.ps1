param(
    [string]$Version = "0.3.1",
    [string]$Configuration = "Release",
    [string]$RuntimeIdentifier = "win-x64",
    [string]$ArtifactRoot,
    [string]$DotNetPath
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$project = Join-Path $repoRoot "apps\windows\SquooshPro.Windows\SquooshPro.Windows.csproj"
if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    $ArtifactRoot = Join-Path $repoRoot "Artifacts\WindowsRelease"
}
$packageName = "Squoosh-Pro-$Version-Windows-x64"
$publishDirectory = Join-Path $ArtifactRoot $packageName

$dotnetCommand = if ($DotNetPath) { Get-Item $DotNetPath } else { Get-Command dotnet.exe -ErrorAction SilentlyContinue }
$portableDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
if ($null -eq $dotnetCommand -and (Test-Path $portableDotnet)) {
    $env:DOTNET_ROOT = Split-Path $portableDotnet
    $env:PATH = "$($env:DOTNET_ROOT);$($env:PATH)"
    $dotnetCommand = Get-Command dotnet.exe -ErrorAction Stop
}
if ($null -eq $dotnetCommand) {
    throw ".NET SDK 10 is required to build Squoosh Pro."
}
$dotnetExe = $dotnetCommand.FullName
if ([string]::IsNullOrWhiteSpace($dotnetExe)) { $dotnetExe = $dotnetCommand.Source }
if (Test-Path $publishDirectory) { throw "Output already exists: $publishDirectory. Choose a new ArtifactRoot." }
New-Item $publishDirectory -ItemType Directory -Force | Out-Null

Push-Location $repoRoot
try {
    $sdkVersion = (& $dotnetExe --version).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $sdkVersion.StartsWith("10.")) { throw ".NET SDK 10 is required. Pass -DotNetPath for a portable SDK." }
    & $dotnetExe publish $project -c $Configuration -r $RuntimeIdentifier --self-contained true -o $publishDirectory "/p:Platform=x64" "/p:Version=$Version"
    if ($LASTEXITCODE -ne 0) { throw "Windows release publish failed." }
    & (Join-Path $PSScriptRoot "package-release.ps1") -PublishedDirectory $publishDirectory -Version $Version -OutputRoot $ArtifactRoot
} finally { Pop-Location }
