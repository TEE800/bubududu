import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> openBytes(Uint8List bytes, String name, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  if (tab == null) {
    // Popup blockiert: stattdessen herunterladen.
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = name
      ..click();
  }
}
