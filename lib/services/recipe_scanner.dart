import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../util/recipe_parser.dart';

/// Fotografiert ein Rezept (oder nimmt ein Bild aus der Galerie) und liest den
/// Text direkt auf dem Handy aus. Ohne Internet, ohne Kosten. Gibt null zurück,
/// wenn kein Bild gewählt wurde. Läuft nur in der Android- und iOS-App.
Future<List<OcrLine>?> scanRecipeText(ImageSource source) async {
  final image = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2400,
    maxHeight: 2400,
  );
  if (image == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(image.path),
    );
    // Blockweise, damit Spalten (Mengen | Zutaten) zusammen bleiben. Die
    // Zeilenhöhe hilft, die große Überschrift als Namen zu finden.
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(line.text, height: line.boundingBox.height),
    ];
  } finally {
    await recognizer.close();
  }
}
