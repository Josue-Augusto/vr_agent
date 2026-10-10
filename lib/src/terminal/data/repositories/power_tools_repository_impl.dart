import 'dart:io';

import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';

class PowerToolsRepositoryImpl implements PowerToolsRepository {
  final String executablePath;

  const PowerToolsRepositoryImpl({required this.executablePath});

  @override
  Future<PowerToolsResult> execute(List<String> arguments) async {
    final executable = File(executablePath);
    if (!await executable.exists()) {
      throw FileSystemException(
        'PowerTools não encontrado',
        executable.path,
      );
    }

    final result = await Process.run(
      executable.path,
      arguments,
      workingDirectory: executable.parent.path,
      runInShell: false,
    );
    return PowerToolsResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}
