import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('decOfficeBridgeActive')
external JSBoolean get _bridgeActive;

@JS('decOfficeReceiveSelection')
external JSPromise<JSString> _receiveSelection();

@JS('decOfficeSendDocx')
external JSPromise<JSString> _sendDocx(JSString base64, JSString fileName);

class OfficeBridge {
  bool get active => _bridgeActive.toDart;

  Future<String> receiveSelection() async =>
      (await _receiveSelection().toDart).toDart;

  Future<String> sendDocument(Uint8List bytes, String fileName) async =>
      (await _sendDocx(base64Encode(bytes).toJS, fileName.toJS).toDart).toDart;
}
