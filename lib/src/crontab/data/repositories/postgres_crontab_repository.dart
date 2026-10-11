import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';

class PostgresCrontabRepository implements CrontabRepository {
  final ConnectionRepository connectionRepository;

  const PostgresCrontabRepository({required this.connectionRepository});

  @override
  Future<List<AgentTask>> getTasksForServer(int serverId) async {
    final rows = await connectionRepository.execute(
      'SELECT id, server_id, name, description, command, schedule, timezone, '
      'enabled, timeout_seconds, max_retries, retry_delay_sec, run_as_user, priority '
      'FROM agent_tasks WHERE server_id = \$1 ORDER BY priority, id',
      parameters: [serverId],
    );
    return rows.map(AgentTask.fromJson).toList(growable: false);
  }

  @override
  Future<int> startTaskRun({
    required AgentTask task,
    required int attempt,
    required String triggeredBy,
  }) async {
    final rows = await connectionRepository.execute(
      'INSERT INTO agent_task_runs (task_id, server_id, status, attempt, triggered_by) '
      'VALUES (\$1, \$2, \'running\', \$3, \$4) RETURNING id',
      parameters: [task.id, task.serverId, attempt, triggeredBy],
    );
    if (rows.isEmpty || rows.first['id'] is! num) {
      throw StateError('O banco não retornou o identificador da execução da tarefa ${task.id}.');
    }
    return (rows.first['id'] as num).toInt();
  }

  @override
  Future<void> finishTaskRun({
    required int runId,
    required AgentTask task,
    required DateTime startedAt,
    required String status,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required String? errorMessage,
  }) async {
    final finishedAt = DateTime.now().toUtc();
    await connectionRepository.execute(
      'UPDATE agent_task_runs SET finished_at = \$1, duration_ms = \$2, status = \$3, '
      'exit_code = \$4, stdout = \$5, stderr = \$6, error_message = \$7 WHERE id = \$8',
      parameters: [
        finishedAt,
        finishedAt.difference(startedAt).inMilliseconds,
        status,
        exitCode,
        stdout,
        stderr,
        errorMessage,
        runId,
      ],
    );
    await connectionRepository.execute(
      'UPDATE agent_tasks SET last_run_at = \$1, last_status = \$2, last_exit_code = \$3, '
      'last_error = \$4, consecutive_failures = CASE WHEN \$2 = \'success\' '
      'THEN 0 ELSE consecutive_failures + 1 END, updated_at = \$1 WHERE id = \$5',
      parameters: [
        finishedAt,
        status,
        exitCode,
        errorMessage,
        task.id,
      ],
    );
  }
}
