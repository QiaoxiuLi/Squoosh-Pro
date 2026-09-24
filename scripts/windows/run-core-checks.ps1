$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$project = Join-Path $repoRoot "apps\windows\SquooshPro.WindowsChecks\SquooshPro.WindowsChecks.csproj"
$dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
$portableDotnet = Join-Path $env:USERPROFILE ".dotnet\dotnet.exe"
if ($null -eq $dotnet -and (Test-Path $portableDotnet)) {
    $dotnet = Get-Item $portableDotnet
}
if ($null -eq $dotnet) { throw ".NET SDK 8 is required to run the Windows core checks." }

& $dotnet.FullName run --project $project -c Release
if ($LASTEXITCODE -ne 0) { throw "Windows core checks failed." }
