import 'dart:convert';
import 'dart:js_interop';
import 'draft_repository.dart';

@JS('decDraftCall')
external JSPromise<JSString> _call(JSString method, JSString payload);

class DraftStore implements DraftRepository {
  Future<dynamic> _request(String method, dynamic payload) async => jsonDecode(
    (await _call(method.toJS, jsonEncode(payload).toJS).toDart).toDart,
  );
  @override
  Future<List<Map<String, dynamic>>> history() async =>
      (await _request('history', null) as List).cast<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> read(String id) async =>
      await _request('read', id) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> revision) async {
    await _request('save', revision);
  }
}
