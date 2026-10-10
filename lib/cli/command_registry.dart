import 'dart:io';

import 'package:vr_agent/cli/agent_command.dart';

class CommandRegistry {
  final Map<String, AgentCommand> _commands = {};

  void register(AgentCommand command) {
    if (_commands.containsKey(command.name)) {
      throw ArgumentError.value(command.name, 'command.name', 'Already registered');
    }
    _commands[command.name] = command;
  }

  List<AgentCommand> get commands => List.unmodifiable(_commands.values);

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      return _commands['-help']!.action(const []);
    }

    final command = _commands[arguments.first];
    if (command == null) {
      stderr.writeln('Comando desconhecido: ${arguments.first}');
      await _commands['-help']!.action(const []);
      return 64;
    }

    return command.action(arguments.skip(1).toList(growable: false));
  }
}

CommandRegistry createDefaultCommandPalette({String? executablePath}) {
  final registry = CommandRegistry();
  final powerToolsPath =
      executablePath ??
      '${File(Platform.resolvedExecutable).parent.path}'
          '${Platform.pathSeparator}PowerTools'
          '${Platform.isWindows ? '.exe' : ''}';
  final powerTools = PowerToolsCommand(executable: powerToolsPath);

  registry.register(
    AgentCommand(
      name: '-version',
      description: 'Exibe a versão do VR Agent.',
      action: VersionCommand().call,
    ),
  );
  registry.register(
    AgentCommand(
      name: '-check',
      description: 'Verifica atualizações do PowerTools.',
      action: (arguments) => powerTools.call(['-check', ...arguments]),
    ),
  );
  registry.register(
    AgentCommand(
      name: '-update',
      description: 'Atualiza o PowerTools.',
      action: (arguments) => powerTools.call(['-update', ...arguments]),
    ),
  );
  registry.register(
    AgentCommand(
      name: '-backup',
      description: 'Executa o backup do banco de dados.',
      action: (arguments) => powerTools.call(['-backup', ...arguments]),
    ),
  );
  registry.register(
    AgentCommand(
      name: '-help',
      description: 'Exibe os comandos disponíveis.',
      action: HelpCommand(() => registry.commands).call,
    ),
  );

  return registry;
}
