class TaskRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String? errorMessage;
  final bool timedOut;

  const TaskRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.errorMessage,
    this.timedOut = false,
  });

  bool get succeeded => exitCode == 0 && !timedOut && errorMessage == null;
}
