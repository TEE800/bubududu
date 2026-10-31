import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Der Text aller Seiten eines PDFs, Seiten durch Zeilenumbrüche getrennt.
Future<String> pdfText(Uint8List bytes) async {
  await pdfrxFlutterInitialize();
  final doc = await PdfDocument.openData(bytes);
  try {
    final pages = <String>[];
    for (final page in doc.pages) {
      pages.add((await page.loadText())?.fullText ?? '');
    }
    return pages.join('\n');
  } finally {
    await doc.dispose();
  }
}
