class AgentTask {
  final int id;
  final int serverId;
  final String name;
  final String? description;
  final String command;
  final String schedule;
  final String timezone;
  final bool enabled;
  final int timeoutSeconds;
  final int maxRetries;
  final int retryDelaySeconds;
  final String? runAsUser;
  final int priority;

  const AgentTask({
    required this.id,
    required this.serverId,
    required this.name,
    required this.description,
    required this.command,
    required this.schedule,
    required this.timezone,
    required this.enabled,
    required this.timeoutSeconds,
    required this.maxRetries,
    required this.retryDelaySeconds,
    required this.runAsUser,
    required this.priority,
  });

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    final timeoutSeconds = (json['timeout_seconds'] as num? ?? 300).toInt();
    final maxRetries = (json['max_retries'] as num? ?? 0).toInt();
    final retryDelaySeconds = (json['retry_delay_sec'] as num? ?? 60).toInt();
    if (timeoutSeconds <= 0 || maxRetries < 0 || retryDelaySeconds < 0) {
      throw const FormatException(
        'timeout_seconds deve ser positivo; max_retries e retry_delay_sec não podem ser negativos.',
      );
    }
    return AgentTask(
      id: (json['id'] as num).toInt(),
      serverId: (json['server_id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      command: json['command'] as String,
      schedule: json['schedule'] as String,
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      enabled: json['enabled'] as bool? ?? true,
      timeoutSeconds: timeoutSeconds,
      maxRetries: maxRetries,
      retryDelaySeconds: retryDelaySeconds,
      runAsUser: json['run_as_user'] as String?,
      priority: (json['priority'] as num? ?? 5).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'server_id': serverId,
    'name': name,
    'description': description,
    'command': command,
    'schedule': schedule,
    'timezone': timezone,
    'enabled': enabled,
    'timeout_seconds': timeoutSeconds,
    'max_retries': maxRetries,
    'retry_delay_sec': retryDelaySeconds,
    'run_as_user': runAsUser,
    'priority': priority,
  };
}
