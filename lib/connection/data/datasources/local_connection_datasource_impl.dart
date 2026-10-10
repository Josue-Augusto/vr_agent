import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:vr_agent/connection/data/models/connection_model.dart';
import 'package:vr_agent/core/feature/filePath/data/repositories/file_path_repository_impl.dart';
import 'package:vr_agent/core/feature/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/core/tools/constants.dart';

String get connectionConfigPath => connectionConfigPathFor(isWindows: Platform.isWindows);

String connectionConfigPathFor({required bool isWindows}) => isWindows ? r'C:\vr\.env' : '/vr/.env';

abstract interface class PostgreSQLConnectionDatasource {
  Future<Connection> openConnection({String? user, String? password});
  Future<ConnectionModel> getConfig();
}

class OpenSQLConnection implements PostgreSQLConnectionDatasource {
  final FilePathRepository _filePathRepository;
  final String configPath;

  OpenSQLConnection({
    FilePathRepository? filePathRepository,
    String? configPath,
  }) : _filePathRepository = filePathRepository ?? FilePathRepositoryImpl(),
       configPath = configPath ?? connectionConfigPath;

  @override
  Future<Connection> openConnection({String? user, String? password}) async {
    final config = await getConfig();
    final conn = await Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: user ?? config.username,
        password: password ?? config.password,
      ),
      settings: ConnectionSettings(sslMode: config.sslMode, applicationName: APP_NAME_ID),
    );
    return conn;
  }

  @override
  Future<ConnectionModel> getConfig() async {
    final json = await _filePathRepository.readDecryptedFile(
      path: configPath,
    );
    if (json.trim().isEmpty) {
      throw FormatException(
        'O arquivo de configuração de conexão está vazio: $configPath',
      );
    }

    final Map<String, dynamic> data = jsonDecode(json) as Map<String, dynamic>;
    return ConnectionModel.fromJson(data);
  }
}
