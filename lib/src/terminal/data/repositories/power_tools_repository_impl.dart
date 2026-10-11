import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';

class PowerToolsRepositoryImpl implements PowerToolsRepository {
  final String executablePath;

  static String defaultExecutablePath(PlatformInfo platform) {
    final directory = platform.isWindows ? r'C:\vr\agent' : '/vr/agent';
    return '$directory${platform.pathSeparator}PowerTools'
        '${platform.isWindows ? '.exe' : ''}';
  }

  const PowerToolsRepositoryImpl({required this.executablePath});

  @override
  Future<PowerToolsResult> execute(
    List<String> arguments, {
    Duration? timeout,
  }) async {
    final executable = File(executablePath);
    if (!await executable.exists()) {
      throw FileSystemException(
        'PowerTools não encontrado',
        executable.path,
      );
    }

    final process = await Process.start(
      executable.path,
      arguments,
      workingDirectory: executable.parent.path,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    var timedOut = false;
    final exitCodeFuture = process.exitCode;
    final exitCode = timeout == null
        ? await exitCodeFuture
        : await exitCodeFuture.timeout(
            timeout,
            onTimeout: () {
              timedOut = true;
              process.kill();
              return exitCodeFuture;
            },
          );
    return PowerToolsResult(
      exitCode: exitCode,
      stdout: await stdoutFuture,
      stderr: await stderrFuture,
      timedOut: timedOut,
    );
  }
}
