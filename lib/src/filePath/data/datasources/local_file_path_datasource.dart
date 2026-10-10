import 'dart:io';

abstract interface class FilePathDatasource {
  Future<String> readFile({required String path});
  Future<void> writeFile({required String path, required String content});
}

class LocalFilePathDatasource implements FilePathDatasource {
  @override
  Future<String> readFile({required String path}) {
    return File(path).readAsString();
  }

  @override
  Future<void> writeFile({required String path, required String content}) {
    return File(path).writeAsString(content);
  }
}
