import 'dart:async';
import 'dart:io' as io;

import 'package:vr_agent/src/di/injection.dart';
import 'package:vr_agent/vr_agent.dart';

Future<void> main(List<String> arguments) async {
  final dependencies = createAppDependencies();
  if (arguments.isEmpty || (arguments.length == 1 && arguments.single == '--service')) {
    await _runService(dependencies);
    return;
  }

  io.exitCode = await dependencies.commandRegistry.run(arguments);
}

Future<void> _runService(AppDependencies dependencies) async {
  final agent = VRAgent(
    startAgent: dependencies.startAgent,
    closeAgent: dependencies.closeAgent,
    startScheduler: dependencies.crontabScheduler.start,
    closeScheduler: dependencies.crontabScheduler.close,
  );
  final shutdown = Completer<void>();
  final signalSubscriptions = <StreamSubscription<io.ProcessSignal>>[];

  void requestShutdown(io.ProcessSignal signal) {
    if (!shutdown.isCompleted) {
      io.stdout.writeln('VR Agent received $signal; shutting down.');
      shutdown.complete();
    }
  }

  final signals = io.Platform.isWindows
      ? [io.ProcessSignal.sigint]
      : [io.ProcessSignal.sigint, io.ProcessSignal.sigterm];
  for (final signal in signals) {
    try {
      signalSubscriptions.add(signal.watch().listen(requestShutdown));
    } on UnsupportedError catch (error, stackTrace) {
      _writeServiceError(
        'Signal $signal is not supported; the service manager may terminate the process.',
        error,
        stackTrace,
      );
    }
  }

  try {
    await agent.start();
    io.stdout.writeln('VR Agent service started; waiting for scheduled tasks.');
    await shutdown.future;
  } catch (error, stackTrace) {
    _writeServiceError(
      'VR Agent service failed.',
      error,
      stackTrace,
    );
    io.exitCode = 1;
  } finally {
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
    try {
      await agent.close();
    } catch (error, stackTrace) {
      _writeServiceError(
        'VR Agent service shutdown failed.',
        error,
        stackTrace,
      );
      io.exitCode = 1;
    }
  }
}

void _writeServiceError(
  String message,
  Object error,
  StackTrace stackTrace,
) {
  io.stderr.writeln('$message\n$error\n$stackTrace');
}
