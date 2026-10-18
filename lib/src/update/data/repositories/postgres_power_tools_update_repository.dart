import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_release.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';

class PostgresPowerToolsUpdateRepository implements PowerToolsUpdateRepository {
  final ConnectionRepository connectionRepository;
  final PlatformInfo platform;

  const PostgresPowerToolsUpdateRepository({
    required this.connectionRepository,
    required this.platform,
  });

  @override
  Future<PowerToolsRelease?> getLatestRelease({required int serverId}) async {
    final linkColumn = platform.isWindows ? 'link_windows' : 'link_linux';
    final rows = await connectionRepository.execute(
      'SELECT au.id, current_version.current_version, '
      'new_version.new_version, new_version.$linkColumn AS repository '
      'FROM agent_update AS au '
      'LEFT JOIN agent_version AS current_version '
      'ON current_version.id = au.current_version_id '
      'LEFT JOIN agent_version AS new_version '
      'ON new_version.id = au.new_version_id '
      'WHERE au.server_id = \$1 '
      'ORDER BY au.version_date DESC, au.id DESC LIMIT 1',
      parameters: [serverId],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    if (row['id'] is! num ||
        row['current_version'] is! String ||
        row['new_version'] is! String ||
        row['repository'] is! String ||
        (row['repository'] as String).trim().isEmpty) {
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
  Future<void> synchronizeCurrentVersion({
    required int releaseId,
    required String currentVersion,
    required int serverId,
  }) async {
    final rows = await connectionRepository.execute(
      'WITH version_to_sync AS ('
      'SELECT id FROM agent_version WHERE new_version = \$1 '
      'ORDER BY created_at DESC, id DESC LIMIT 1'
      '), updated AS ('
      'UPDATE agent_update AS au '
      'SET current_version_id = version_to_sync.id '
      'FROM version_to_sync '
      'WHERE au.id = \$2 '
      'AND au.server_id = \$3 '
      'AND au.current_version_id IS DISTINCT FROM version_to_sync.id '
      'RETURNING au.id, au.current_version_id'
      ') '
      'SELECT version_to_sync.id AS version_id, '
      'COALESCE(updated.current_version_id, au.current_version_id) '
      'AS current_version_id '
      'FROM agent_update AS au '
      'LEFT JOIN version_to_sync ON TRUE '
      'LEFT JOIN updated ON updated.id = au.id '
      'WHERE au.id = \$2 AND au.server_id = \$3',
      parameters: [currentVersion, releaseId, serverId],
    );
    if (rows.isEmpty) {
      throw StateError(
        'O registro de atualização $releaseId não foi encontrado ao '
        'sincronizar a versão atual do PowerTools.',
      );
    }

    final row = rows.first;
    final versionId = row['version_id'];
    final currentVersionId = row['current_version_id'];
    if (versionId is! num) {
      throw StateError(
        'A versão $currentVersion do PowerTools não foi encontrada em '
        'agent_version.new_version.',
      );
    }
    if (currentVersionId is! num ||
        currentVersionId.toInt() != versionId.toInt()) {
      throw StateError(
        'Não foi possível sincronizar o ID da versão atual do PowerTools '
        'no registro de atualização $releaseId.',
      );
    }
  }

  @override
  Future<void> markCompleted({
    required int releaseId,
  }) async {
    final rows = await connectionRepository.execute(
      'UPDATE agent_update SET current_version_id = new_version_id, '
      'status = \$1, completion = \$2, error_message = NULL '
      'WHERE id = \$3 RETURNING id',
      parameters: [
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
