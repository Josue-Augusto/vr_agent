import 'dart:io';

abstract interface class FilePathDatasource {
  Future<String> readFile({required String path});
  Future<void> writeFile({required String path, required String content});
  Stream<void> watchFile({required String path});
}

class LocalFilePathDatasource implements FilePathDatasource {
  @override
  Future<String> readFile({required String path}) async {
    final file = File(path);
    await file.create(recursive: true);
    return file.readAsString();
  }

  @override
  Future<void> writeFile({required String path, required String content}) async {
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Stream<void> watchFile({required String path}) =>
      File(path).watch().map((_) {});
}
