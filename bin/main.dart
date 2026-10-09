import 'package:vr_agent/vr_agent.dart';

Future<void> main() async {
  final agent = VRAgent();
  await agent.start();
}
