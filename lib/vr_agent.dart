import 'package:vr_agent/src/terminal/domain/usecases/close_agent.dart';
import 'package:vr_agent/src/terminal/domain/usecases/start_agent.dart';

class VRAgent {
  final StartAgent startAgent;
  final CloseAgent closeAgent;

  const VRAgent({required this.startAgent, required this.closeAgent});

  Future<void> start() => startAgent();

  Future<void> close() => closeAgent();
}
