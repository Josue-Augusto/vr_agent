import 'dart:async';
import 'dart:io' as io;

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
  Timer? _reloadDebounceTimer;
  StreamSubscription<void>? _crontabWatchSubscription;
  bool _started = false;

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
    _lastCheckedMinute = _minuteKey(DateTime.now().toUtc());
    _started = true;
    _watchCrontab();
    _scheduleNextCheck();
    io.stdout.writeln(
      'Crontab scheduler started with '
      '${_tasks.where((task) => task.enabled).length} enabled task(s).',
    );
  }

  Future<void> reloadTasks() async {
    _tasks = await _loadTasks();
  }

  Future<void> close() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = null;
    await _crontabWatchSubscription?.cancel();
    _crontabWatchSubscription = null;
    await Future.wait(_runningTasks.toList(growable: false));
  }

  Future<List<AgentTask>> _loadTasks() async {
    final schedule = await filePathRepository.readJson(fileName: '.crontab');
    final tasks = schedule['tasks'];
    if (tasks is! List) {
      throw const FormatException('O arquivo .crontab deve conter uma lista "tasks".');
    }
    final loadedTasks = tasks
        .map((task) {
          if (task is! Map<String, dynamic>) {
            throw const FormatException('Cada tarefa do .crontab deve ser um objeto JSON.');
          }
          return AgentTask.fromJson(task);
        })
        .toList(growable: false);
    for (final task in loadedTasks.where((task) => task.enabled)) {
      CronExpression(task.schedule);
      timezone.getLocation(task.timezone);
    }
    return loadedTasks;
  }

  Future<void> _checkDueTasks() async {
    try {
      await reloadTasks();
      if (!_started) return;
      final now = DateTime.now().toUtc();
      final minuteKey = _minuteKey(now);
      if (minuteKey == _lastCheckedMinute) return;
      _lastCheckedMinute = minuteKey;
      _runsThisMinute.clear();
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
      io.stderr.writeln(
        'Falha ao verificar tarefas do .crontab: $error\n$stackTrace',
      );
    }
  }

  void _scheduleNextCheck() {
    if (!_started) return;
    final now = DateTime.now().toUtc();
    final nextMinute = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    final delay = nextMinute.difference(now);
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_checkAndScheduleNext());
    });
  }

  void _watchCrontab() {
    _crontabWatchSubscription = filePathRepository
        .watchFile(fileName: '.crontab')
        .listen(
          (_) {
            _reloadDebounceTimer?.cancel();
            _reloadDebounceTimer = Timer(
              const Duration(milliseconds: 100),
              () => unawaited(_reloadTasksFromWatch()),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            io.stderr.writeln(
              'Falha ao observar alterações no .crontab; a verificação por minuto continuará ativa: '
              '$error\n$stackTrace',
            );
          },
        );
  }

  Future<void> _reloadTasksFromWatch() async {
    if (!_started) return;
    try {
      await reloadTasks();
    } catch (error, stackTrace) {
      io.stderr.writeln(
        'Falha ao recarregar tarefas após alteração no .crontab: $error\n$stackTrace',
      );
    }
  }

  Future<void> _checkAndScheduleNext() async {
    await _checkDueTasks();
    if (_started && _timer == null) _scheduleNextCheck();
  }

  String _minuteKey(DateTime dateTime) => '${dateTime.year}-${dateTime.month}-${dateTime.day}-${dateTime.hour}-${dateTime.minute}';

  Future<void> _runTask(AgentTask task) async {
    try {
      await runCrontabTask(task);
    } catch (error, stackTrace) {
      io.stderr.writeln(
        'Falha ao registrar a execução da tarefa ${task.id}: $error\n$stackTrace',
      );
    } finally {
      _runningTaskIds.remove(task.id);
    }
  }
}
