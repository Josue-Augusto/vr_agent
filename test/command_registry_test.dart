import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:vr_agent/src/connection/data/datasources/postgres_connection_datasource.dart';
import 'package:vr_agent/src/connection/data/models/connection_model.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/di/injection.dart';
import 'package:vr_agent/src/terminal/data/repositories/power_tools_repository_impl.dart';
import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';
import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';
import 'package:vr_agent/src/terminal/presentation/cli/power_tools_command.dart';
import 'package:vr_agent/src/service/domain/repositories/system_service_installation_repository.dart';

void main() {
  group('CommandRegistry', () {
    test('dispatches command and preserves remaining arguments', () async {
      final registry = CommandRegistry();
      List<String>? receivedArguments;
      registry.register(
        AgentCommand(
          name: '-custom',
          description: 'Custom test command',
          action: (arguments) async {
            receivedArguments = arguments;
            return 7;
          },
        ),
      );
      registry.register(
        AgentCommand(
          name: '-help',
          description: 'Help',
          action: (_) async => 0,
        ),
      );

      final exitCode = await registry.run([
        '-a',
        '-custom',
        '--target',
        'nightly',
      ]);

      expect(exitCode, 7);
      expect(receivedArguments, ['--target', 'nightly']);
    });

    test('returns a usage error for unknown commands', () async {
      final registry = CommandRegistry();
      registry.register(
        AgentCommand(
          name: '-help',
          description: 'Help',
          action: (_) async => 0,
        ),
      );

      expect(await registry.run(['-a', '-missing']), 64);
    });

    test('requires an explicit execution mode', () async {
      final registry = CommandRegistry();
      registry.register(
        AgentCommand(
          name: '-help',
          description: 'Help',
          action: (_) async => 0,
        ),
      );

      expect(await registry.run(['-info']), 64);
    });

    test('PowerTools mode forwards the requested flag and arguments', () async {
      final repository = _FakePowerToolsRepository();
      final registry = CommandRegistry(
        powerToolsAction: PowerToolsCommand(
          RunPowerToolsCommand(repository),
        ).call,
      );

      final exitCode = await registry.run([
        '-p',
        '-info',
        '--details',
      ]);

      expect(exitCode, 9);
      expect(repository.arguments, ['-info', '--details']);
    });
  });

  group('PowerToolsRepositoryImpl', () {
    test('uses the fixed Windows installation directory', () {
      expect(
        PowerToolsRepositoryImpl.defaultExecutablePath(
          PlatformInfo.fromOperatingSystem('windows'),
        ),
        r'C:\vr\agent\PowerTools.exe',
      );
    });

    test('uses the fixed Linux installation directory', () {
      expect(
        PowerToolsRepositoryImpl.defaultExecutablePath(
          PlatformInfo.fromOperatingSystem('linux'),
        ),
        '/vr/agent/PowerTools',
      );
    });

    test(
      'forwards arguments and returns the process exit code',
      () async {
        final directory = await Directory.systemTemp.createTemp();
        final executable = File(
          '${directory.path}${Platform.pathSeparator}'
          'record_args${Platform.isWindows ? '.cmd' : '.sh'}',
        );
        final argumentsFile = File(
          '${directory.path}${Platform.pathSeparator}arguments.txt',
        );

        try {
          if (Platform.isWindows) {
            await executable.writeAsString(
              '@echo off\r\necho %* > "%~dp0arguments.txt"\r\nexit /b 7\r\n',
            );
          } else {
            await executable.writeAsString(
              r'''#!/bin/sh
printf "%s\n" "$@" > "$(dirname "$0")/arguments.txt"
exit 7
''',
            );
            await Process.run('chmod', ['+x', executable.path]);
          }

          final repository = PowerToolsRepositoryImpl(
            executablePath: executable.path,
          );
          final result = await repository.execute(['-backup', '--full']);

          expect(result.exitCode, 7);
          expect(await argumentsFile.readAsLines(), ['-backup', '--full']);
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: Platform.isWindows ? 'The test helper is a batch script, not a PowerTools executable.' : false,
    );

    test('reports a missing executable explicitly', () async {
      final directory = await Directory.systemTemp.createTemp();
      try {
        final repository = PowerToolsRepositoryImpl(
          executablePath: '${directory.path}${Platform.pathSeparator}missing',
        );

        await expectLater(
          repository.execute(['-backup']),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test(
      'kills a PowerTools process that exceeds its timeout',
      () async {
        final directory = await Directory.systemTemp.createTemp();
        final executable = File('${directory.path}/slow.sh');
        try {
          await executable.writeAsString('#!/bin/sh\nsleep 5\n');
          await Process.run('chmod', ['+x', executable.path]);

          final result =
              await PowerToolsRepositoryImpl(
                executablePath: executable.path,
              ).execute(
                ['-slow'],
                timeout: const Duration(milliseconds: 100),
              );

          expect(result.timedOut, isTrue);
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: Platform.isWindows ? 'The test helper is a shell script.' : false,
    );
  });

  test('PowerTools CLI command delegates to its use case', () async {
    final repository = _FakePowerToolsRepository();
    final command = PowerToolsCommand(RunPowerToolsCommand(repository));

    final exitCode = await command.call(['-backup']);

    expect(exitCode, 9);
    expect(repository.arguments, ['-backup']);
  });

  test('agent info command gets values through its use case', () async {
    final getAgentInfo = GetAgentInfo(
      name: 'VR Agent',
      version: '1.2.3',
      platform: 'Linux',
    );

    expect(getAgentInfo().name, 'VR Agent');
    expect(getAgentInfo().version, '1.2.3');
    expect(getAgentInfo().platform, 'Linux');
  });

  test('dependency injection routes CLI commands through the repository', () async {
    final repository = _FakePowerToolsRepository();
    final dependencies = createAppDependencies(
      platformInfo: PlatformInfo.fromOperatingSystem('windows'),
      connectionDatasource: _UnusedConnectionDatasource(),
      powerToolsRepository: repository,
    );

    final exitCode = await dependencies.commandRegistry.run([
      '-p',
      '-backup',
      '--full',
    ]);

    expect(exitCode, 9);
    expect(repository.arguments, ['-backup', '--full']);
  });

  test('dependency injection routes service installation through its repository', () async {
    final serviceInstallation = _FakeSystemServiceInstallationRepository();
    final dependencies = createAppDependencies(
      platformInfo: PlatformInfo.fromOperatingSystem('windows'),
      connectionDatasource: _UnusedConnectionDatasource(),
      systemServiceInstallationRepository: serviceInstallation,
    );

    expect(await dependencies.commandRegistry.run(['-a', '-install', '-service']), 0);
    expect(serviceInstallation.installed, isTrue);
  });

  test('rejects service installation without the install selector', () async {
    final registry = CommandRegistry()
      ..register(
        AgentCommand(
          name: '-help',
          description: 'Help',
          action: (_) async => 0,
        ),
      );

    expect(await registry.run(['-a', '-service']), 64);
  });
}

class _FakePowerToolsRepository implements PowerToolsRepository {
  List<String>? arguments;

  @override
  Future<PowerToolsResult> execute(
    List<String> arguments, {
    Duration? timeout,
  }) async {
    this.arguments = arguments;
    return const PowerToolsResult(exitCode: 9, stdout: '', stderr: '');
  }
}

class _UnusedConnectionDatasource implements PostgreSQLConnectionDatasource {
  @override
  Future<Connection> openConnection({String? user, String? password}) => throw UnimplementedError();

  @override
  Future<ConnectionModel> getConfig() => throw UnimplementedError();
}

class _FakeSystemServiceInstallationRepository implements SystemServiceInstallationRepository {
  var installed = false;

  @override
  Future<void> install() async {
    installed = true;
  }
}
