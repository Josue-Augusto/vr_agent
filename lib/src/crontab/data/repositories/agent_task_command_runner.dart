import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/crontab/domain/entities/agent_task.dart';
import 'package:vr_agent/src/crontab/domain/entities/task_run_result.dart';
import 'package:vr_agent/src/crontab/domain/repositories/task_command_runner.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';
import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';

class AgentTaskCommandRunner implements TaskCommandRunner {
  final PowerToolsRepository powerToolsRepository;
  final GetAgentInfo getAgentInfo;
  final PlatformInfo platformInfo;
  final ScheduledCliInvoker cliInvoker;

  AgentTaskCommandRunner({
    required this.powerToolsRepository,
    required this.getAgentInfo,
    PlatformInfo? platformInfo,
    ScheduledCliInvoker? cliInvoker,
  }) : platformInfo = platformInfo ?? PlatformInfo.current,
       cliInvoker = cliInvoker ?? const ProcessScheduledCliInvoker();

  @override
  Future<TaskRunResult> run(AgentTask task) async {
    final parts = task.command.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || (parts.first != '-a' && parts.first != '-p')) {
      throw FormatException(
        'O comando da tarefa deve começar com "-a" (Agent) ou "-p" (PowerTools): ${task.command}',
      );
    }

    final command = parts[1];
    final arguments = parts.skip(2).toList(growable: false);
    final runAsUser = task.runAsUser?.trim();
    final requiresSeparateCli = (parts.first == '-a' && command == '-update') || (platformInfo.isLinux && runAsUser != null && runAsUser.isNotEmpty);
    if (requiresSeparateCli) {
      return cliInvoker.run(
        parts,
        runAsUser: platformInfo.isLinux && runAsUser?.isNotEmpty == true
            ? runAsUser
            : null,
        timeout: Duration(seconds: task.timeoutSeconds),
      );
    }

    if (parts.first == '-p') {
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

abstract interface class ScheduledCliInvoker {
  Future<TaskRunResult> run(
    List<String> arguments, {
    String? runAsUser,
    required Duration timeout,
  });
}

class ProcessScheduledCliInvoker implements ScheduledCliInvoker {
  const ProcessScheduledCliInvoker();

  @override
  Future<TaskRunResult> run(
    List<String> arguments, {
    String? runAsUser,
    required Duration timeout,
  }) async {
    final executable = Platform.resolvedExecutable;
    final runAs = runAsUser?.trim();
    final process = runAs != null && runAs.isNotEmpty
        ? await Process.start(
            'runuser',
            ['--user', runAs, '--', executable, ...arguments],
            workingDirectory: Directory.current.path,
            runInShell: false,
          )
        : await Process.start(
            executable,
            arguments,
            workingDirectory: Directory.current.path,
            runInShell: false,
          );

    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    var timedOut = false;
    final exitCodeFuture = process.exitCode;
    final exitCode = await exitCodeFuture.timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        process.kill();
        return exitCodeFuture;
      },
    );
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    return TaskRunResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      timedOut: timedOut,
      errorMessage: timedOut
          ? 'A tarefa excedeu o limite de tempo.'
          : exitCode == 0
          ? null
          : _failureMessage(exitCode, stdout, stderr),
    );
  }

  String _failureMessage(int exitCode, String stdout, String stderr) {
    final details = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
    return details.isEmpty ? 'O comando terminou com código $exitCode.' : 'O comando terminou com código $exitCode: $details';
  }
}
