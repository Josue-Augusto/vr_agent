import 'dart:io';

import 'package:vr_agent/src/terminal/domain/usecases/get_agent_info.dart';

class VersionCommand {
  final GetAgentInfo _getAgentInfo;

  const VersionCommand(this._getAgentInfo);

  Future<int> call(List<String> arguments) async {
    final info = _getAgentInfo();
    stdout.writeln('${info.name} ${info.version}');
    return 0;
  }
}
