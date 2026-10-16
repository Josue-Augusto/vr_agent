import 'dart:io';

import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/data/repositories/file_path_repository_impl.dart';
import 'package:vr_agent/src/service/domain/repositories/system_service_installation_repository.dart';

typedef ServiceProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class PlatformSystemServiceInstallationRepository implements SystemServiceInstallationRepository {
  final PlatformInfo platform;
  final ServiceProcessRunner _processRunner;
  final String _installDirectory;
  final String _systemdUnitPath;

  PlatformSystemServiceInstallationRepository({
    required this.platform,
    ServiceProcessRunner? processRunner,
    String? installDirectory,
    String? systemdUnitPath,
  }) : _processRunner = processRunner ?? Process.run,
       _installDirectory = installDirectory ?? FilePathRepositoryImpl.directoryPathFor(platform),
       _systemdUnitPath = systemdUnitPath ?? '/etc/systemd/system/vr-agent.service';

  @override
  Future<void> install() async {
    final executableName = platform.isWindows ? 'vr_agent.exe' : 'vr_agent';
    final executablePath = '$_installDirectory${Platform.pathSeparator}$executableName';
    if (!await File(executablePath).exists()) {
      throw FileSystemException(
        'Compile e coloque o executável em "$_installDirectory" antes de instalar o serviço.',
        executablePath,
      );
    }

    if (platform.isWindows) {
      await _installWindows();
    } else {
      await _installLinux(executablePath);
    }
  }

  Future<void> _installWindows() async {
    final scriptPath = '$_installDirectory${Platform.pathSeparator}install-service.ps1';
    await File(scriptPath).writeAsString(windowsInstallerScript);
    final result = await _processRunner(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
      ],
    );
    _checkResult(result, 'Executar o instalador Windows');
  }

  Future<void> _installLinux(String executablePath) async {
    final identity = await _processRunner('id', ['-u']);
    _checkResult(identity, 'Verificar privilégios de instalação', displayOutput: false);
    if (identity.stdout.toString().trim() != '0') {
      throw StateError('Execute o comando com sudo/root para instalar o serviço systemd.');
    }

    final unitFile = File(_systemdUnitPath);
    await unitFile.writeAsString(_linuxUnit(executablePath));
    await _runChecked('systemctl', ['daemon-reload']);
    await _runChecked('systemctl', ['enable', 'vr-agent.service']);
    await _runChecked('systemctl', ['restart', 'vr-agent.service']);
  }

  Future<void> _runChecked(String executable, List<String> arguments) async {
    final result = await _processRunner(executable, arguments);
    _checkResult(result, 'Executar $executable ${arguments.join(' ')}');
  }

  void _checkResult(ProcessResult result, String operation, {bool displayOutput = true}) {
    final stdoutText = result.stdout.toString().trim();
    final stderrText = result.stderr.toString().trim();
    if (displayOutput && stdoutText.isNotEmpty) stdout.writeln(stdoutText);
    if (result.exitCode != 0) {
      final detail = stderrText.isEmpty ? stdoutText : stderrText;
      throw StateError('$operation falhou (código ${result.exitCode}): $detail');
    }
    if (displayOutput && stderrText.isNotEmpty) stderr.writeln(stderrText);
  }

  String _linuxUnit(String executablePath) =>
      '''
[Unit]
Description=VR Agent scheduled task runner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$_installDirectory
ExecStart=$executablePath --service
Restart=on-failure
RestartSec=5s
KillSignal=SIGTERM
TimeoutStopSec=300s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
''';

  static const windowsInstallerScript = r'''#Requires -RunAsAdministrator
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

if (-not $NssmPath -or -not (Test-Path -LiteralPath $NssmPath -PathType Leaf)) {
    throw 'NSSM installation completed, but nssm.exe could not be located.'
}

$nssm = (Resolve-Path -LiteralPath $NssmPath).Path
$InstallDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$ExecutablePath = (Resolve-Path -LiteralPath $ExecutablePath).Path
$logDirectory = Join-Path $InstallDirectory 'logs'
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
    Invoke-Nssm -Arguments @('install', $ServiceName, $ExecutablePath)
} else {
    if ($service.Status -ne 'Stopped') {
        Invoke-Nssm -Arguments @('stop', $ServiceName)
    }
    Invoke-Nssm -Arguments @('set', $ServiceName, 'Application', $ExecutablePath)
}

Invoke-Nssm -Arguments @('set', $ServiceName, 'AppDirectory', $InstallDirectory)
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
''';
}
