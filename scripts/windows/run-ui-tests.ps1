param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationPath,
    [string]$ArtifactDirectory,
    [string]$DotNetPath
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$project = Join-Path $repoRoot "apps\windows\SquooshPro.WindowsUiTests\SquooshPro.WindowsUiTests.csproj"
$runnerDirectory = Join-Path $repoRoot "Artifacts\WindowsUiTestRunner"
if ([string]::IsNullOrWhiteSpace($ArtifactDirectory)) {
    $ArtifactDirectory = Join-Path $repoRoot "Artifacts\WindowsUiTests"
}

$dotnet = if ($DotNetPath) { Get-Item $DotNetPath } else { Get-Command dotnet.exe -ErrorAction SilentlyContinue }
$portableDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
if ($null -eq $dotnet -and (Test-Path $portableDotnet)) {
    $dotnet = Get-Item $portableDotnet
}
if ($null -eq $dotnet) { throw ".NET SDK 10 is required to run the Windows UI tests." }

$dotnetExe = $dotnet.FullName
if ([string]::IsNullOrWhiteSpace($dotnetExe)) { $dotnetExe = $dotnet.Source }
& $dotnetExe publish $project -c Release -r win-x64 --self-contained true -o $runnerDirectory
if ($LASTEXITCODE -ne 0) { throw "Windows UI test runner build failed." }

$runner = Join-Path $runnerDirectory "SquooshPro.WindowsUiTests.exe"
& $runner (Resolve-Path $ApplicationPath).Path $ArtifactDirectory
if ($LASTEXITCODE -ne 0) { throw "Windows UI tests failed. Inspect $ArtifactDirectory." }
