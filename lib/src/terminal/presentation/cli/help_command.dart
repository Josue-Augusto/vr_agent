import 'dart:io';

import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';

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
