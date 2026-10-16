import 'dart:io';

import 'package:vr_agent/src/update/domain/entities/power_tools_update_result.dart';
import 'package:vr_agent/src/update/domain/usecases/update_power_tools.dart';

class UpdatePowerToolsCommand {
  final UpdatePowerTools _updatePowerTools;

  const UpdatePowerToolsCommand(this._updatePowerTools);

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -a -update -powertools');
      return 64;
    }

    try {
      final result = await _updatePowerTools();
      switch (result.status) {
        case PowerToolsUpdateStatus.noRelease:
          stdout.writeln(
            'Nenhuma atualização do PowerTools foi cadastrada '
            '(versão atual: ${result.currentVersion}).',
          );
          break;
        case PowerToolsUpdateStatus.upToDate:
          stdout.writeln(
            'PowerTools já está atualizado (${result.currentVersion}).',
          );
          break;
        case PowerToolsUpdateStatus.updated:
          stdout.writeln('PowerTools atualizado para ${result.newVersion}.');
          break;
      }
      return 0;
    } catch (error) {
      stderr.writeln('Falha ao atualizar o PowerTools: $error');
      return 1;
    }
  }
}
