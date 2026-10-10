import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:vr_agent/src/connection/data/datasources/postgres_connection_datasource.dart';
import 'package:vr_agent/src/core/extensions/string_extension.dart';
import 'package:vr_agent/src/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/src/filePath/data/repositories/file_path_repository_impl.dart';

void main() {
  test('reads and decrypts the database configuration JSON', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final configFile = File('${directory.path}/.env');
      final fileRepository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        configPath: configFile.path,
      );
      await LocalFilePathDatasource().writeFile(
        path: configFile.path,
        content: await jsonEncode({
          'host': 'localhost',
          'port': 5432,
          'database': 'agent',
          'username': 'agent_user',
          'password': 'secret',
          'sslMode': true,
        }).encryptIsolate(),
      );

      final config = await OpenSQLConnection(
        filePathRepository: fileRepository,
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
      final fileRepository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        configPath: configFile.path,
      );
      await LocalFilePathDatasource().writeFile(
        path: configFile.path,
        content: await 'not-json'.encryptIsolate(),
      );

      final datasource = OpenSQLConnection(
        filePathRepository: fileRepository,
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
      final repository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        configPath: configFile.path,
      );
      await LocalFilePathDatasource().writeFile(
        path: configFile.path,
        content: await '["not", "an", "object"]'.encryptIsolate(),
      );

      await expectLater(repository.readConfigJson(), throwsA(isA<FormatException>()));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
