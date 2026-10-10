import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';

abstract interface class PowerToolsRepository {
  Future<PowerToolsResult> execute(List<String> arguments);
}
