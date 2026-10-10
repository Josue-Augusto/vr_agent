import 'package:vr_agent/src/terminal/domain/entities/agent_info.dart';

class GetAgentInfo {
  final String name;
  final String version;
  final String platform;

  const GetAgentInfo({required this.name, required this.version, required this.platform});

  AgentInfo call() => AgentInfo(name: name, version: version, platform: platform);
}
