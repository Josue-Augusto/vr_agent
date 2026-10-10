import 'dart:io';

import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';

class PowerToolsCommand {
  final RunPowerToolsCommand _runPowerToolsCommand;

  const PowerToolsCommand(this._runPowerToolsCommand);

  Future<int> call(List<String> arguments) async {
    try {
      final result = await _runPowerToolsCommand(arguments);
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      return result.exitCode;
    } on FileSystemException catch (error) {
      stderr.writeln('Falha ao executar PowerTools: $error');
      return 1;
    }
  }
}
