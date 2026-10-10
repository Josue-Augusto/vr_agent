import 'dart:io';

import 'package:vr_agent/core/feature/filePath/domain/entities/platform_info.dart';
import 'package:vr_agent/core/tools/constants.dart';

typedef CommandAction = Future<int> Function(List<String> arguments);

class AgentCommand {
  final String name;
  final String description;
  final CommandAction action;

  const AgentCommand({required this.name, required this.description, required this.action});
}

class VersionCommand {
  Future<int> call(List<String> arguments) async {
    stdout.writeln('$APP_NAME $VERSION');
    return 0;
  }
}

class InfoCommand {
  Future<int> call(List<String> arguments) async {
    stdout.writeln('$APP_NAME $VERSION');
    stdout.writeln('Plataforma: ${PlatformInfo.current.displayName}');
    return 0;
  }
}

class HelpCommand {
  final List<AgentCommand> Function() commands;

  const HelpCommand(this.commands);

  Future<int> call(List<String> arguments) async {
    stdout.writeln('Uso: vr_agent <comando> [argumentos]');
    stdout.writeln();
    for (final command in commands()) {
      stdout.writeln('  ${command.name.padRight(12)} ${command.description}');
    }
    return 0;
  }
}

class PowerToolsCommand {
  final String executable;

  const PowerToolsCommand({required this.executable});

  Future<int> call(List<String> arguments) async {
    final executableFile = File(executable);
    if (!await executableFile.exists()) {
      stderr.writeln('PowerTools não encontrado: ${executableFile.path}');
      return 1;
    }

    final result = await Process.run(
      executableFile.path,
      arguments,
      workingDirectory: executableFile.parent.path,
      runInShell: false,
    );
    if (result.stdout case final String output when output.isNotEmpty) {
      stdout.write(output);
    }
    if (result.stderr case final String output when output.isNotEmpty) {
      stderr.write(output);
    }
    return result.exitCode;
  }
}
