import 'package:test/test.dart';
import 'package:vr_agent/src/connection/domain/entitie/connection_config.dart';
import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/crontab/data/repositories/agent_task_command_runner.dart';
import 'package:vr_agent/src/crontab/data/scheduler/cron_expression.dart';
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/crontab/domain/repositories/task_command_runner.dart';
import 'package:vr_agent/src/crontab/domain/usecases/run_crontab_task.dart';
import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';

void main() {
  group('CronExpression', () {
    test('matches standard ranges, steps, and lists', () {
      final expression = CronExpression('*/15 9-17 1,15 * 1-5');

      expect(expression.matches(DateTime(2026, 10, 12, 9, 15)), isTrue);
      expect(expression.matches(DateTime(2026, 10, 12, 9, 10)), isFalse);
      expect(expression.matches(DateTime(2026, 10, 18, 9, 15)), isFalse);
    });

    test('supports named months and weekdays', () {
      final expression = CronExpression('0 12 * JAN MON');

      expect(expression.matches(DateTime(2026, 1, 5, 12)), isTrue);
      expect(expression.matches(DateTime(2026, 1, 6, 12)), isFalse);
    });

    test('rejects an expression with the wrong number of fields', () {
      expect(
        () => CronExpression('*/5 * * *'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AgentTask', () {
    test('uses the database default timezone when none is present', () {
      final task = AgentTask.fromJson({
        'id': 3,
        'server_id': 42,
        'name': 'task',
        'command': '-a -version',
        'schedule': '* * * * *',
      });

      expect(task.timezone, 'America/Sao_Paulo');
    });

    test('rejects invalid timeout and retry values', () {
      expect(
        () => AgentTask.fromJson({
          'id': 3,
          'server_id': 42,
          'name': 'task',
          'command': '-a -version',
          'schedule': '* * * * *',
          'timeout_seconds': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('syncs server-filtered tasks to the encrypted file contract', () async {
    final filePath = _FakeFilePathRepository()..jsonToRead = {'server_id': 42};
    final database = _FakeCrontabRepository()..tasks = [_task()];
    final connection = _FakeConnectionRepository();

    final count = await SyncCrontab(
      filePathRepository: filePath,
      crontabRepository: database,
      connectionRepository: connection,
    )();

    expect(count, 1);
    expect(database.requestedServerId, 42);
    expect(filePath.readFileName, '.env');
    expect(filePath.writeFileName, '.crontab');
    expect(filePath.writtenJson!['server_id'], 42);
    expect(filePath.writtenJson!['tasks'], hasLength(1));
    expect(connection.initialized, isTrue);
    expect(connection.closed, isTrue);
  });

  test('routes -update -crontab to task synchronization', () async {
    final filePath = _FakeFilePathRepository()..jsonToRead = {'server_id': 42};
    final database = _FakeCrontabRepository()..tasks = [_task()];
    final syncCrontab = SyncCrontab(
      filePathRepository: filePath,
      crontabRepository: database,
      connectionRepository: _FakeConnectionRepository(),
    );
    final registry = createDefaultCommandPalette(
      getAgentInfo: GetAgentInfo(
        name: 'VR Agent',
        version: '1.0.0',
        platform: 'Linux',
      ),
      runPowerToolsCommand: RunPowerToolsCommand(_FakePowerToolsRepository()),
      syncCrontab: syncCrontab,
      filePathRepository: filePath,
    );

    expect(await registry.run(['-a', '-update', '-crontab']), 0);
    expect(database.requestedServerId, 42);
    expect(filePath.writeFileName, '.crontab');
  });

  test('PowerTools task prefix forwards arguments and captures output', () async {
    final powerTools = _FakePowerToolsRepository();
    final result = await AgentTaskCommandRunner(
      powerToolsRepository: powerTools,
      getAgentInfo: GetAgentInfo(
        name: 'VR Agent',
        version: '1.0.0',
        platform: 'Linux',
      ),
    ).run(_task(command: '-p -backup --full'));

    expect(powerTools.arguments, ['-backup', '--full']);
    expect(powerTools.timeout, const Duration(seconds: 300));
    expect(result.stdout, 'captured output');
    expect(result.succeeded, isTrue);
  });

  test('agent task prefix runs native agent version action', () async {
    final result = await AgentTaskCommandRunner(
      powerToolsRepository: _FakePowerToolsRepository(),
      getAgentInfo: GetAgentInfo(
        name: 'VR Agent',
        version: '1.0.0',
        platform: 'Linux',
      ),
    ).run(_task(command: '-a -version'));

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VR Agent'));
  });

  test('records failed attempts and retries before succeeding', () async {
    final database = _FakeCrontabRepository();
    final runner = _RetryingTaskCommandRunner();

    await RunCrontabTask(
      crontabRepository: database,
      taskCommandRunner: runner,
    )(_task(maxRetries: 1, retryDelaySeconds: 0));

    expect(database.startedAttempts, [1, 2]);
    expect(database.finishedStatuses, ['failed', 'success']);
    expect(runner.calls, 2);
  });
}

AgentTask _task({
  String command = '-a -version',
  int maxRetries = 0,
  int retryDelaySeconds = 60,
}) => AgentTask(
  id: 3,
  serverId: 42,
  name: 'test task',
  description: null,
  command: command,
  schedule: '* * * * *',
  timezone: 'UTC',
  enabled: true,
  timeoutSeconds: 300,
  maxRetries: maxRetries,
  retryDelaySeconds: retryDelaySeconds,
  runAsUser: null,
  priority: 5,
);

class _FakeFilePathRepository implements FilePathRepository {
  Map<String, dynamic> jsonToRead = {};
  String? readFileName;
  String? writeFileName;
  Map<String, dynamic>? writtenJson;

  @override
  Future<Map<String, dynamic>> readJson({required String fileName}) async {
    readFileName = fileName;
    return jsonToRead;
  }

  @override
  Future<void> writeJson({
    required String fileName,
    required Map<String, dynamic> data,
  }) async {
    writeFileName = fileName;
    writtenJson = data;
  }
}

class _FakeCrontabRepository implements CrontabRepository {
  List<AgentTask> tasks = [];
  int? requestedServerId;
  final List<int> startedAttempts = [];
  final List<String> finishedStatuses = [];

  @override
  Future<List<AgentTask>> getTasksForServer(int serverId) async {
    requestedServerId = serverId;
    return tasks;
  }

  @override
  Future<int> startTaskRun({
    required AgentTask task,
    required int attempt,
    required String triggeredBy,
  }) async {
    startedAttempts.add(attempt);
    return attempt;
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
    finishedStatuses.add(status);
  }
}

class _FakeConnectionRepository implements ConnectionRepository {
  bool initialized = false;
  bool closed = false;

  @override
  Future<void> init({String? user, String? password}) async {
    initialized = true;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<List<Map<String, dynamic>>> execute(
    String query, {
    List<Object?>? parameters,
  }) async => [];

  @override
  Future<ConnectionConfig> getConfig() => throw UnimplementedError();

  @override
  bool isVerifiedFor(ConnectionConfig config) => false;

  @override
  Future<void> reconnect({String? user, String? password}) => throw UnimplementedError();
}

class _FakePowerToolsRepository implements PowerToolsRepository {
  List<String>? arguments;
  Duration? timeout;

  @override
  Future<PowerToolsResult> execute(
    List<String> arguments, {
    Duration? timeout,
  }) async {
    this.arguments = arguments;
    this.timeout = timeout;
    return const PowerToolsResult(
      exitCode: 0,
      stdout: 'captured output',
      stderr: '',
    );
  }
}

class _RetryingTaskCommandRunner implements TaskCommandRunner {
  int calls = 0;

  @override
  Future<TaskRunResult> run(AgentTask task) async {
    calls++;
    if (calls == 1) {
      return const TaskRunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'failed',
      );
    }
    return const TaskRunResult(exitCode: 0, stdout: 'done', stderr: '');
  }
}
