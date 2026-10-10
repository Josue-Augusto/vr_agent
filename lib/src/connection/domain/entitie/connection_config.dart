enum ConnectionSslMode { disable, require }

class ConnectionConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final ConnectionSslMode sslMode;

  const ConnectionConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
  });

  ConnectionConfig copyWith({
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    ConnectionSslMode? sslMode,
  }) {
    return ConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      sslMode: sslMode ?? this.sslMode,
    );
  }
}
