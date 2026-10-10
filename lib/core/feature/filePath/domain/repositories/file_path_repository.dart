abstract interface class FilePathRepository {
  Future<Map<String, dynamic>> readConfigJson();
  Future<String> readDecryptedFile({required String path});
  Future<void> writeEncryptedFile({required String path, required String content});
}
