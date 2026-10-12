import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/install/domain/entities/power_tools_install_result.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_update_repository.dart';

class InstallPowerTools {
  final ConnectionRepository connectionRepository;
  final FilePathRepository filePathRepository;
  final PowerToolsUpdateRepository updateRepository;
  final PowerToolsBinaryInstaller binaryInstaller;
  final String executablePath;
  final PlatformInfo platform;

  const InstallPowerTools({
    required this.connectionRepository,
    required this.filePathRepository,
    required this.updateRepository,
    required this.binaryInstaller,
    required this.executablePath,
    required this.platform,
  });

  Future<PowerToolsInstallResult> call() async {
    if (await binaryInstaller.isInstalled(executablePath: executablePath)) {
      return const PowerToolsInstallResult(
        status: PowerToolsInstallStatus.alreadyInstalled,
      );
    }

    await connectionRepository.init();
    try {
      final config = await filePathRepository.readJson(fileName: '.env');
      final serverId = config['server_id'];
      if (serverId is! num ||
          serverId <= 0 ||
          serverId != serverId.toInt()) {
        throw const FormatException(
          'O campo server_id do .env deve ser um inteiro positivo.',
        );
      }

      final release = await updateRepository.getLatestRelease(
        serverId: serverId.toInt(),
      );
      if (release == null) {
        throw StateError(
          'Nenhum link de instalação do PowerTools foi cadastrado para este servidor.',
        );
      }
      late final String version;
      try {
        version = _validatedVersion(release.newVersion);
        await binaryInstaller.install(
          repositoryUrl: release.repository,
          executablePath: executablePath,
          platform: platform,
        );
        await updateRepository.markCompleted(releaseId: release.id);
      } catch (error, stackTrace) {
        try {
          await updateRepository.markFailed(
            releaseId: release.id,
            errorMessage: error.toString(),
          );
        } catch (updateError, updateStackTrace) {
          Error.throwWithStackTrace(
            StateError(
              'A instalação falhou ($error) e também não foi possível '
              'registrar a falha no banco ($updateError).',
            ),
            updateStackTrace,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      return PowerToolsInstallResult(
        status: PowerToolsInstallStatus.installed,
        version: version,
      );
    } finally {
      await connectionRepository.close();
    }
  }

  String _validatedVersion(String version) {
    final match = RegExp(r'^v?(\d+(?:\.\d+)*)$').firstMatch(version.trim());
    if (match == null) {
      throw FormatException('Versão inválida no banco: "$version".');
    }
    return match.group(1)!;
  }
}
