import 'dart:async';
import 'dart:developer' as developer;

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:vr_agent/src/crontab/data/scheduler/cron_expression.dart';
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/crontab/domain/usecases/run_crontab_task.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';

class LocalCrontabScheduler {
  final FilePathRepository filePathRepository;
  final CrontabRepository crontabRepository;
  final RunCrontabTask runCrontabTask;
  final Set<int> _runningTaskIds = {};
  final Set<String> _runsThisMinute = {};
  final Set<Future<void>> _runningTasks = {};
  List<AgentTask> _tasks = [];
  String? _lastCheckedMinute;
  Timer? _timer;

  LocalCrontabScheduler({
    required this.filePathRepository,
    required this.crontabRepository,
    required this.runCrontabTask,
  }) {
    timezone_data.initializeTimeZones();
  }

  Future<void> start() async {
    if (_timer != null) return;
    _tasks = await _loadTasks();
    for (final task in _tasks.where((task) => task.enabled)) {
      CronExpression(task.schedule);
      timezone.getLocation(task.timezone);
    }
    _lastCheckedMinute = _minuteKey(DateTime.now().toUtc());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_checkDueTasks());
    });
  }

  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    await Future.wait(_runningTasks.toList(growable: false));
  }

  Future<List<AgentTask>> _loadTasks() async {
    final schedule = await filePathRepository.readJson(fileName: '.crontab');
    final tasks = schedule['tasks'];
    if (tasks is! List) {
      throw const FormatException('O arquivo .crontab deve conter uma lista "tasks".');
    }
    return tasks
        .map((task) {
          if (task is! Map<String, dynamic>) {
            throw const FormatException('Cada tarefa do .crontab deve ser um objeto JSON.');
          }
          return AgentTask.fromJson(task);
        })
        .toList(growable: false);
  }

  Future<void> _checkDueTasks() async {
    try {
      final now = DateTime.now().toUtc();
      final minuteKey = _minuteKey(now);
      if (minuteKey == _lastCheckedMinute) return;
      _lastCheckedMinute = minuteKey;
      _tasks = await _loadTasks();
      if (_timer == null) return;
      if (_runsThisMinute.length > 10000) _runsThisMinute.clear();
      for (final task in _tasks) {
        if (!task.enabled || _runningTaskIds.contains(task.id)) continue;
        final key = '${task.id}:$minuteKey';
        if (_runsThisMinute.contains(key)) continue;
        final location = timezone.getLocation(task.timezone);
        final localTime = timezone.TZDateTime.from(now, location);
        if (!CronExpression(task.schedule).matches(localTime)) continue;
        _runsThisMinute.add(key);
        _runningTaskIds.add(task.id);
        final execution = _runTask(task);
        _runningTasks.add(execution);
        unawaited(execution.whenComplete(() => _runningTasks.remove(execution)));
      }
    } catch (error, stackTrace) {
      developer.log(
        'Falha ao verificar tarefas do .crontab.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _minuteKey(DateTime dateTime) => '${dateTime.year}-${dateTime.month}-${dateTime.day}-${dateTime.hour}-${dateTime.minute}';

  Future<void> _runTask(AgentTask task) async {
    try {
      await runCrontabTask(task);
    } catch (error, stackTrace) {
      developer.log(
        'Falha ao registrar a execução da tarefa ${task.id}.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _runningTaskIds.remove(task.id);
    }
  }
}
