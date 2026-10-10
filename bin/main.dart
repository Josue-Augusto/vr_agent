import 'dart:io' as io;

import 'package:vr_agent/cli/command_registry.dart';
import 'package:vr_agent/vr_agent.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    final agent = VRAgent();
    await agent.start();
    return;
  }

  io.exitCode = await createDefaultCommandPalette().run(arguments);
}
