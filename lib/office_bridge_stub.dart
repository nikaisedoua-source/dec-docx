import 'dart:typed_data';

class OfficeBridge {
  bool get active => false;

  Future<String> receiveSelection() async => '';

  Future<String> sendDocument(Uint8List bytes, String fileName) async =>
      'unavailable';
}
