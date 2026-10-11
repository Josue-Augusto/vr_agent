import 'dart:async';

import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/crontab/domain/repositories/task_command_runner.dart';

class RunCrontabTask {
  final CrontabRepository crontabRepository;
  final TaskCommandRunner taskCommandRunner;

  const RunCrontabTask({
    required this.crontabRepository,
    required this.taskCommandRunner,
  });

  Future<void> call(AgentTask task) async {
    for (var attempt = 1; attempt <= task.maxRetries + 1; attempt++) {
      final startedAt = DateTime.now().toUtc();
      final runId = await crontabRepository.startTaskRun(
        task: task,
        attempt: attempt,
        triggeredBy: attempt == 1 ? 'schedule' : 'retry',
      );
      late final TaskRunResult result;
      try {
        result = await taskCommandRunner.run(task).timeout(
          Duration(seconds: task.timeoutSeconds),
          onTimeout: () => TaskRunResult(
            exitCode: -1,
            stdout: '',
            stderr: '',
            errorMessage: 'A tarefa excedeu o limite de tempo.',
            timedOut: true,
          ),
        );
      } catch (error) {
        result = TaskRunResult(
          exitCode: -1,
          stdout: '',
          stderr: '',
          errorMessage: error.toString(),
        );
      }

      final status = result.timedOut
          ? 'timeout'
          : result.succeeded
          ? 'success'
          : 'failed';
      final errorMessage = result.errorMessage ??
          (status == 'failed'
              ? 'O comando terminou com código ${result.exitCode}.'
              : null);
      await crontabRepository.finishTaskRun(
        runId: runId,
        task: task,
        startedAt: startedAt,
        status: status,
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        errorMessage: errorMessage,
      );
      if (status == 'success' || attempt > task.maxRetries) return;
      await Future<void>.delayed(Duration(seconds: task.retryDelaySeconds));
    }
  }
}
