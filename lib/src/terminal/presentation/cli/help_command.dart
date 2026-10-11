import 'dart:io';

import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';

class HelpCommand {
  final List<AgentCommand> Function() commands;

  const HelpCommand(this.commands);

  Future<int> call(List<String> arguments) async {
    stdout.writeln('Uso: vr_agent <-a|-p> <flag> [argumentos]');
    stdout.writeln();
    for (final command in commands()) {
      stdout.writeln('  ${('-a ${command.name}').padRight(20)} ${command.description}');
    }
    stdout.writeln('  ${'-p <flag>'.padRight(20)} Encaminha a flag e os argumentos ao PowerTools.');
    return 0;
  }
}
