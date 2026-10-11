import 'package:vr_agent/src/terminal/domain/usecases/close_agent.dart';
import 'package:vr_agent/src/terminal/domain/usecases/start_agent.dart';

class VRAgent {
  final StartAgent startAgent;
  final CloseAgent closeAgent;
  final Future<void> Function()? startScheduler;
  final Future<void> Function()? closeScheduler;

  const VRAgent({
    required this.startAgent,
    required this.closeAgent,
    this.startScheduler,
    this.closeScheduler,
  });

  Future<void> start() async {
    await startAgent();
    await startScheduler?.call();
  }

  Future<void> close() async {
    await closeScheduler?.call();
    await closeAgent();
  }
}
