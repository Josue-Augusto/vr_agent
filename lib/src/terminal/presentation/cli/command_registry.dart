import 'dart:io';

import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';
import 'package:vr_agent/src/crontab/presentation/cli/crontab_command.dart';
import 'package:vr_agent/src/crontab/presentation/cli/update_crontab_command.dart';
import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/presentation/cli/help_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/info_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/version_command.dart';

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

CommandRegistry createDefaultCommandPalette({
  required GetAgentInfo getAgentInfo,
  required RunPowerToolsCommand runPowerToolsCommand,
  required SyncCrontab syncCrontab,
  required FilePathRepository filePathRepository,
}) {
  final registry = CommandRegistry();
  final powerTools = PowerToolsCommand(runPowerToolsCommand);
  final updateCrontab = UpdateCrontabCommand(syncCrontab: syncCrontab);

  registry.register(
    AgentCommand(
      name: '-version',
      description: 'Exibe a versão do VR Agent.',
      action: VersionCommand(getAgentInfo).call,
    ),
  );
  registry.register(
    AgentCommand(
      name: '-info',
      description: 'Exibe informações sobre o VR Agent.',
      action: InfoCommand(getAgentInfo).call,
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
      description: 'Atualiza o PowerTools ou use -update -crontab para sincronizar tarefas.',
      action: (arguments) {
        if (arguments.isNotEmpty && arguments.first == '-crontab') {
          return updateCrontab.call(arguments.skip(1).toList(growable: false));
        }
        return powerTools.call(['-update', ...arguments]);
      },
    ),
  );
  registry.register(
    AgentCommand(
      name: '-crontab',
      description: 'Lista as tarefas locais do crontab.',
      action: CrontabCommand(filePathRepository: filePathRepository).call,
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
