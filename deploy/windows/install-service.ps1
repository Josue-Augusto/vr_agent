#Requires -RunAsAdministrator
param(
    [string]$NssmPath = '',
    [string]$ServiceName = 'VRAgent',
    [string]$InstallDirectory = $PSScriptRoot,
    [string]$ExecutablePath = (Join-Path $PSScriptRoot 'vr_agent.exe')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
    throw "Agent executable not found: $ExecutablePath"
}

if (-not $NssmPath -or -not (Test-Path -LiteralPath $NssmPath -PathType Leaf)) {
    $nssmCommand = Get-Command nssm.exe -ErrorAction SilentlyContinue
    if ($null -ne $nssmCommand) {
        $NssmPath = $nssmCommand.Source
    } else {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($null -eq $winget) {
            throw 'winget was not found. Install App Installer or provide -NssmPath.'
        }
        & $winget.Source install --id NSSM.NSSM -e --accept-source-agreements --accept-package-agreements
        $wingetExitCode = $LASTEXITCODE

        $candidatePaths = @(
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\nssm.exe'),
            (Join-Path $env:ProgramFiles 'NSSM\win64\nssm.exe'),
            'C:\nssm\win64\nssm.exe'
        )
        $nssmCommand = Get-Command nssm.exe -ErrorAction SilentlyContinue
        if ($null -ne $nssmCommand) {
            $NssmPath = $nssmCommand.Source
        } else {
            $NssmPath = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        }
        if (-not $NssmPath -and $wingetExitCode -ne 0) {
            throw "winget failed to install NSSM (exit code $wingetExitCode), and nssm.exe could not be located."
        }
    }
}

$nssm = (Resolve-Path -LiteralPath $NssmPath).Path
$installDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$executable = (Resolve-Path -LiteralPath $ExecutablePath).Path
$logDirectory = Join-Path $installDirectory 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Invoke-Nssm {
    param([string[]]$Arguments)

    & $nssm @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "NSSM failed to run '$($Arguments[0])' for service '$ServiceName' (exit code $LASTEXITCODE)."
    }
}

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $service) {
    Invoke-Nssm -Arguments @('install', $ServiceName, $executable)
} else {
    if ($service.Status -ne 'Stopped') {
        Invoke-Nssm -Arguments @('stop', $ServiceName)
    }
    Invoke-Nssm -Arguments @('set', $ServiceName, 'Application', $executable)
}

Invoke-Nssm -Arguments @('set', $ServiceName, 'AppDirectory', $installDirectory)
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppParameters', '--service')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppStdout', (Join-Path $logDirectory 'service-out.log'))
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppStderr', (Join-Path $logDirectory 'service-error.log'))
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppRotateFiles', '1')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppRotateOnline', '1')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppRotateBytes', '10485760')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppExit', 'Default', 'Restart')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppRestartDelay', '5000')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppStopMethodConsole', '300000')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppStopMethodWindow', '0')
Invoke-Nssm -Arguments @('set', $ServiceName, 'AppStopMethodThreads', '0')
Invoke-Nssm -Arguments @('set', $ServiceName, 'Start', 'SERVICE_AUTO_START')

function Get-ServiceStartupDiagnostics {
    $details = @()
    $currentService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $currentService) {
        $details += "Service '$ServiceName' could not be found."
    } else {
        $details += "Current service status: $($currentService.Status)"
    }

    foreach ($logPath in @(
        (Join-Path $logDirectory 'service-error.log'),
        (Join-Path $logDirectory 'service-out.log')
    )) {
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $logContent = @(Get-Content -LiteralPath $logPath -Tail 50 -ErrorAction SilentlyContinue)
            if ($logContent.Count -gt 0) {
                $details += "Recent contents of ${logPath}:`n$($logContent -join "`n")"
            }
        }
    }

    return $details -join "`n"
}

try {
    Invoke-Nssm -Arguments @('start', $ServiceName)
} catch {
    $diagnostics = Get-ServiceStartupDiagnostics
    throw "$($_.Exception.Message)`n$diagnostics"
}

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $service -or $service.Status -ne 'Running') {
    $diagnostics = Get-ServiceStartupDiagnostics
    throw "Service '$ServiceName' did not reach the Running state.`n$diagnostics"
}

Write-Host "Service '$ServiceName' installed and started. Logs: $logDirectory"
