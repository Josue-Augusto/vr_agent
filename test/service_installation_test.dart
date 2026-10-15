import 'dart:io';

import 'package:test/test.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/service/data/repositories/platform_system_service_installation_repository.dart';

void main() {
  group('PlatformSystemServiceInstallationRepository', () {
    test('generates and runs the Windows NSSM installer script', () async {
      final directory = await Directory.systemTemp.createTemp();
      final executable = File('${directory.path}${Platform.pathSeparator}vr_agent.exe');
      await executable.writeAsBytes([]);
      String? launchedScript;

      try {
        final installer = PlatformSystemServiceInstallationRepository(
          platform: PlatformInfo.fromOperatingSystem('windows'),
          installDirectory: directory.path,
          processRunner: (command, arguments) async {
            expect(command, 'powershell.exe');
            launchedScript = arguments.last;
            return ProcessResult(1, 0, 'Service installed', '');
          },
        );

        await installer.install();

        final script = await File(launchedScript!).readAsString();
        expect(script, contains('winget.Source install --id NSSM.NSSM'));
        expect(script, contains('Microsoft\\WinGet\\Links\\nssm.exe'));
        expect(script, contains("'AppParameters', '--service'"));
        expect(script, contains("'SERVICE_AUTO_START'"));
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('writes and enables the Linux systemd unit', () async {
      final directory = await Directory.systemTemp.createTemp();
      final executable = File('${directory.path}${Platform.pathSeparator}vr_agent');
      final unitPath = '${directory.path}${Platform.pathSeparator}vr-agent.service';
      final calls = <String>[];
      await executable.writeAsBytes([]);

      try {
        final installer = PlatformSystemServiceInstallationRepository(
          platform: PlatformInfo.fromOperatingSystem('linux'),
          installDirectory: directory.path,
          systemdUnitPath: unitPath,
          processRunner: (command, arguments) async {
            calls.add('$command ${arguments.join(' ')}');
            if (command == 'id') return ProcessResult(1, 0, '0\n', '');
            return ProcessResult(1, 0, '', '');
          },
        );

        await installer.install();

        final unit = await File(unitPath).readAsString();
        expect(unit, contains('WorkingDirectory=${directory.path}'));
        expect(unit, contains('ExecStart=${executable.path} --service'));
        expect(unit, contains('Restart=on-failure'));
        expect(calls, [
          'id -u',
          'systemctl daemon-reload',
          'systemctl enable vr-agent.service',
          'systemctl restart vr-agent.service',
        ]);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('refuses Linux service installation without root privileges', () async {
      final directory = await Directory.systemTemp.createTemp();
      final executable = File('${directory.path}${Platform.pathSeparator}vr_agent');
      final unitPath = '${directory.path}${Platform.pathSeparator}vr-agent.service';
      await executable.writeAsBytes([]);

      try {
        final installer = PlatformSystemServiceInstallationRepository(
          platform: PlatformInfo.fromOperatingSystem('linux'),
          installDirectory: directory.path,
          systemdUnitPath: unitPath,
          processRunner: (_, _) async => ProcessResult(1, 0, '1000\n', ''),
        );

        await expectLater(installer.install(), throwsA(isA<StateError>()));
        expect(await File(unitPath).exists(), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('reports a missing platform executable', () async {
      final directory = await Directory.systemTemp.createTemp();
      try {
        final installer = PlatformSystemServiceInstallationRepository(
          platform: PlatformInfo.fromOperatingSystem('linux'),
          installDirectory: directory.path,
        );

        await expectLater(installer.install(), throwsA(isA<FileSystemException>()));
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
