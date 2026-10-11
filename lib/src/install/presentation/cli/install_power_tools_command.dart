import 'dart:io';

import 'package:vr_agent/src/install/domain/entities/power_tools_install_result.dart';
import 'package:vr_agent/src/install/domain/usecases/install_power_tools.dart';

class InstallPowerToolsCommand {
  final InstallPowerTools _installPowerTools;

  const InstallPowerToolsCommand(this._installPowerTools);

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -a install');
      return 64;
    }

    try {
      final result = await _installPowerTools();
      switch (result.status) {
        case PowerToolsInstallStatus.alreadyInstalled:
          stdout.writeln(
            'O PowerTools já está instalado. Use -a -update para atualizar.',
          );
          return 0;
        case PowerToolsInstallStatus.installed:
          stdout.writeln('PowerTools ${result.version} instalado com sucesso.');
          return 0;
      }
    } catch (error) {
      stderr.writeln('Falha ao instalar o PowerTools: $error');
      return 1;
    }
  }
}
