import 'dart:io';

import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';

class CrontabCommand {
  final FilePathRepository filePathRepository;

  const CrontabCommand({required this.filePathRepository});

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -crontab');
      return 64;
    }
    try {
      final crontab = await filePathRepository.readJson(fileName: '.crontab');
      final tasks = crontab['tasks'];
      if (tasks is! List) {
        throw const FormatException('O arquivo .crontab não contém uma lista "tasks".');
      }
      if (tasks.isEmpty) {
        stdout.writeln('O crontab não contém tarefas.');
        return 0;
      }
      for (final task in tasks) {
        if (task is! Map<String, dynamic>) {
          throw const FormatException('Uma tarefa do .crontab não é um objeto JSON.');
        }
        stdout.writeln(
          '${task['id']} | ${task['enabled'] == true ? 'habilitada' : 'desabilitada'} '
          '| ${task['schedule']} (${task['timezone']}) | ${task['command']} '
          '| ${task['name']}',
        );
      }
      return 0;
    } on FormatException catch (error) {
      stderr.writeln('Não foi possível ler o .crontab: $error');
      return 1;
    } on FileSystemException catch (error) {
      stderr.writeln('Não foi possível acessar o .crontab: $error');
      return 1;
    }
  }
}
