abstract interface class FilePathRepository {
  Future<Map<String, dynamic>> readJson({required String fileName});
  Future<void> writeJson({required String fileName, required Map<String, dynamic> data});
  Stream<void> watchFile({required String fileName});
}
