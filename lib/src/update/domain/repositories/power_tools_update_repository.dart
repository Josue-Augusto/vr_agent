import 'package:vr_agent/src/update/domain/entities/power_tools_release.dart';

abstract interface class PowerToolsUpdateRepository {
  Future<PowerToolsRelease?> getLatestRelease({required int serverId});

  Future<void> markCompleted({required int releaseId, required String installedVersion});

  Future<void> markFailed({required int releaseId, required String errorMessage});
}
