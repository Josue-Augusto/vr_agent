import 'dart:io';

import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';

class UpdateCrontabCommand {
  final SyncCrontab syncCrontab;

  const UpdateCrontabCommand({required this.syncCrontab});

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -a -update -crontab');
      return 64;
    }
    try {
      final count = await syncCrontab();
      stdout.writeln('Crontab atualizado: $count tarefa(s).');
      return 0;
    } on Exception catch (error) {
      stderr.writeln('Falha ao atualizar o crontab: $error');
      return 1;
    }
  }
}
