abstract interface class FilePathRepository {
  Future<String> readDecryptedFile({required String path});
  Future<void> writeEncryptedFile({required String path, required String content});
}
