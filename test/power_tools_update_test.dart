import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:vr_agent/src/connection/domain/entitie/connection_config.dart';
import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/repositories/crontab_repository.dart';
import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';
import 'package:vr_agent/src/update/data/repositories/google_drive_power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/data/repositories/postgres_power_tools_update_repository.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_release.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_update_result.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';
import 'package:vr_agent/src/update/domain/usecases/update_power_tools.dart';

void main() {
  group('GoogleDrivePowerToolsBinaryInstaller', () {
    test('downloads and atomically replaces the executable', () async {
      final directory = await Directory.systemTemp.createTemp();
      final adapter = _FakeHttpClientAdapter([
        ResponseBody.fromBytes([1, 2, 3, 4], HttpStatus.ok),
      ]);
      final target = File('${directory.path}/PowerTools.exe');
      String? validatedPath;
      await target.writeAsBytes([9, 9]);

      try {
        await GoogleDrivePowerToolsBinaryInstaller(
          dio: Dio()..httpClientAdapter = adapter,
          versionReader: (path) async {
            validatedPath = path;
            return 'PowerTools version 1.2.0';
          },
        ).install(
          repositoryUrl: 'https://drive.google.com/file/d/file-123/view',
          executablePath: target.path,
          platform: PlatformInfo.fromOperatingSystem('windows'),
          expectedVersion: '1.2.0',
        );

        expect(await target.readAsBytes(), [1, 2, 3, 4]);
        expect(validatedPath, target.path);
        expect(adapter.requestedUris.first.host, 'drive.usercontent.google.com');
        expect(adapter.requestedUris.first.path, '/download');
        expect(adapter.requestedUris.first.queryParameters['id'], 'file-123');
        final remainingFiles = directory.listSync();
        expect(remainingFiles, hasLength(1));
        expect(remainingFiles.single.path, endsWith('PowerTools.exe'));
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test(
      'restores the installed binary if Windows blocks version validation',
      () async {
        final directory = await Directory.systemTemp.createTemp();
        final adapter = _FakeHttpClientAdapter([
          ResponseBody.fromBytes([1, 2, 3, 4], HttpStatus.ok),
        ]);
        final target = File('${directory.path}/PowerTools.exe');
        await target.writeAsBytes([9, 9]);

        try {
          await expectLater(
            GoogleDrivePowerToolsBinaryInstaller(
              dio: Dio()..httpClientAdapter = adapter,
              versionReader: (_) async {
                throw ProcessException(
                  'PowerTools.exe',
                  ['-version'],
                  'A política de Controle de Aplicativo bloqueou este arquivo',
                  1260,
                );
              },
            ).install(
              repositoryUrl: 'https://drive.google.com/file/d/file-123/view',
              executablePath: target.path,
              platform: PlatformInfo.fromOperatingSystem('windows'),
              expectedVersion: '1.2.0',
            ),
            throwsA(isA<ProcessException>()),
          );
          expect(await target.readAsBytes(), [9, 9]);
          expect(directory.listSync(), hasLength(1));
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test('rejects an outdated download without replacing the installed binary', () async {
        final directory = await Directory.systemTemp.createTemp();
        final adapter = _FakeHttpClientAdapter([
          ResponseBody.fromBytes([1, 2, 3, 4], HttpStatus.ok),
        ]);
        final target = File('${directory.path}/PowerTools.exe');
        await target.writeAsBytes([9, 9]);

        try {
          await expectLater(
            GoogleDrivePowerToolsBinaryInstaller(
              dio: Dio()..httpClientAdapter = adapter,
              versionReader: (_) async => 'PowerTools version 1.0.19',
            ).install(
              repositoryUrl: 'https://drive.google.com/file/d/file-123/view',
              executablePath: target.path,
              platform: PlatformInfo.fromOperatingSystem('windows'),
              expectedVersion: '1.0.20',
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('contém PowerTools 1.0.19'),
              ),
            ),
          );
          expect(await target.readAsBytes(), [9, 9]);
          expect(directory.listSync(), hasLength(1));
        } finally {
          await directory.delete(recursive: true);
        }
    });

    test('rejects an HTML response without replacing the existing executable', () async {
        final directory = await Directory.systemTemp.createTemp();
        final adapter = _FakeHttpClientAdapter([
          ResponseBody.fromString(
            '<html>Google Drive error</html>',
            HttpStatus.ok,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          ),
        ]);
        final target = File('${directory.path}/PowerTools.exe');
        await target.writeAsBytes([9, 9]);

        try {
          await expectLater(
            GoogleDrivePowerToolsBinaryInstaller(
              dio: Dio()..httpClientAdapter = adapter,
            ).install(
              repositoryUrl: 'https://drive.google.com/open?id=file-123',
              executablePath: target.path,
              platform: PlatformInfo.fromOperatingSystem('windows'),
            ),
            throwsA(isA<FormatException>()),
          );
          expect(await target.readAsBytes(), [9, 9]);
        } finally {
          await directory.delete(recursive: true);
        }
    });

    test('follows the Google Drive confirmation form without a browser', () async {
        final directory = await Directory.systemTemp.createTemp();
        final adapter = _FakeHttpClientAdapter([
          ResponseBody.fromString(
            '''
          <html><form action="https://drive.google.com/uc">
            <input type="hidden" name="export" value="download">
            <input type="hidden" name="id" value="file-123">
            <input type="hidden" name="confirm" value="download-token">
          </form></html>
          ''',
            HttpStatus.ok,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
              'set-cookie': ['download_warning_file-123=download-token; Path=/'],
            },
          ),
          ResponseBody.fromBytes([1, 2, 3, 4], HttpStatus.ok),
        ]);
        final target = File('${directory.path}/PowerTools.exe');

        try {
          await GoogleDrivePowerToolsBinaryInstaller(
            dio: Dio()..httpClientAdapter = adapter,
          ).install(
            repositoryUrl: 'https://drive.google.com/file/d/file-123/view',
            executablePath: target.path,
            platform: PlatformInfo.fromOperatingSystem('windows'),
          );

          expect(adapter.requestedUris, hasLength(2));
          expect(
            adapter.requestedUris.last.queryParameters['confirm'],
            'download-token',
          );
          expect(
            adapter.requestedHeaders.last.values.join(';'),
            contains('download_warning_file-123=download-token'),
          );
          expect(await target.readAsBytes(), [1, 2, 3, 4]);
        } finally {
          await directory.delete(recursive: true);
        }
    });
  });

  group('UpdatePowerTools', () {
    test('routes -a -update -powertools to the updater', () async {
      final connection = _FakeConnectionRepository();
      final filePath = _FakeFilePathRepository()..config = {'server_id': 42};
      final powerTools = _FakePowerToolsRepository()
        ..results.addAll([
          const PowerToolsResult(
            exitCode: 0,
            stdout: 'PowerTools version 1.0.0',
            stderr: '',
          ),
          const PowerToolsResult(
            exitCode: 0,
            stdout: 'PowerTools version 1.1.0',
            stderr: '',
          ),
        ]);
      final installer = _FakePowerToolsBinaryInstaller();
      final update = _useCase(
        connectionRepository: connection,
        filePathRepository: filePath,
        powerToolsRepository: powerTools,
        updateRepository: _FakePowerToolsUpdateRepository()
          ..release = const PowerToolsRelease(
            id: 3,
            currentVersion: '1.0.0',
            newVersion: '1.1.0',
            repository: 'https://drive.google.com/file/d/example/view',
          ),
        binaryInstaller: installer,
      );
      final registry = createDefaultCommandPalette(
        getAgentInfo: const GetAgentInfo(
          name: 'VR Agent',
          version: '1.0.0',
          platform: 'Windows',
        ),
        runPowerToolsCommand: RunPowerToolsCommand(powerTools),
        syncCrontab: SyncCrontab(
          filePathRepository: filePath,
          crontabRepository: _FakeCrontabRepository(),
          connectionRepository: connection,
        ),
        filePathRepository: filePath,
        updatePowerTools: update,
      );

      expect(await registry.run(['-a', '-update', '-powertools']), 0);
      expect(installer.repositoryUrl, isNotNull);
      expect(powerTools.arguments, ['-version']);
    });

    test('requires an explicit update target', () async {
      final filePath = _FakeFilePathRepository();
      final connection = _FakeConnectionRepository();
      final registry = createDefaultCommandPalette(
        getAgentInfo: const GetAgentInfo(
          name: 'VR Agent',
          version: '1.0.0',
          platform: 'Windows',
        ),
        runPowerToolsCommand: RunPowerToolsCommand(_FakePowerToolsRepository()),
        syncCrontab: SyncCrontab(
          filePathRepository: filePath,
          crontabRepository: _FakeCrontabRepository(),
          connectionRepository: connection,
        ),
        filePathRepository: filePath,
      );

      expect(await registry.run(['-a', '-update']), 64);
    });

    test('installs a newer release and marks it completed', () async {
      final connection = _FakeConnectionRepository();
      final filePath = _FakeFilePathRepository()..config = {'server_id': 42};
      final powerTools = _FakePowerToolsRepository()
        ..results.addAll([
          const PowerToolsResult(
            exitCode: 0,
            stdout: 'PowerTools version 1.9.0',
            stderr: '',
          ),
          const PowerToolsResult(
            exitCode: 0,
            stdout: 'PowerTools version 2.0.0',
            stderr: '',
          ),
        ]);
      final updateRepository = _FakePowerToolsUpdateRepository()
        ..release = const PowerToolsRelease(
          id: 9,
          currentVersion: '1.0.0',
          newVersion: '2.0.0',
          repository: 'https://drive.google.com/file/d/example/view',
        );
      final installer = _FakePowerToolsBinaryInstaller();

      final result = await _useCase(
        connectionRepository: connection,
        filePathRepository: filePath,
        powerToolsRepository: powerTools,
        updateRepository: updateRepository,
        binaryInstaller: installer,
      )();

      expect(result.status, PowerToolsUpdateStatus.updated);
      expect(result.currentVersion, '1.9.0');
      expect(result.newVersion, '2.0.0');
      expect(powerTools.arguments, ['-version']);
      expect(updateRepository.requestedServerId, 42);
      expect(updateRepository.completedReleaseId, 9);
      expect(installer.repositoryUrl, contains('drive.google.com'));
      expect(installer.executablePath, r'C:\vr\agent\PowerTools.exe');
      expect(installer.expectedVersion, '2.0.0');
      expect(connection.initialized, isTrue);
      expect(connection.closed, isTrue);
    });

    test('does not mark update completed if downloaded binary is still old', () async {
        final updateRepository = _FakePowerToolsUpdateRepository()
          ..release = const PowerToolsRelease(
            id: 12,
            currentVersion: '1.0.0',
            newVersion: '2.0.0',
            repository: 'https://drive.google.com/file/d/example/view',
          );
        final powerTools = _FakePowerToolsRepository()
          ..results.addAll([
            const PowerToolsResult(
              exitCode: 0,
              stdout: 'PowerTools version 1.0.0',
              stderr: '',
            ),
            const PowerToolsResult(
              exitCode: 0,
              stdout: 'PowerTools version 1.0.0',
              stderr: '',
            ),
          ]);

        await expectLater(
          _useCase(
            powerToolsRepository: powerTools,
            updateRepository: updateRepository,
          )(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('continua na versão 1.0.0'),
            ),
          ),
        );

        expect(updateRepository.completedReleaseId, isNull);
        expect(updateRepository.failedReleaseId, 12);
      expect(updateRepository.errorMessage, contains('continua na versão 1.0.0'));
    });

    test('does not reinstall an equal semantic version', () async {
      final installer = _FakePowerToolsBinaryInstaller();
      final updateRepository = _FakePowerToolsUpdateRepository()
        ..release = const PowerToolsRelease(
          id: 9,
          currentVersion: '1.0',
          newVersion: '1.2.0',
          repository: 'https://drive.google.com/file/d/example/view',
        );

      final result = await _useCase(
        powerToolsRepository: _FakePowerToolsRepository()
          ..result = const PowerToolsResult(
            exitCode: 0,
            stdout: 'PowerTools version v1.2',
            stderr: '',
          ),
        updateRepository: updateRepository,
        binaryInstaller: installer,
      )();

      expect(result.status, PowerToolsUpdateStatus.upToDate);
      expect(installer.repositoryUrl, isNull);
      expect(updateRepository.completedReleaseId, isNull);
    });

    test('records installation errors and rethrows them', () async {
      final updateRepository = _FakePowerToolsUpdateRepository()
        ..release = const PowerToolsRelease(
          id: 11,
          currentVersion: '1.0.0',
          newVersion: '2.0.0',
          repository: 'https://drive.google.com/file/d/example/view',
        );

      await expectLater(
        _useCase(
          powerToolsRepository: _FakePowerToolsRepository()
            ..result = const PowerToolsResult(
              exitCode: 0,
              stdout: 'PowerTools version 1.0.0',
              stderr: '',
            ),
          updateRepository: updateRepository,
          binaryInstaller: _FakePowerToolsBinaryInstaller()..error = StateError('download failed'),
        )(),
        throwsA(isA<StateError>()),
      );

      expect(updateRepository.failedReleaseId, 11);
      expect(updateRepository.errorMessage, contains('download failed'));
    });
  });

  test('maps the latest database release', () async {
    final connection = _FakeConnectionRepository()
      ..rows = [
        {
          'id': 5,
          'current_version': '1.0.0',
          'new_version': '1.1.0',
          'repository': 'https://drive.google.com/file/d/example/view',
        },
      ];

    final release = await PostgresPowerToolsUpdateRepository(
      connectionRepository: connection,
      platform: PlatformInfo.fromOperatingSystem('windows'),
    ).getLatestRelease(serverId: 42);

    expect(release?.id, 5);
    expect(release?.currentVersion, '1.0.0');
    expect(release?.newVersion, '1.1.0');
    expect(
      connection.query,
      contains('current_version.id = au.current_version_id'),
    );
    expect(
      connection.query,
      contains('new_version.id = au.new_version_id'),
    );
    expect(
      connection.query,
      contains('new_version.link_windows AS repository'),
    );
    expect(connection.query, contains('ORDER BY au.version_date DESC, au.id DESC'));
    expect(connection.parameters, [42]);
  });

  test('selects the Linux binary link for Linux', () async {
    final connection = _FakeConnectionRepository()
      ..rows = [
        {
          'id': 5,
          'current_version': '1.0.0',
          'new_version': '1.1.0',
          'repository': 'https://drive.google.com/file/d/linux/view',
        },
      ];

    final release = await PostgresPowerToolsUpdateRepository(
      connectionRepository: connection,
      platform: PlatformInfo.fromOperatingSystem('linux'),
    ).getLatestRelease(serverId: 42);

    expect(release?.repository, 'https://drive.google.com/file/d/linux/view');
    expect(
      connection.query,
      contains('new_version.link_linux AS repository'),
    );
  });

  test('rejects a release without a link for the current platform', () async {
    final connection = _FakeConnectionRepository()
      ..rows = [
        {
          'id': 5,
          'current_version': '1.0.0',
          'new_version': '1.1.0',
          'repository': null,
        },
      ];

    await expectLater(
      PostgresPowerToolsUpdateRepository(
        connectionRepository: connection,
        platform: PlatformInfo.fromOperatingSystem('linux'),
      ).getLatestRelease(serverId: 42),
      throwsA(isA<FormatException>()),
    );
  });

  test('updates the release row after completion and on failure', () async {
    final connection = _FakeConnectionRepository()
      ..rows = [
        {'id': 5},
      ];
    final repository = PostgresPowerToolsUpdateRepository(
      connectionRepository: connection,
      platform: PlatformInfo.fromOperatingSystem('windows'),
    );

    await repository.markCompleted(releaseId: 5);
    expect(
      connection.query,
      contains('current_version_id = new_version_id'),
    );
    expect(connection.query, contains('RETURNING id'));
    expect(connection.parameters?[0], 'completed');
    expect(connection.parameters?[2], 5);

    await repository.markFailed(releaseId: 5, errorMessage: 'download failed');
    expect(connection.query, contains('status = \$1'));
    expect(connection.parameters?[0], 'failed');
    expect(connection.parameters?[2], 'download failed');
  });
}

UpdatePowerTools _useCase({
  ConnectionRepository? connectionRepository,
  FilePathRepository? filePathRepository,
  PowerToolsRepository? powerToolsRepository,
  PowerToolsUpdateRepository? updateRepository,
  PowerToolsBinaryInstaller? binaryInstaller,
}) => UpdatePowerTools(
  connectionRepository: connectionRepository ?? _FakeConnectionRepository(),
  filePathRepository: filePathRepository ?? (_FakeFilePathRepository()..config = {'server_id': 42}),
  powerToolsRepository:
      powerToolsRepository ??
      (_FakePowerToolsRepository()
        ..result = const PowerToolsResult(
          exitCode: 0,
          stdout: 'PowerTools version 1.0.0',
          stderr: '',
        )),
  updateRepository: updateRepository ?? _FakePowerToolsUpdateRepository(),
  binaryInstaller: binaryInstaller ?? _FakePowerToolsBinaryInstaller(),
  executablePath: r'C:\vr\agent\PowerTools.exe',
  platform: PlatformInfo.fromOperatingSystem('windows'),
);

class _FakeConnectionRepository implements ConnectionRepository {
  bool initialized = false;
  bool closed = false;
  List<Map<String, dynamic>> rows = [];
  String? query;
  List<Object?>? parameters;

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
  }) async {
    this.query = query;
    this.parameters = parameters;
    return rows;
  }

  @override
  Future<ConnectionConfig> getConfig() => throw UnimplementedError();

  @override
  bool isVerifiedFor(ConnectionConfig config) => false;

  @override
  Future<void> reconnect({String? user, String? password}) => throw UnimplementedError();
}

class _FakeFilePathRepository implements FilePathRepository {
  Map<String, dynamic> config = {};

  @override
  Future<Map<String, dynamic>> readJson({required String fileName}) async => config;

  @override
  Future<void> writeJson({
    required String fileName,
    required Map<String, dynamic> data,
  }) => throw UnimplementedError();

  @override
  Stream<void> watchFile({required String fileName}) =>
      const Stream<void>.empty();
}

class _FakePowerToolsRepository implements PowerToolsRepository {
  PowerToolsResult result = const PowerToolsResult(
    exitCode: 0,
    stdout: '',
    stderr: '',
  );
  List<String>? arguments;
  final List<PowerToolsResult> results = [];

  @override
  Future<PowerToolsResult> execute(
    List<String> arguments, {
    Duration? timeout,
  }) async {
    this.arguments = arguments;
    if (results.isNotEmpty) return results.removeAt(0);
    return result;
  }
}

class _FakePowerToolsUpdateRepository implements PowerToolsUpdateRepository {
  PowerToolsRelease? release;
  int? requestedServerId;
  int? completedReleaseId;
  int? failedReleaseId;
  String? errorMessage;

  @override
  Future<PowerToolsRelease?> getLatestRelease({required int serverId}) async {
    requestedServerId = serverId;
    return release;
  }

  @override
  Future<void> markCompleted({
    required int releaseId,
  }) async {
    completedReleaseId = releaseId;
  }

  @override
  Future<void> markFailed({
    required int releaseId,
    required String errorMessage,
  }) async {
    failedReleaseId = releaseId;
    this.errorMessage = errorMessage;
  }
}

class _FakePowerToolsBinaryInstaller implements PowerToolsBinaryInstaller {
  String? repositoryUrl;
  String? executablePath;
  String? expectedVersion;
  Object? error;
  bool installed = false;

  @override
  Future<bool> isInstalled({required String executablePath}) async => installed;

  @override
  Future<void> install({
    required String repositoryUrl,
    required String executablePath,
    required PlatformInfo platform,
    String? expectedVersion,
  }) async {
    this.repositoryUrl = repositoryUrl;
    this.executablePath = executablePath;
    this.expectedVersion = expectedVersion;
    final error = this.error;
    if (error != null) throw error;
  }
}

class _FakeCrontabRepository implements CrontabRepository {
  @override
  Future<List<AgentTask>> getTasksForServer(int serverId) async => const [];

  @override
  Future<int> startTaskRun({
    required AgentTask task,
    required int attempt,
    required String triggeredBy,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final List<ResponseBody> responses;
  final List<Uri> requestedUris = [];
  final List<Map<String, dynamic>> requestedHeaders = [];
  var _responseIndex = 0;

  _FakeHttpClientAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUris.add(options.uri);
    requestedHeaders.add(options.headers);
    return responses[_responseIndex++];
  }

  @override
  void close({bool force = false}) {}
}
