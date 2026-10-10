import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:vr_agent/connection/data/datasources/local_connection_datasource_impl.dart';
import 'package:vr_agent/core/feature/filePath/data/repositories/file_path_repository_impl.dart';

void main() {
  test('reads and decrypts the database configuration JSON', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final configFile = File('${directory.path}/.env');
      await FilePathRepositoryImpl().writeEncryptedFile(
        path: configFile.path,
        content: jsonEncode({
          'host': 'localhost',
          'port': 5432,
          'database': 'agent',
          'username': 'agent_user',
          'password': 'secret',
          'sslMode': true,
        }),
      );

      final config = await OpenSQLConnection(
        filePathRepository: FilePathRepositoryImpl(configPath: configFile.path),
      ).getConfig();

      expect(config.host, 'localhost');
      expect(config.port, 5432);
      expect(config.database, 'agent');
      expect(config.username, 'agent_user');
      expect(config.password, 'secret');
      expect(config.sslMode, SslMode.require);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('reports malformed decrypted configuration as invalid JSON', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final configFile = File('${directory.path}/.env');
      await FilePathRepositoryImpl().writeEncryptedFile(
        path: configFile.path,
        content: 'not-json',
      );

      final datasource = OpenSQLConnection(
        filePathRepository: FilePathRepositoryImpl(configPath: configFile.path),
      );

      await expectLater(datasource.getConfig(), throwsA(isA<FormatException>()));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rejects a JSON value that is not an object', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final configFile = File('${directory.path}/.env');
      await FilePathRepositoryImpl().writeEncryptedFile(
        path: configFile.path,
        content: '["not", "an", "object"]',
      );

      final repository = FilePathRepositoryImpl(configPath: configFile.path);

      await expectLater(repository.readConfigJson(), throwsA(isA<FormatException>()));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
