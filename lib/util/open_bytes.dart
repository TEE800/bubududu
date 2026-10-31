import 'dart:typed_data';

import 'open_bytes/open_bytes_io.dart'
    if (dart.library.js_interop) 'open_bytes/open_bytes_web.dart'
    as impl;

/// Öffnet eine Datei (z. B. ein PDF) in der passenden App des Geräts,
/// im Browser in einem neuen Tab.
Future<void> openBytes(Uint8List bytes, String name, String mime) =>
    impl.openBytes(bytes, name, mime);
