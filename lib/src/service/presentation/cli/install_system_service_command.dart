import 'dart:io';

import 'package:vr_agent/src/service/domain/usecases/install_system_service.dart';

class InstallSystemServiceCommand {
  final InstallSystemService _installSystemService;

  const InstallSystemServiceCommand(this._installSystemService);

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -a -service');
      return 64;
    }

    try {
      await _installSystemService();
      stdout.writeln('Serviço do VR Agent instalado e iniciado.');
      return 0;
    } catch (error) {
      stderr.writeln('Falha ao instalar o serviço do VR Agent: $error');
      return 1;
    }
  }
}
