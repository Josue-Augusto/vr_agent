import 'package:vr_agent/core/extensions/string_extension.dart';
import 'package:vr_agent/core/feature/filePath/data/datasources/local_file_path_datasource.dart';
import 'package:vr_agent/core/feature/filePath/domain/repositories/file_path_repository.dart';

class FilePathRepositoryImpl implements FilePathRepository {
  final FilePathDatasource _datasource;

  FilePathRepositoryImpl({FilePathDatasource? datasource}) : _datasource = datasource ?? LocalFilePathDatasource();

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
