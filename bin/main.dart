import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:vr_agent/src/di/injection.dart';
import 'package:vr_agent/vr_agent.dart';

Future<void> main(List<String> arguments) async {
  final dependencies = createAppDependencies();
  if (arguments.isEmpty) {
    final agent = VRAgent(
      startAgent: dependencies.startAgent,
      closeAgent: dependencies.closeAgent,
      startScheduler: dependencies.crontabScheduler.start,
      closeScheduler: dependencies.crontabScheduler.close,
    );
    try {
      await agent.start();
    } catch (error, stackTrace) {
      developer.log(
        'VR Agent startup failed.',
        error: error,
        stackTrace: stackTrace,
      );
      await dependencies.crontabScheduler.close();
      await dependencies.closeAgent();
      io.exitCode = 1;
    }
    return;
  }

  io.exitCode = await dependencies.commandRegistry.run(arguments);
}
