import 'dart:io';

import 'package:test/test.dart';
import 'package:vr_agent/cli/agent_command.dart';
import 'package:vr_agent/cli/command_registry.dart';

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

      final exitCode = await registry.run(['-custom', '--target', 'nightly']);

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

      expect(await registry.run(['-missing']), 64);
    });
  });

  group('PowerToolsCommand', () {
    test(
      'forwards flags and returns the PowerTools exit code',
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

          final exitCode = await PowerToolsCommand(
            executable: executable.path,
          ).call(['-backup', '--full']);

          expect(exitCode, 7);
          expect(await argumentsFile.readAsLines(), ['-backup', '--full']);
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: Platform.isWindows ? 'The test helper is a batch script, not a PowerTools executable.' : false,
    );

    test('reports a missing PowerTools executable', () async {
      final directory = await Directory.systemTemp.createTemp();
      try {
        expect(
          await PowerToolsCommand(
            executable: '${directory.path}${Platform.pathSeparator}missing',
          ).call(['-backup']),
          1,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
