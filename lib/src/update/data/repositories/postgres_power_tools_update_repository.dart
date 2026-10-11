import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_release.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';

class PostgresPowerToolsUpdateRepository
    implements PowerToolsUpdateRepository {
  final ConnectionRepository connectionRepository;

  const PostgresPowerToolsUpdateRepository({
    required this.connectionRepository,
  });

  @override
  Future<PowerToolsRelease?> getLatestRelease({required int serverId}) async {
    final rows = await connectionRepository.execute(
      'SELECT id, current_version, new_version, repository FROM agent_update '
      'WHERE server_id = \$1 ORDER BY version_date DESC, id DESC LIMIT 1',
      parameters: [serverId],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    if (row['id'] is! num ||
        row['current_version'] is! String ||
        row['new_version'] is! String ||
        row['repository'] is! String) {
      throw const FormatException(
        'O registro de atualização do PowerTools possui dados inválidos.',
      );
    }
    return PowerToolsRelease(
      id: (row['id'] as num).toInt(),
      currentVersion: row['current_version'] as String,
      newVersion: row['new_version'] as String,
      repository: row['repository'] as String,
    );
  }

  @override
  Future<void> markCompleted({
    required int releaseId,
    required String installedVersion,
  }) async {
    final rows = await connectionRepository.execute(
      'UPDATE agent_update SET current_version = \$1, status = \$2, '
      'completion = \$3, error_message = NULL WHERE id = \$4 RETURNING id',
      parameters: [
        installedVersion,
        'completed',
        DateTime.now().toUtc().toIso8601String(),
        releaseId,
      ],
    );
    if (rows.isEmpty) {
      throw StateError(
        'O registro de atualização $releaseId não foi encontrado ao concluir.',
      );
    }
  }

  @override
  Future<void> markFailed({
    required int releaseId,
    required String errorMessage,
  }) async {
    final rows = await connectionRepository.execute(
      'UPDATE agent_update SET status = \$1, completion = \$2, '
      'error_message = \$3 WHERE id = \$4 RETURNING id',
      parameters: [
        'failed',
        DateTime.now().toUtc().toIso8601String(),
        errorMessage,
        releaseId,
      ],
    );
    if (rows.isEmpty) {
      throw StateError(
        'O registro de atualização $releaseId não foi encontrado ao registrar a falha.',
      );
    }
  }
}
