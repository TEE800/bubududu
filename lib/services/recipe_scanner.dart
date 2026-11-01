import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../util/recipe_parser.dart';

const _maxSize = 2400.0;

/// Ein Foto aufnehmen. Gibt null zurück, wenn abgebrochen wurde.
Future<XFile?> takeRecipePhoto() => ImagePicker().pickImage(
  source: ImageSource.camera,
  maxWidth: _maxSize,
  maxHeight: _maxSize,
);

/// Ein oder mehrere Bilder aus der Galerie, in der Reihenfolge der Auswahl.
Future<List<XFile>> pickRecipeImages() =>
    ImagePicker().pickMultiImage(maxWidth: _maxSize, maxHeight: _maxSize);

/// Liest den Text aller Bilder direkt auf dem Handy aus (ohne Internet, ohne
/// Kosten) und fügt sie zu einem Rezept zusammen. Läuft nur in der Android-
/// und iOS-App.
Future<List<OcrLine>> scanRecipeImages(List<XFile> images) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final pages = <List<OcrLine>>[];
    for (final image in images) {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      // Blockweise, damit Spalten (Mengen | Zutaten) zusammen bleiben. Die
      // Zeilenhöhe hilft, die große Überschrift als Namen zu finden.
      pages.add([
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text, height: line.boundingBox.height),
      ]);
    }
    return mergeOcrPages(pages);
  } finally {
    await recognizer.close();
  }
}
