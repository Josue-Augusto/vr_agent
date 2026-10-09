enum ConnectionSslMode { disable, require }

class ConnectionEntity {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final ConnectionSslMode sslMode;

  const ConnectionEntity({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
  });

  ConnectionEntity copyWith({
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    ConnectionSslMode? sslMode,
  }) {
    return ConnectionEntity(
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      sslMode: sslMode ?? this.sslMode,
    );
  }
}
