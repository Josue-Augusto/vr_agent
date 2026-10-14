import 'package:test/test.dart';
import 'package:vr_agent/src/connection/domain/entitie/connection_config.dart';
import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/install/domain/entities/power_tools_install_result.dart';
import 'package:vr_agent/src/install/domain/usecases/install_power_tools.dart';
import 'package:vr_agent/src/terminal/domain/entities/agent_command.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_release.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';

void main() {
  group('InstallPowerTools', () {
    test('does not access the database when PowerTools already exists', () async {
      final connection = _FakeConnectionRepository();
      final updates = _FakePowerToolsUpdateRepository();
      final installer = _FakePowerToolsBinaryInstaller()..installed = true;

      final result = await _useCase(
        connection: connection,
        updates: updates,
        installer: installer,
      )();

      expect(result.status, PowerToolsInstallStatus.alreadyInstalled);
      expect(connection.initialized, isFalse);
      expect(updates.requestedServerId, isNull);
      expect(installer.downloadedUrl, isNull);
    });

    test('downloads the release for this server and updates the database', () async {
      final connection = _FakeConnectionRepository();
      final updates = _FakePowerToolsUpdateRepository()
        ..release = const PowerToolsRelease(
          id: 7,
          currentVersion: '1.0.0',
          newVersion: '2.1.0',
          repository: 'https://drive.google.com/file/d/powertools/view',
        );
      final installer = _FakePowerToolsBinaryInstaller();

      final result = await _useCase(
        connection: connection,
        updates: updates,
        installer: installer,
      )();

      expect(result.status, PowerToolsInstallStatus.installed);
      expect(result.version, '2.1.0');
      expect(connection.initialized, isTrue);
      expect(connection.closed, isTrue);
      expect(updates.requestedServerId, 42);
      expect(installer.downloadedUrl, contains('drive.google.com'));
      expect(updates.completedReleaseId, 7);
    });

    test('marks a failed installation in the database', () async {
      final updates = _FakePowerToolsUpdateRepository()
        ..release = const PowerToolsRelease(
          id: 7,
          currentVersion: '1.0.0',
          newVersion: '2.1.0',
          repository: 'https://drive.google.com/file/d/powertools/view',
        );
      final installer = _FakePowerToolsBinaryInstaller()..error = StateError('download failed');

      await expectLater(
        _useCase(updates: updates, installer: installer)(),
        throwsA(isA<StateError>()),
      );

      expect(updates.failedReleaseId, 7);
      expect(updates.failure, contains('download failed'));
    });

    test('routes the bare install command through the command registry', () async {
      final registry = CommandRegistry()
        ..register(
          AgentCommand(
            name: 'install',
            description: 'Install PowerTools',
            action: (_) async => 17,
          ),
        )
        ..register(
          AgentCommand(
            name: '-help',
            description: 'Help',
            action: (_) async => 0,
          ),
        );

      expect(await registry.run(['-a', 'install']), 17);
    });
  });
}

InstallPowerTools _useCase({
  _FakeConnectionRepository? connection,
  _FakeFilePathRepository? files,
  _FakePowerToolsUpdateRepository? updates,
  _FakePowerToolsBinaryInstaller? installer,
}) => InstallPowerTools(
  connectionRepository: connection ?? _FakeConnectionRepository(),
  filePathRepository: files ?? (_FakeFilePathRepository()..config = {'server_id': 42}),
  updateRepository: updates ?? _FakePowerToolsUpdateRepository()
    ..release = const PowerToolsRelease(
      id: 7,
      currentVersion: '1.0.0',
      newVersion: '2.1.0',
      repository: 'https://drive.google.com/file/d/powertools/view',
    ),
  binaryInstaller: installer ?? _FakePowerToolsBinaryInstaller(),
  executablePath: r'C:\vr\agent\PowerTools.exe',
  platform: PlatformInfo.fromOperatingSystem('windows'),
);

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
  Stream<void> watchFile({required String fileName}) => const Stream<void>.empty();
}

class _FakePowerToolsUpdateRepository implements PowerToolsUpdateRepository {
  PowerToolsRelease? release;
  int? requestedServerId;
  int? completedReleaseId;
  int? failedReleaseId;
  String? failure;

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
    failure = errorMessage;
  }
}

class _FakePowerToolsBinaryInstaller implements PowerToolsBinaryInstaller {
  bool installed = false;
  String? downloadedUrl;
  Object? error;

  @override
  Future<bool> isInstalled({required String executablePath}) async => installed;

  @override
  Future<void> install({
    required String repositoryUrl,
    required String executablePath,
    required PlatformInfo platform,
  }) async {
    downloadedUrl = repositoryUrl;
    final error = this.error;
    if (error != null) throw error;
  }
}
