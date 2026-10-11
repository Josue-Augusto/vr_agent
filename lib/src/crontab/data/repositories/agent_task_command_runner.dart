import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';
import 'package:vr_agent/src/crontab/domain/repositories/task_command_runner.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';

class AgentTaskCommandRunner implements TaskCommandRunner {
  final PowerToolsRepository powerToolsRepository;
  final GetAgentInfo getAgentInfo;

  const AgentTaskCommandRunner({
    required this.powerToolsRepository,
    required this.getAgentInfo,
  });

  @override
  Future<TaskRunResult> run(AgentTask task) async {
    if (task.runAsUser != null && task.runAsUser!.isNotEmpty) {
      throw UnsupportedError('run_as_user ainda não é suportado pelo agente.');
    }
    final parts = task.command.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || (parts.first != 'a' && parts.first != 'p')) {
      throw FormatException(
        'O comando da tarefa deve começar com "a" (Agent) ou "p" (PowerTools): ${task.command}',
      );
    }

    final command = parts[1];
    final arguments = parts.skip(2).toList(growable: false);
    if (parts.first == 'p') {
      final result = await powerToolsRepository.execute([
        command,
        ...arguments,
      ], timeout: Duration(seconds: task.timeoutSeconds));
      return TaskRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        timedOut: result.timedOut,
        errorMessage: result.timedOut
            ? 'A tarefa excedeu o limite de tempo.'
            : result.exitCode == 0
            ? null
            : 'PowerTools terminou com código ${result.exitCode}.',
      );
    }

    final agentInfo = getAgentInfo();
    if (command == '-version' && arguments.isEmpty) {
      return TaskRunResult(
        exitCode: 0,
        stdout: '${agentInfo.name} ${agentInfo.version}\n',
        stderr: '',
      );
    }
    if (command == '-info' && arguments.isEmpty) {
      return TaskRunResult(
        exitCode: 0,
        stdout: '${agentInfo.name} ${agentInfo.version}\nPlataforma: ${agentInfo.platform}\n',
        stderr: '',
      );
    }
    throw FormatException('Comando nativo do agente não suportado: $command');
  }
}
