import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'draft_repository.dart';

class DraftStore implements DraftRepository {
  DraftStore({this.directory});
  final Directory? directory;
  Future<Directory> _root() async =>
      directory ??
      Directory(
        '${(await getApplicationSupportDirectory()).path}/dec-drafts-v1',
      );
  @override
  Future<void> save(Map<String, dynamic> revision) async {
    final root = await _root();
    await root.create(recursive: true);
    final id = revision['id'] as String;
    _checkId(id);
    final file = File('${root.path}/$id.json');
    final pending = File('${root.path}/$id.pending');
    await pending.writeAsString(jsonEncode(revision), flush: true);
    await pending.rename(file.path);
  }

  void _checkId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      throw const FormatException('Invalid revision');
    }
  }

  @override
  Future<Map<String, dynamic>> read(String id) async {
    _checkId(id);
    final value =
        jsonDecode(
              await File('${(await _root()).path}/$id.json').readAsString(),
            )
            as Map<String, dynamic>;
    if (value['schema'] != 1 || value['id'] != id || value['data'] is! Map) {
      throw const FormatException('Invalid draft');
    }
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> history() async {
    final root = await _root();
    if (!await root.exists()) return [];
    final files = await root
        .list(followLinks: false)
        .where((f) => f is File && f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    final result = <Map<String, dynamic>>[];
    for (final file in files.take(50)) {
      final id = file.uri.pathSegments.last.replaceFirst('.json', '');
      // A corrupt revision must be reported, never silently treated as an empty library.
      final revision = await read(id);
      result.add({
        'id': id,
        'savedAt': revision['savedAt'],
        'title': revision['title'],
      });
    }
    return result;
  }
}
