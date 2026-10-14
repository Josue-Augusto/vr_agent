param(
    [string]$NssmPath = 'C:\nssm\win64\nssm.exe',
    [string]$ServiceName = 'VRAgent',
    [string]$InstallDirectory = 'C:\vr\agent',
    [string]$ExecutablePath = 'C:\vr\agent\vr_agent.exe'
)

$ErrorActionPreference = 'Stop'

$nssm = (Resolve-Path -LiteralPath $NssmPath).Path
$executable = (Resolve-Path -LiteralPath $ExecutablePath).Path
$installDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$logDirectory = Join-Path $installDirectory 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Set-NssmSetting {
    param([string[]]$Arguments)

    & $nssm set $ServiceName @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "NSSM failed to set '$($Arguments[0])' for service '$ServiceName' (exit code $LASTEXITCODE)."
    }
}

& $nssm install $ServiceName $executable
if ($LASTEXITCODE -ne 0) {
    throw "NSSM failed to install service '$ServiceName' (exit code $LASTEXITCODE)."
}

Set-NssmSetting -Arguments @('AppDirectory', $installDirectory)
Set-NssmSetting -Arguments @('AppParameters', '--service')
Set-NssmSetting -Arguments @('AppStdout', (Join-Path $logDirectory 'service-out.log'))
Set-NssmSetting -Arguments @('AppStderr', (Join-Path $logDirectory 'service-error.log'))
Set-NssmSetting -Arguments @('AppRotateFiles', '1')
Set-NssmSetting -Arguments @('AppRotateOnline', '1')
Set-NssmSetting -Arguments @('AppRotateBytes', '10485760')
Set-NssmSetting -Arguments @('AppExit', 'Default', 'Restart')
Set-NssmSetting -Arguments @('AppRestartDelay', '5000')
Set-NssmSetting -Arguments @('AppStopMethodConsole', '300000')
Set-NssmSetting -Arguments @('AppStopMethodWindow', '0')
Set-NssmSetting -Arguments @('AppStopMethodThreads', '0')
Set-NssmSetting -Arguments @('Start', 'SERVICE_AUTO_START')

& $nssm start $ServiceName
if ($LASTEXITCODE -ne 0) {
    throw "NSSM failed to start service '$ServiceName' (exit code $LASTEXITCODE)."
}

Write-Host "Service '$ServiceName' installed and started. Logs: $logDirectory"
