import 'package:postgres/postgres.dart';
import 'package:vr_agent/src/connection/data/models/connection_model.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';
import 'package:vr_agent/src/terminal/data/constants/app_constants.dart';

abstract interface class PostgreSQLConnectionDatasource {
  Future<Connection> openConnection({String? user, String? password});
  Future<ConnectionModel> getConfig();
}

class OpenSQLConnection implements PostgreSQLConnectionDatasource {
  final FilePathRepository filePathRepository;

  OpenSQLConnection({required this.filePathRepository});

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
    final data = await filePathRepository.readJson(fileName: '.env');
    return ConnectionModel.fromJson(data);
  }
}
