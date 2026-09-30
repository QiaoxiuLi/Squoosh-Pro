param(
    [Parameter(Mandatory = $true)][string]$Runner,
    [Parameter(Mandatory = $true)][string]$Application,
    [Parameter(Mandatory = $true)][string]$Artifacts
)

$ErrorActionPreference = "Stop"
New-Item $Artifacts -ItemType Directory -Force | Out-Null
$taskName = "SquooshPro-UIValidation-$([Guid]::NewGuid().ToString('N'))"
$log = Join-Path $Artifacts "console.log"
$command = "& '$($Runner.Replace("'", "''"))' '$($Application.Replace("'", "''"))' '$($Artifacts.Replace("'", "''"))' *> '$($log.Replace("'", "''"))'; exit `$LASTEXITCODE"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -EncodedCommand $encoded"
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 8)
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings | Out-Null
    Start-ScheduledTask $taskName
    $deadline = (Get-Date).AddMinutes(7)
    Start-Sleep 3
    while ((Get-ScheduledTask $taskName).State -eq "Running" -and (Get-Date) -lt $deadline) { Start-Sleep 2 }
    $info = Get-ScheduledTaskInfo $taskName
    if (Test-Path $log) { Get-Content $log }
    if ($info.LastTaskResult -ne 0) { throw "UI validation failed: $($info.LastTaskResult). See $log" }
} finally {
    Stop-ScheduledTask $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask $taskName -Confirm:$false -ErrorAction SilentlyContinue
}
