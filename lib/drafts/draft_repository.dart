abstract class DraftRepository {
  Future<List<Map<String, dynamic>>> history();
  Future<Map<String, dynamic>> read(String id);
  Future<void> save(Map<String, dynamic> revision);
}
