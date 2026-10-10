import 'dart:convert';

import 'package:vr_agent/src/core/extensions/string_extension.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';

class FilePathRepositoryImpl implements FilePathRepository {
  final FilePathDatasource datasource;
  final String _configPath;

  FilePathRepositoryImpl({
    required this.datasource,
    PlatformInfo? platformInfo,
    String? configPath,
  }) : _configPath = configPath ?? configPathFor(platformInfo ?? PlatformInfo.current);

  static String configPathFor(PlatformInfo platformInfo) => platformInfo.isWindows ? r'C:\vr\.env' : '/vr/.env';

  @override
  Future<Map<String, dynamic>> readConfigJson() async {
    final encryptedContent = (await datasource.readFile(path: _configPath)).trim();
    final contents = await encryptedContent.decryptIsolate();
    if (contents.trim().isEmpty) {
      throw FormatException(
        'O arquivo de configuração está vazio: $_configPath',
      );
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'A configuração deve ser um objeto JSON: $_configPath',
      );
    }
    return decoded;
  }
}
