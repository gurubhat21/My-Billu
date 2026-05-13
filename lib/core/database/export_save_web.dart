import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Save file on web — triggers browser download
Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
  final jsArray = [bytes.toJS].toJS;
  final blob = web.Blob(jsArray, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  web.document.body?.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}


