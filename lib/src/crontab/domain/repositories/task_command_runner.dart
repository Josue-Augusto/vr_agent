import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';

abstract interface class TaskCommandRunner {
  Future<TaskRunResult> run(AgentTask task);
}
