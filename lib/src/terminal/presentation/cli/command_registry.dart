import 'dart:io';

import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';
import 'package:vr_agent/src/crontab/presentation/cli/crontab_command.dart';
import 'package:vr_agent/src/crontab/presentation/cli/update_crontab_command.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/help_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/info_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/version_command.dart';
import 'package:vr_agent/src/update/domain/usecases/update_power_tools.dart';
import 'package:vr_agent/src/update/presentation/cli/update_power_tools_command.dart';

class CommandRegistry {
  final Map<String, AgentCommand> _commands = {};
  final CommandAction? _powerToolsAction;

  CommandRegistry({this._powerToolsAction});

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

    final mode = arguments.first;
    if (mode != '-a' && mode != '-p') {
      stderr.writeln('O comando deve começar com "-a" (Agent) ou "-p" (PowerTools).');
      await _commands['-help']!.action(const []);
      return 64;
    }
    if (arguments.length < 2 || !arguments[1].startsWith('-')) {
      stderr.writeln('Informe a flag do comando após "$mode".');
      await _commands['-help']!.action(const []);
      return 64;
    }

    final commandName = arguments[1];
    final commandArguments = arguments.skip(2).toList(growable: false);
    if (mode == '-p') {
      final powerToolsAction = _powerToolsAction;
      if (powerToolsAction == null) {
        stderr.writeln('A execução do PowerTools não está configurada.');
        return 1;
      }
      return powerToolsAction([commandName, ...commandArguments]);
    }

    final command = _commands[commandName];
    if (command == null) {
      stderr.writeln('Comando do agente desconhecido: $commandName');
      await _commands['-help']!.action(const []);
      return 64;
    }

    return command.action(commandArguments);
  }
}

CommandRegistry createDefaultCommandPalette({
  required GetAgentInfo getAgentInfo,
  required RunPowerToolsCommand runPowerToolsCommand,
  required SyncCrontab syncCrontab,
  required FilePathRepository filePathRepository,
  UpdatePowerTools? updatePowerTools,
}) {
  final powerTools = PowerToolsCommand(runPowerToolsCommand);
  final registry = CommandRegistry(powerToolsAction: powerTools.call);
  final updateCrontab = UpdateCrontabCommand(syncCrontab: syncCrontab);
  final updatePowerToolsCommand = updatePowerTools == null
      ? null
      : UpdatePowerToolsCommand(updatePowerTools);

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
      name: '-update',
      description:
          'Atualiza o PowerTools; use -a -update -crontab para sincronizar tarefas.',
      action: (arguments) async {
        if (arguments.isEmpty) {
          final command = updatePowerToolsCommand;
          if (command == null) {
            stderr.writeln('A atualização do PowerTools não está configurada.');
            return 1;
          }
          return command.call(const []);
        }
        if (arguments.length == 1 && arguments.first == '-crontab') {
          return updateCrontab.call(arguments.skip(1).toList(growable: false));
        }
        stderr.writeln('Uso: vr_agent -a -update [-crontab]');
        return 64;
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
      name: '-help',
      description: 'Exibe os comandos disponíveis.',
      action: HelpCommand(() => registry.commands).call,
    ),
  );

  return registry;
}
