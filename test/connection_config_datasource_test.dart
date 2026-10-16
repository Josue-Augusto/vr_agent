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
        directoryPath: directory.path,
      );
      await LocalFilePathDatasource().writeFile(
        path: configFile.path,
        content: await jsonEncode({
          'remotehost': 'localhost',
          'remoteport': 5432,
          'remotedatabase': 'agent',
          'remoteusername': 'agent_user',
          'remotepassword': 'secret',
          'remotesslMode': true,
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
        directoryPath: directory.path,
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
        directoryPath: directory.path,
      );
      await LocalFilePathDatasource().writeFile(
        path: configFile.path,
        content: await '["not", "an", "object"]'.encryptIsolate(),
      );

      await expectLater(
        repository.readJson(fileName: '.env'),
        throwsA(isA<FormatException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('writes and reads encrypted JSON using a dynamic file name', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final repository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        directoryPath: '${directory.path}/nested',
      );
      final data = <String, dynamic>{'setting': 'value', 'enabled': true};

      await repository.writeJson(fileName: 'config.conf', data: data);

      final storedContent = await File(
        '${directory.path}/nested/config.conf',
      ).readAsString();
      expect(storedContent, isNot(contains('"setting"')));
      expect(await storedContent.decryptIsolate(), jsonEncode(data));
      expect(await repository.readJson(fileName: 'config.conf'), data);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('creates the parent directory and file when reading a missing file', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final repository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        directoryPath: '${directory.path}/missing/nested',
      );

      await expectLater(
        repository.readJson(fileName: 'config.conf'),
        throwsA(isA<FormatException>()),
      );
      expect(
        await File('${directory.path}/missing/nested/config.conf').exists(),
        isTrue,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('treats an empty crontab file as an empty task schedule', () async {
    final directory = await Directory.systemTemp.createTemp();

    try {
      final repository = FilePathRepositoryImpl(
        datasource: LocalFilePathDatasource(),
        directoryPath: directory.path,
      );

      expect(await repository.readJson(fileName: '.crontab'), {'tasks': <dynamic>[]});
      await expectLater(
        repository.readJson(fileName: '.env'),
        throwsA(isA<FormatException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
