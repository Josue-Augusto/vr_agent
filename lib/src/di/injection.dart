import 'package:vr_agent/core/constants/app_constants.dart';
import 'package:vr_agent/src/connection/data/datasources/postgres_connection_datasource.dart';
import 'package:vr_agent/src/connection/data/repositories/connection_repository_impl.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/crontab/data/repositories/agent_task_command_runner.dart';
import 'package:vr_agent/src/crontab/data/repositories/postgres_crontab_repository.dart';
import 'package:vr_agent/src/crontab/data/scheduler/local_crontab_scheduler.dart';
import 'package:vr_agent/src/crontab/domain/usecases/run_crontab_task.dart';
import 'package:vr_agent/src/crontab/domain/usecases/sync_crontab.dart';
import 'package:vr_agent/src/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/src/filePath/data/repositories/file_path_repository_impl.dart';
import 'package:vr_agent/src/terminal/data/repositories/power_tools_repository_impl.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/close_agent.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';
import 'package:vr_agent/src/terminal/domain/usecases/run_power_tools_command.dart';
import 'package:vr_agent/src/terminal/domain/usecases/start_agent.dart';
import 'package:vr_agent/src/terminal/presentation/cli/command_registry.dart';
import 'package:vr_agent/src/update/data/repositories/google_drive_power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/data/repositories/postgres_power_tools_update_repository.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';
import 'package:vr_agent/src/update/domain/usecases/update_power_tools.dart';

class AppDependencies {
  final StartAgent startAgent;
  final CloseAgent closeAgent;
  final GetAgentInfo getAgentInfo;
  final RunPowerToolsCommand runPowerToolsCommand;
  final LocalCrontabScheduler crontabScheduler;
  final CommandRegistry commandRegistry;

  const AppDependencies({
    required this.startAgent,
    required this.closeAgent,
    required this.getAgentInfo,
    required this.runPowerToolsCommand,
    required this.crontabScheduler,
    required this.commandRegistry,
  });
}

AppDependencies createAppDependencies({
  PlatformInfo? platformInfo,
  PostgreSQLConnectionDatasource? connectionDatasource,
  FilePathDatasource? filePathDatasource,
  PowerToolsRepository? powerToolsRepository,
  PowerToolsBinaryInstaller? powerToolsBinaryInstaller,
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
  final executablePath = PowerToolsRepositoryImpl.defaultExecutablePath(
    platform,
  );
  final toolsRepository = powerToolsRepository ?? PowerToolsRepositoryImpl(executablePath: executablePath);
  final updatePowerTools = UpdatePowerTools(
    connectionRepository: connectionRepository,
    filePathRepository: fileRepository,
    powerToolsRepository: toolsRepository,
    updateRepository: PostgresPowerToolsUpdateRepository(
      connectionRepository: connectionRepository,
    ),
    binaryInstaller: powerToolsBinaryInstaller ?? GoogleDrivePowerToolsBinaryInstaller(),
    executablePath: executablePath,
    platform: platform,
  );
  final startAgent = StartAgent(connectionRepository);
  final closeAgent = CloseAgent(connectionRepository);
  final getAgentInfo = GetAgentInfo(
    name: APP_NAME,
    version: VERSION,
    platform: platform.displayName,
  );
  final runPowerToolsCommand = RunPowerToolsCommand(toolsRepository);
  final crontabRepository = PostgresCrontabRepository(
    connectionRepository: connectionRepository,
  );
  final taskCommandRunner = AgentTaskCommandRunner(
    powerToolsRepository: toolsRepository,
    getAgentInfo: getAgentInfo,
  );
  final runCrontabTask = RunCrontabTask(
    crontabRepository: crontabRepository,
    taskCommandRunner: taskCommandRunner,
  );
  final crontabScheduler = LocalCrontabScheduler(
    filePathRepository: fileRepository,
    crontabRepository: crontabRepository,
    runCrontabTask: runCrontabTask,
  );
  final syncCrontab = SyncCrontab(
    filePathRepository: fileRepository,
    crontabRepository: crontabRepository,
    connectionRepository: connectionRepository,
  );
  final commandRegistry = createDefaultCommandPalette(
    getAgentInfo: getAgentInfo,
    runPowerToolsCommand: runPowerToolsCommand,
    syncCrontab: syncCrontab,
    filePathRepository: fileRepository,
    updatePowerTools: updatePowerTools,
  );

  return AppDependencies(
    startAgent: startAgent,
    closeAgent: closeAgent,
    getAgentInfo: getAgentInfo,
    runPowerToolsCommand: runPowerToolsCommand,
    crontabScheduler: crontabScheduler,
    commandRegistry: commandRegistry,
  );
}
