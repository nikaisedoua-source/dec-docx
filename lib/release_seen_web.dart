import 'dart:js_interop';

@JS('localStorage.getItem')
external JSString? _getItem(JSString key);
@JS('localStorage.setItem')
external void _setItem(JSString key, JSString value);

Future<bool> markReleaseSeen(String version) async {
  try {
    final key = 'dec-docx-last-seen-release'.toJS;
    if (_getItem(key)?.toDart == version) return false;
    _setItem(key, version.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
