import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Fotografiert ein Rezept (oder nimmt ein Bild aus der Galerie) und liest den
/// Text direkt auf dem Handy aus. Ohne Internet, ohne Kosten. Gibt null zurück,
/// wenn kein Bild gewählt wurde. Läuft nur in der Android- und iOS-App.
Future<String?> scanRecipeText(ImageSource source) async {
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
    // Blockweise, damit Spalten (Mengen | Zutaten) zusammen bleiben.
    return result.blocks.map((b) => b.text).join('\n');
  } finally {
    await recognizer.close();
  }
}
