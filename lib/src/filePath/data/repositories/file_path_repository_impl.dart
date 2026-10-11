import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:vr_agent/src/core/extensions/string_extension.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/src/filePath/domain/repositories/file_path_repository.dart';

class FilePathRepositoryImpl implements FilePathRepository {
  final FilePathDatasource datasource;
  final p.Context _pathContext;
  final String _directoryPath;

  FilePathRepositoryImpl({
    required this.datasource,
    PlatformInfo? platformInfo,
    String? directoryPath,
  }) : _pathContext = p.Context(
         style: (platformInfo ?? PlatformInfo.current).isWindows ? p.Style.windows : p.Style.posix,
       ),
       _directoryPath = directoryPath ?? directoryPathFor(platformInfo ?? PlatformInfo.current);

  static String directoryPathFor(PlatformInfo platformInfo) =>
      platformInfo.isWindows ? r'C:\vr\agent' : '/vr/agent';

  String get directoryPath => _directoryPath;

  @override
  Future<Map<String, dynamic>> readJson({required String fileName}) async {
    final path = _pathFor(fileName);
    final encryptedContent = (await datasource.readFile(path: path)).trim();
    if (encryptedContent.isEmpty) {
      throw FormatException('O arquivo está vazio: $path');
    }

    final contents = await encryptedContent.decryptIsolate();
    if (contents.trim().isEmpty) {
      throw FormatException(
        'O arquivo está vazio: $path',
      );
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'O conteúdo deve ser um objeto JSON: $path',
      );
    }
    return decoded;
  }

  @override
  Future<void> writeJson({
    required String fileName,
    required Map<String, dynamic> data,
  }) async {
    final path = _pathFor(fileName);
    final encryptedContent = await jsonEncode(data).encryptIsolate();
    await datasource.writeFile(path: path, content: encryptedContent);
  }

  String _pathFor(String fileName) {
    if (fileName.isEmpty || fileName == '.' || fileName == '..' || _pathContext.basename(fileName) != fileName) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Informe apenas o nome do arquivo, sem diretórios.',
      );
    }
    return _pathContext.join(_directoryPath, fileName);
  }
}
