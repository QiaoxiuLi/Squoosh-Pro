param(
    [Parameter(Mandatory = $true)]
    [string]$PublishedDirectory,
    [string]$Version = "0.2.0",
    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sourceDirectory = (Resolve-Path $PublishedDirectory).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot "Artifacts\WindowsRelease"
}
$packageName = "Squoosh-Pro-$Version-Windows-x64"
$packageDirectory = Join-Path $OutputRoot $packageName
$zipPath = Join-Path $OutputRoot "$packageName.zip"
$checksumPath = "$zipPath.sha256"

New-Item $OutputRoot -ItemType Directory -Force | Out-Null
if (-not $sourceDirectory.Equals($packageDirectory, [StringComparison]::OrdinalIgnoreCase)) {
    if (Test-Path $packageDirectory) {
        Remove-Item $packageDirectory -Recurse -Force
    }
    Copy-Item $sourceDirectory $packageDirectory -Recurse
}

foreach ($required in @("SquooshPro.exe", "SquooshPro.dll", "SquooshPro.pri")) {
    if (-not (Test-Path (Join-Path $packageDirectory $required))) {
        throw "Published application is missing $required."
    }
}

Copy-Item (Join-Path $repoRoot "docs\USER_GUIDE_WINDOWS_ZH.md") (Join-Path $packageDirectory "USER_GUIDE_WINDOWS_ZH.md") -Force
Copy-Item (Join-Path $repoRoot "third_party\THIRD_PARTY_NOTICES.md") (Join-Path $packageDirectory "THIRD_PARTY_NOTICES.md") -Force
Copy-Item (Join-Path $repoRoot "LICENSE") (Join-Path $packageDirectory "LICENSE.txt") -Force
$licenseDestination = Join-Path $packageDirectory "LICENSES"
if (Test-Path $licenseDestination) { Remove-Item $licenseDestination -Recurse -Force }
Copy-Item (Join-Path $repoRoot "third_party\LICENSES") $licenseDestination -Recurse

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $packageDirectory -DestinationPath $zipPath -CompressionLevel Optimal
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumLine = "$hash  $([System.IO.Path]::GetFileName($zipPath))$([char]10)"
[System.IO.File]::WriteAllText($checksumPath, $checksumLine, [System.Text.Encoding]::ASCII)

Write-Host "Windows release: $zipPath"
Write-Host "SHA-256: $hash"
