class PowerToolsResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const PowerToolsResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });
}
