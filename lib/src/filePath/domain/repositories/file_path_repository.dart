abstract interface class FilePathRepository {
  Future<Map<String, dynamic>> readConfigJson();
}
