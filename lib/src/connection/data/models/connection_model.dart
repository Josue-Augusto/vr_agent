import 'package:postgres/postgres.dart';
import 'package:vr_agent/src/connection/domain/entitie/connection_config.dart';

class ConnectionModel {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final SslMode sslMode;

  ConnectionModel({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
  });

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    final sslEnabled = json['sslMode'] == true;
    return ConnectionModel(
      host: (json['host'] ?? 'localhost') as String,
      port: (json['port'] ?? 5432) as int,
      database: (json['database'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      password: (json['password'] ?? '') as String,
      sslMode: sslEnabled ? SslMode.require : SslMode.disable,
    );
  }

  factory ConnectionModel.fromEntity(ConnectionConfig entity) {
    return ConnectionModel(
      host: entity.host,
      port: entity.port,
      database: entity.database,
      username: entity.username,
      password: entity.password,
      sslMode: entity.sslMode == ConnectionSslMode.require ? SslMode.require : SslMode.disable,
    );
  }

  ConnectionConfig toEntity() {
    return ConnectionConfig(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      sslMode: sslMode == SslMode.require ? ConnectionSslMode.require : ConnectionSslMode.disable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'database': database,
      'username': username,
      'password': password,
      'sslMode': sslMode == SslMode.require,
    };
  }

  ConnectionModel copyWith({
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    SslMode? sslMode,
  }) {
    return ConnectionModel(
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      sslMode: sslMode ?? this.sslMode,
    );
  }
}
