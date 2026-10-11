enum PowerToolsInstallStatus { installed, alreadyInstalled }

class PowerToolsInstallResult {
  final PowerToolsInstallStatus status;
  final String? version;

  const PowerToolsInstallResult({required this.status, this.version});
}
