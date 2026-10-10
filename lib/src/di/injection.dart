import 'dart:io';

import 'package:vr_agent/src/connection/data/datasources/postgres_connection_datasource.dart';
import 'package:vr_agent/src/connection/data/repositories/connection_repository_impl.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/src/filePath/data/repositories/file_path_repository_impl.dart';
import 'package:vr_agent/src/terminal/data/constants/app_constants.dart';
import 'package:vr_agent/src/terminal/data/repositories/power_tools_repository_impl.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/close_agent.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/domain/usecases/start_agent.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';

class AppDependencies {
  final StartAgent startAgent;
  final CloseAgent closeAgent;
  final GetAgentInfo getAgentInfo;
  final RunPowerToolsCommand runPowerToolsCommand;
  final CommandRegistry commandRegistry;

  const AppDependencies({
    required this.startAgent,
    required this.closeAgent,
    required this.getAgentInfo,
    required this.runPowerToolsCommand,
    required this.commandRegistry,
  });
}

AppDependencies createAppDependencies({
  PlatformInfo? platformInfo,
  String? powerToolsExecutablePath,
  PostgreSQLConnectionDatasource? connectionDatasource,
  FilePathDatasource? filePathDatasource,
  PowerToolsRepository? powerToolsRepository,
  Duration healthCheckInterval = const Duration(seconds: 30),
}) {
  final platform = platformInfo ?? PlatformInfo.current;
  final fileRepository = FilePathRepositoryImpl(
    datasource: filePathDatasource ?? LocalFilePathDatasource(),
    platformInfo: platform,
  );
  final postgresDatasource = connectionDatasource ?? OpenSQLConnection(filePathRepository: fileRepository);
  final connectionRepository = PostgreSQLConnectionImpl(
    dataSource: postgresDatasource,
    healthCheckInterval: healthCheckInterval,
  );
  final script = Platform.script;
  final agentDirectory = script.scheme == 'file' && script.path.toLowerCase().endsWith('.dart') ? File.fromUri(script).parent.path : File(Platform.resolvedExecutable).parent.path;
  final executablePath =
      powerToolsExecutablePath ??
      '$agentDirectory'
          '${platform.pathSeparator}PowerTools'
          '${platform.isWindows ? '.exe' : ''}';
  final toolsRepository = powerToolsRepository ?? PowerToolsRepositoryImpl(executablePath: executablePath);
  final startAgent = StartAgent(connectionRepository);
  final closeAgent = CloseAgent(connectionRepository);
  final getAgentInfo = GetAgentInfo(
    name: APP_NAME,
    version: VERSION,
    platform: platform.displayName,
  );
  final runPowerToolsCommand = RunPowerToolsCommand(toolsRepository);
  final commandRegistry = createDefaultCommandPalette(
    getAgentInfo: getAgentInfo,
    runPowerToolsCommand: runPowerToolsCommand,
  );

  return AppDependencies(
    startAgent: startAgent,
    closeAgent: closeAgent,
    getAgentInfo: getAgentInfo,
    runPowerToolsCommand: runPowerToolsCommand,
    commandRegistry: commandRegistry,
  );
}
