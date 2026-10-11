enum PowerToolsUpdateStatus { noRelease, upToDate, updated }

class PowerToolsUpdateResult {
  final PowerToolsUpdateStatus status;
  final String currentVersion;
  final String? newVersion;

  const PowerToolsUpdateResult({
    required this.status,
    required this.currentVersion,
    this.newVersion,
  });
}
