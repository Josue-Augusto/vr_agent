import 'dart:convert';

import 'package:vr_agent/core/extensions/string_extension.dart';
import 'package:vr_agent/core/feature/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/core/feature/filePath/domain/entities/platform_info.dart';
import 'package:vr_agent/core/feature/filePath/domain/repositories/file_path_repository.dart';

class FilePathRepositoryImpl implements FilePathRepository {
  final FilePathDatasource _datasource;
  final String _configPath;

  FilePathRepositoryImpl({
    FilePathDatasource? datasource,
    PlatformInfo? platformInfo,
    String? configPath,
  }) : _datasource = datasource ?? LocalFilePathDatasource(),
       _configPath =
           configPath ?? configPathFor(platformInfo ?? PlatformInfo.current);

  static String configPathFor(PlatformInfo platformInfo) =>
      platformInfo.isWindows ? r'C:\vr\.env' : '/vr/.env';

  @override
  Future<Map<String, dynamic>> readConfigJson() async {
    final contents = await readDecryptedFile(path: _configPath);
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

  @override
  Future<String> readDecryptedFile({required String path}) async {
    final encryptedContent = (await _datasource.readFile(path: path)).trim();
    return encryptedContent.decryptIsolate();
  }

  @override
  Future<void> writeEncryptedFile({
    required String path,
    required String content,
  }) async {
    final encryptedContent = await content.encryptIsolate();
    await _datasource.writeFile(path: path, content: encryptedContent);
  }
}
