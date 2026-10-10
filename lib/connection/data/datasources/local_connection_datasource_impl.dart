import 'package:postgres/postgres.dart';
import 'package:vr_agent/connection/data/models/connection_model.dart';
import 'package:vr_agent/core/feature/filePath/data/repositories/file_path_repository_impl.dart';
import 'package:vr_agent/core/feature/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/core/tools/constants.dart';

abstract interface class PostgreSQLConnectionDatasource {
  Future<Connection> openConnection({String? user, String? password});
  Future<ConnectionModel> getConfig();
}

class OpenSQLConnection implements PostgreSQLConnectionDatasource {
  final FilePathRepository _filePathRepository;

  OpenSQLConnection({
    FilePathRepository? filePathRepository,
  }) : _filePathRepository = filePathRepository ?? FilePathRepositoryImpl();

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
    final data = await _filePathRepository.readConfigJson();
    return ConnectionModel.fromJson(data);
  }
}
