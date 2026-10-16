import 'dart:async';
import 'dart:io' as io;

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/crontab/domain/repositories/task_command_runner.dart';

class RunCrontabTask {
  final CrontabRepository crontabRepository;
  final TaskCommandRunner taskCommandRunner;

  RunCrontabTask({
    required this.crontabRepository,
    required this.taskCommandRunner,
  }) {
    timezone_data.initializeTimeZones();
  }

  Future<void> call(AgentTask task) async {
    final location = timezone.getLocation(
      task.timezone == 'UTC' ? 'Etc/UTC' : task.timezone,
    );
    for (var attempt = 1; attempt <= task.maxRetries + 1; attempt++) {
      final startedAt = timezone.TZDateTime.now(location);
      io.stdout.writeln(
        '[${_formatTimestamp(startedAt)} ${task.timezone}] Starting scheduled task '
        '${task.id} (${task.name}), attempt $attempt.',
      );
      final runId = await crontabRepository.startTaskRun(
        task: task,
        attempt: attempt,
        triggeredBy: attempt == 1 ? 'schedule' : 'retry',
      );
      late final TaskRunResult result;
      try {
        result = await taskCommandRunner
            .run(task)
            .timeout(
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
      final errorMessage = result.errorMessage ?? (status == 'failed' ? 'O comando terminou com código ${result.exitCode}.' : null);
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
      final finishedAt = timezone.TZDateTime.now(location);
      final finishedTimestamp = _formatTimestamp(finishedAt);
      if (status == 'success') {
        io.stdout.writeln(
          '[$finishedTimestamp ${task.timezone}] Scheduled task '
          '${task.id} (${task.name}) completed successfully.',
        );
      } else {
        io.stderr.writeln(
          '[$finishedTimestamp ${task.timezone}] Scheduled task '
          '${task.id} (${task.name}) '
          'ended with status "$status": $errorMessage',
        );
      }
      if (status == 'success' || attempt > task.maxRetries) return;
      await Future<void>.delayed(Duration(seconds: task.retryDelaySeconds));
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final offset = timestamp.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteOffset = offset.abs();
    final offsetHours = absoluteOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (absoluteOffset.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final localIsoTimestamp = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      timestamp.minute,
      timestamp.second,
      timestamp.millisecond,
      timestamp.microsecond,
    ).toIso8601String();
    return '${localIsoTimestamp.substring(0, localIsoTimestamp.length - 1)}'
        '$sign$offsetHours:$offsetMinutes';
  }
}
