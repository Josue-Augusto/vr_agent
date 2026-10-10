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
    );
    try {
      await agent.start();
    } catch (error, stackTrace) {
      developer.log(
        'Initial PostgreSQL connection failed; automatic reconnection will continue.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return;
  }

  io.exitCode = await dependencies.commandRegistry.run(arguments);
}
