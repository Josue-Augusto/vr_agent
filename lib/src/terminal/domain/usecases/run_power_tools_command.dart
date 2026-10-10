import 'package:vr_agent/src/terminal/domain/entities/power_tools_result.dart';
import 'package:vr_agent/src/terminal/domain/repositories/power_tools_repository.dart';

class RunPowerToolsCommand {
  final PowerToolsRepository _repository;

  const RunPowerToolsCommand(this._repository);

  Future<PowerToolsResult> call(List<String> arguments) => _repository.execute(arguments);
}
