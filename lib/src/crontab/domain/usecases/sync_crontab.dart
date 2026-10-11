import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';

class SyncCrontab {
  final FilePathRepository filePathRepository;
  final CrontabRepository crontabRepository;
  final ConnectionRepository connectionRepository;

  const SyncCrontab({
    required this.filePathRepository,
    required this.crontabRepository,
    required this.connectionRepository,
  });

  Future<int> call() async {
    await connectionRepository.init();
    try {
      final config = await filePathRepository.readJson(fileName: '.env');
      final serverId = config['server_id'];
      if (serverId is! num || serverId <= 0 || serverId != serverId.toInt()) {
        throw const FormatException('O campo server_id do .env deve ser um inteiro positivo.');
      }

      final tasks = await crontabRepository.getTasksForServer(serverId.toInt());
      await filePathRepository.writeJson(
        fileName: '.crontab',
        data: {
          'server_id': serverId.toInt(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
        },
      );
      return tasks.length;
    } finally {
      await connectionRepository.close();
    }
  }
}
