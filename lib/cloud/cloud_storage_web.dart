import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'cloud_models.dart';

@JS('decCloudCall')
external JSPromise<JSString> _call(
  JSString method,
  JSString args,
  JSUint8Array bytes,
);
@JS('decCloudRead')
external JSPromise<JSUint8Array> _read(JSString path);
@JS('decCloudSupported')
external bool get _supported;

class CloudStorage {
  String? folder;
  String? provider;
  String? mode;
  String? permission;
  bool get supported => _supported;
  bool get configured => mode != null;
  bool get connected => folder != null && permission == 'granted';
  Future<dynamic> _request(
    String method, [
    Map<String, dynamic> args = const {},
    Uint8List? bytes,
  ]) async => jsonDecode(
    (await _call(
      method.toJS,
      jsonEncode(args).toJS,
      (bytes ?? Uint8List(0)).toJS,
    ).toDart).toDart,
  );
  void _state(dynamic result) {
    folder = result?['folder'] as String?;
    provider = result?['provider'] as String?;
    mode = result?['mode'] as String?;
    permission = result?['permission'] as String?;
  }

  Future<void> restore() async {
    if (supported) _state(await _request('restore'));
  }

  Future<void> choose(String service) async {
    _state(await _request('choose', {'provider': service}));
  }

  Future<void> chooseLocal() async {
    _state(await _request('chooseLocal'));
  }

  Future<void> authorize() async {
    _state(await _request('authorize'));
  }

  Future<List<CloudFile>> list() async => ((await _request('list')) as List)
      .map((e) => CloudFile.fromJson(e as Map<String, dynamic>))
      .toList();
  Future<String> save(CloudDocument doc) async =>
      await _request('save', {
            'language': safeCloudSegment(doc.language, 'sans-langue'),
            'person': safeCloudSegment(doc.person, 'sans-personne'),
            'name': safeCloudSegment(
              doc.name.replaceFirst(
                RegExp(r'\.docx$', caseSensitive: false),
                '',
              ),
              'document',
            ),
          }, doc.bytes)
          as String;
  Future<Uint8List> read(String path) async =>
      (await _read(path.toJS).toDart).toDart;
  Future<void> disconnect() async {
    await _request('disconnect');
    folder = null;
    provider = null;
    mode = null;
    permission = null;
  }
}
