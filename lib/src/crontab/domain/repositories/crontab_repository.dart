import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';

abstract interface class CrontabRepository {
  Future<List<AgentTask>> getTasksForServer(int serverId);
  Future<int> startTaskRun({
    required AgentTask task,
    required int attempt,
    required String triggeredBy,
  });
  Future<void> finishTaskRun({
    required int runId,
    required AgentTask task,
    required DateTime startedAt,
    required String status,
    required int? exitCode,
    required String stdout,
    required String stderr,
    required String? errorMessage,
  });
}
