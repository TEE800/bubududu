// Rendert die Figuren als Bilder: Vorschau aller Stimmungen und das App-Logo.
// Aufruf: flutter test tool/render_mascots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bubududu/widgets/mascots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _save(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

ui.Image _paint(Size size, void Function(Canvas) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording().toImageSync(
    size.width.round(),
    size.height.round(),
  );
}

/// Logo: beide Figuren auf dunkelgrünem Grund. [padding] lässt Rand für
/// runde/adaptive Icons, [background] false = transparent (Vordergrund-Ebene).
ui.Image logo(double px, {double padding = 0.08, bool background = true}) {
  return _paint(Size(px, px), (canvas) {
    if (background) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, px, px),
        Paint()..color = MascotPainter.green,
      );
    }
    // Die Figuren füllen etwa x 25–175 und y 0–130 im 200 × 130-Raster.
    final inner = px * (1 - 2 * padding);
    final scale = inner / 150;
    canvas
      ..translate(px / 2 - 100 * scale, px / 2 - 65 * scale)
      ..scale(scale);
    MascotPainter(mood: MascotMood.love)
        .paint(canvas, const Size(MascotPainter.width, MascotPainter.height));
  });
}

void main() {
  test('Figuren rendern', () async {
    final out = Platform.environment['OUT'] ?? 'build/mascots';
    for (final mood in MascotMood.values) {
      final img = _paint(const Size(400, 260), (canvas) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 400, 260),
          Paint()..color = const Color(0xFFF1F8E9),
        );
        MascotPainter(mood: mood).paint(canvas, const Size(400, 260));
      });
      await _save(img, '$out/${mood.name}.png');
    }
    await _save(logo(1024), '$out/logo.png');
    await _save(
      logo(1024, padding: 0.12, background: false),
      '$out/logo_foreground.png',
    );
  });
}
