import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:vr_agent/connection/data/datasources/local_connection_datasource_impl.dart';
import 'package:vr_agent/connection/domain/entitie/connection_entity.dart';
import 'package:vr_agent/connection/domain/repositories/connection_repository.dart';

class PostgreSQLConnectionImpl implements ConnectionRepository {
  Connection? _connection;
  Future<void>? _initFuture;
  Future<Connection>? _reconnectFuture;
  Future<void>? _healthCheckFuture;
  Timer? _healthCheckTimer;
  ConnectionEntity? _verifiedConfig;
  String? _user;
  String? _password;
  bool _closed = false;
  final PostgreSQLConnectionDatasource _dataSource;
  final Duration healthCheckInterval;

  PostgreSQLConnectionImpl({
    PostgreSQLConnectionDatasource? dataSource,
    this.healthCheckInterval = const Duration(seconds: 30),
  }) : _dataSource = dataSource ?? OpenSQLConnection();

  @override
  Future<void> init({String? user, String? password}) {
    _closed = false;
    _startHealthChecks();
    if (user != null) _user = user;
    if (password != null) _password = password;
    final current = _initFuture;
    if (current != null) return current;

    late final Future<void> attempt;
    attempt = _init(user: _user, password: _password).catchError((Object error, StackTrace stackTrace) {
      if (identical(_initFuture, attempt)) _initFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _initFuture = attempt;
    return attempt;
  }

  Future<void> _init({String? user, String? password}) async {
    final connection = await _dataSource.openConnection(
      user: user,
      password: password,
    );
    _connection = connection;
    _watchConnection(connection);
    final config = await _dataSource.getConfig();
    _verifiedConfig = config
        .copyWith(
          username: user ?? config.username,
          password: password ?? config.password,
        )
        .toEntity();
  }

  @override
  Future<Connection> getConnection({String? user, String? password}) async {
    _closed = false;
    _startHealthChecks();
    final reconnecting = _reconnectFuture;
    if (reconnecting != null) return reconnecting;
    await init(user: user, password: password);
    final reconnectingAfterInit = _reconnectFuture;
    if (reconnectingAfterInit != null) return reconnectingAfterInit;
    final connection = _connection;
    if (connection == null) {
      return _replaceConnection(expected: null, force: true);
    }
    if (!connection.isOpen) return _replaceConnection(expected: connection);
    return connection;
  }

  @override
  Future<Result> execute(Object query, {Object? parameters}) async {
    final connection = await getConnection();
    try {
      return await connection.execute(query, parameters: parameters);
    } catch (error, stackTrace) {
      if (!_isConnectionFailure(error, connection)) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final recoveredConnection = await _replaceConnection(expected: connection);
      return recoveredConnection.execute(query, parameters: parameters);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _verifiedConfig = null;
    _initFuture = null;
    final connection = _connection;
    _connection = null;
    if (connection != null) await connection.close();
  }

  @override
  Future<ConnectionEntity> getConfig() async {
    final config = await _dataSource.getConfig();
    return config.toEntity();
  }

  @override
  bool isVerifiedFor(ConnectionEntity config) {
    final verifiedConfig = _verifiedConfig;
    return verifiedConfig != null &&
        verifiedConfig.host == config.host &&
        verifiedConfig.port == config.port &&
        verifiedConfig.database == config.database &&
        verifiedConfig.username == config.username &&
        verifiedConfig.password == config.password &&
        verifiedConfig.sslMode == config.sslMode;
  }

  @override
  Future<void> reconnect({String? user, String? password}) async {
    _closed = false;
    _startHealthChecks();
    if (user != null) _user = user;
    if (password != null) _password = password;
    await _replaceConnection(expected: _connection, force: true);
  }

  Future<Connection> _replaceConnection({required Connection? expected, bool force = false}) {
    final reconnecting = _reconnectFuture;
    if (reconnecting != null) return reconnecting;
    if (!force && expected != null && !identical(_connection, expected)) {
      return getConnection();
    }

    late final Future<Connection> attempt;
    attempt = _openReplacement(expected: expected, force: force).whenComplete(() {
      if (identical(_reconnectFuture, attempt)) _reconnectFuture = null;
    });
    _reconnectFuture = attempt;
    return attempt;
  }

  Future<Connection> _openReplacement({required Connection? expected, required bool force}) async {
    if (!force && expected != null && !identical(_connection, expected)) {
      return getConnection();
    }

    final previousConnection = _connection;
    _connection = null;
    _initFuture = null;
    _verifiedConfig = null;
    if (previousConnection != null) {
      try {
        await previousConnection.close(force: true);
      } catch (error, stackTrace) {
        developer.log('Failed to close stale PostgreSQL connection before reconnecting.', error: error, stackTrace: stackTrace);
      }
    }
    await init(user: _user, password: _password);
    final connection = _connection;
    if (connection == null || !connection.isOpen) {
      throw StateError('Não foi possível restabelecer a conexão PostgreSQL.');
    }
    return connection;
  }

  void _startHealthChecks() {
    if (_healthCheckTimer != null || _closed) return;
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) {
      if (_healthCheckFuture != null || _closed) return;

      late final Future<void> healthCheck;
      healthCheck = _performHealthCheck().whenComplete(() {
        if (identical(_healthCheckFuture, healthCheck)) {
          _healthCheckFuture = null;
        }
      });
      _healthCheckFuture = healthCheck;
      unawaited(healthCheck);
    });
  }

  Future<void> _performHealthCheck() async {
    try {
      final connection = await getConnection();
      await connection.execute('SELECT 1');
    } catch (error, stackTrace) {
      developer.log(
        'PostgreSQL health check failed; attempting to reconnect.',
        error: error,
        stackTrace: stackTrace,
      );
      final connection = _connection;
      try {
        await _replaceConnection(expected: connection, force: connection?.isOpen ?? false);
      } catch (reconnectError, reconnectStackTrace) {
        developer.log(
          'PostgreSQL reconnection attempt failed; the health check will retry.',
          error: reconnectError,
          stackTrace: reconnectStackTrace,
        );
      }
    }
  }

  void _watchConnection(Connection connection) {
    unawaited(
      connection.closed.then((_) async {
        if (_closed || !identical(_connection, connection)) return;
        try {
          await _replaceConnection(expected: connection);
        } catch (error, stackTrace) {
          developer.log(
            'PostgreSQL connection closed; automatic reconnection failed.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }),
    );
  }

  bool _isConnectionFailure(Object error, Connection connection) {
    if (!connection.isOpen || error is SocketException || error is IOException) return true;
    if (error is! PgException) return false;
    if (error.severity == Severity.fatal || error.severity == Severity.panic) return true;
    final message = error.message.toLowerCase();
    return message.contains('connection is not open') || message.contains('connection is closing') || message.contains('connection closed');
  }
}
