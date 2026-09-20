import 'dart:js_interop';
import 'dart:typed_data';

@JS('decExtractPdfText')
external JSPromise<JSString> _extractPdf(JSUint8Array bytes);

Future<String> extractWebPdfText(Uint8List bytes) async =>
    (await _extractPdf(bytes.toJS).toDart).toDart;
