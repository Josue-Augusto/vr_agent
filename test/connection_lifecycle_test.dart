import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:vr_agent/connection/data/datasources/local_connection_datasource_impl.dart';
import 'package:vr_agent/connection/data/models/connection_model.dart';
import 'package:vr_agent/connection/data/repositories/connection_repository_impl.dart';

void main() {
  group('connection lifecycle', () {
    test('uses OS-specific configuration paths', () {
      expect(connectionConfigPathFor(isWindows: true), r'C:\vr\.env');
      expect(connectionConfigPathFor(isWindows: false), '/vr/.env');
    });

    test('opens a replacement when the current connection is closed', () async {
      final datasource = _FakeConnectionDatasource();
      final repository = PostgreSQLConnectionImpl(
        dataSource: datasource,
        healthCheckInterval: const Duration(hours: 1),
      );
      addTearDown(repository.close);

      await repository.init();
      final initialConnection = datasource.connections.single;
      initialConnection.disconnect();

      final connection = await repository.getConnection();

      expect(datasource.openCount, 2);
      expect(connection, same(datasource.connections.last));
      expect(connection.isOpen, isTrue);
    });

    test('health checks reconnect after a network failure', () async {
      final datasource = _FakeConnectionDatasource();
      final repository = PostgreSQLConnectionImpl(
        dataSource: datasource,
        healthCheckInterval: const Duration(milliseconds: 10),
      );
      addTearDown(repository.close);

      await repository.init();
      datasource.connections.single.failHealthCheck = true;

      await _waitUntil(() => datasource.openCount > 1);

      expect(datasource.openCount, 2);
      expect(datasource.connections.last.isOpen, isTrue);
    });

    test('retries when the initial connection attempt fails', () async {
      final datasource = _FakeConnectionDatasource()..failNextOpen = true;
      final repository = PostgreSQLConnectionImpl(
        dataSource: datasource,
        healthCheckInterval: const Duration(milliseconds: 10),
      );
      addTearDown(repository.close);

      await expectLater(repository.init(), throwsA(isA<SocketException>()));
      await _waitUntil(() => datasource.connections.isNotEmpty);

      expect(datasource.openAttempts, greaterThanOrEqualTo(2));
      expect(datasource.connections.single.isOpen, isTrue);
    });
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for automatic PostgreSQL reconnection.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _FakeConnectionDatasource implements PostgreSQLConnectionDatasource {
  final List<_FakeConnection> connections = [];
  bool failNextOpen = false;
  int openAttempts = 0;

  int get openCount => connections.length;

  @override
  Future<Connection> openConnection({String? user, String? password}) async {
    openAttempts++;
    if (failNextOpen) {
      failNextOpen = false;
      throw const SocketException('Simulated initial connection failure');
    }
    final connection = _FakeConnection();
    connections.add(connection);
    return connection;
  }

  @override
  Future<ConnectionModel> getConfig() async {
    return ConnectionModel(
      host: 'localhost',
      port: 5432,
      database: 'test',
      username: 'test',
      password: 'test',
      sslMode: SslMode.disable,
    );
  }
}

class _FakeConnection implements Connection {
  final Completer<void> _closed = Completer<void>();
  bool _isOpen = true;
  bool failHealthCheck = false;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    if (failHealthCheck && query == 'SELECT 1') {
      throw const SocketException('Simulated network failure');
    }
    return Result(
      rows: const [],
      affectedRows: 0,
      schema: ResultSchema(const []),
    );
  }

  @override
  Future<void> close({bool force = false}) async {
    disconnect();
  }

  void disconnect() {
    if (!_isOpen) return;
    _isOpen = false;
    _closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
