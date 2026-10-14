import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/update/domain/entities/power_tools_update_result.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';

class UpdatePowerTools {
  final ConnectionRepository connectionRepository;
  final FilePathRepository filePathRepository;
  final PowerToolsRepository powerToolsRepository;
  final PowerToolsUpdateRepository updateRepository;
  final PowerToolsBinaryInstaller binaryInstaller;
  final String executablePath;
  final PlatformInfo platform;

  const UpdatePowerTools({
    required this.connectionRepository,
    required this.filePathRepository,
    required this.powerToolsRepository,
    required this.updateRepository,
    required this.binaryInstaller,
    required this.executablePath,
    required this.platform,
  });

  Future<PowerToolsUpdateResult> call() async {
    await connectionRepository.init();
    try {
      final serverId = await _getServerId();
      final versionResult = await powerToolsRepository.execute(
        ['-version'],
        timeout: const Duration(seconds: 30),
      );
      if (versionResult.timedOut || versionResult.exitCode != 0) {
        throw StateError(
          'PowerTools -version terminou com código ${versionResult.exitCode}. '
          '${versionResult.stderr}',
        );
      }

      final currentVersion = _versionFromOutput(
        '${versionResult.stdout}\n${versionResult.stderr}',
      );
      final release = await updateRepository.getLatestRelease(
        serverId: serverId,
      );
      if (release == null) {
        return PowerToolsUpdateResult(
          status: PowerToolsUpdateStatus.noRelease,
          currentVersion: currentVersion,
        );
      }

      late final String newVersion;
      try {
        newVersion = _validatedVersion(release.newVersion);
      } catch (error, stackTrace) {
        await _recordFailure(release.id, error, stackTrace);
      }
      if (_compareVersions(newVersion, currentVersion) <= 0) {
        return PowerToolsUpdateResult(
          status: PowerToolsUpdateStatus.upToDate,
          currentVersion: currentVersion,
          newVersion: newVersion,
        );
      }

      try {
        await binaryInstaller.install(
          repositoryUrl: release.repository,
          executablePath: executablePath,
          platform: platform,
          expectedVersion: newVersion,
        );
        final installedVersionResult = await powerToolsRepository.execute(
          ['-version'],
          timeout: const Duration(seconds: 30),
        );
        if (installedVersionResult.timedOut ||
            installedVersionResult.exitCode != 0) {
          throw StateError(
            'Não foi possível validar a versão instalada do PowerTools. '
            'Código ${installedVersionResult.exitCode}. '
            '${installedVersionResult.stderr}',
          );
        }
        final installedVersion = _versionFromOutput(
          '${installedVersionResult.stdout}\n${installedVersionResult.stderr}',
        );
        if (_compareVersions(installedVersion, newVersion) < 0) {
          throw StateError(
            'O PowerTools instalado continua na versão $installedVersion; '
            'era esperada a versão $newVersion ou superior.',
          );
        }
        await updateRepository.markCompleted(releaseId: release.id);
      } catch (error, stackTrace) {
        await _recordFailure(release.id, error, stackTrace);
      }

      return PowerToolsUpdateResult(
        status: PowerToolsUpdateStatus.updated,
        currentVersion: currentVersion,
        newVersion: newVersion,
      );
    } finally {
      await connectionRepository.close();
    }
  }

  Future<Never> _recordFailure(
    int releaseId,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await updateRepository.markFailed(
        releaseId: releaseId,
        errorMessage: error.toString(),
      );
    } catch (updateError, updateStackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'A atualização falhou ($error) e também não foi possível '
          'registrar a falha no banco ($updateError).',
        ),
        updateStackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  Future<int> _getServerId() async {
    final config = await filePathRepository.readJson(fileName: '.env');
    final serverId = config['server_id'];
    if (serverId is! num || serverId <= 0 || serverId != serverId.toInt()) {
      throw const FormatException(
        'O campo server_id do .env deve ser um inteiro positivo.',
      );
    }
    return serverId.toInt();
  }

  String _versionFromOutput(String output) {
    final matches = RegExp(
      r'(?<![A-Za-z0-9.])v?(\d+(?:\.\d+)+)(?![A-Za-z0-9.])',
    ).allMatches(output);
    if (matches.isEmpty) {
      throw FormatException(
        'A saída de PowerTools -version não contém uma versão válida: '
        '${output.trim()}',
      );
    }
    return matches.last.group(1)!;
  }

  String _validatedVersion(String version) {
    final match = RegExp(r'^v?(\d+(?:\.\d+)*)$').firstMatch(version.trim());
    if (match == null) {
      throw FormatException('Versão inválida no banco: "$version".');
    }
    return match.group(1)!;
  }

  int _compareVersions(String left, String right) {
    final leftParts = left.split('.').map(int.parse).toList(growable: false);
    final rightParts = right.split('.').map(int.parse).toList(growable: false);
    final length = leftParts.length > rightParts.length ? leftParts.length : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }
}
