/// Zerlegt den Text eines abfotografierten Rezepts in Name, Zutaten und
/// Zubereitung. Die Texterkennung liefert nur Zeilen, deshalb arbeitet das
/// mit einfachen Faustregeln; das Ergebnis wird vor dem Speichern geprüft.
class RecipeDraft {
  const RecipeDraft({
    required this.title,
    required this.ingredients,
    required this.instructions,
  });

  final String title;
  final List<String> ingredients;
  final String instructions;
}

final _ingredientsHeading = RegExp(
  r'^(zutaten|ingredients|einkaufsliste)\b',
  caseSensitive: false,
);
final _instructionsHeading = RegExp(
  r"^(zubereitung|anleitung|so geht'?s|so wird'?s gemacht|arbeitsschritte|instructions|directions|method)\b",
  caseSensitive: false,
);

const _units =
    r'(g|gr|kg|mg|ml|cl|dl|l|el|tl|esslöffel|teelöffel|stk|stück|prise|prisen|'
    r'pck|pkg|päckchen|packung|becher|dose|dosen|bund|zehe|zehen|tasse|tassen|'
    r'msp|scheibe|scheiben|glas|cup|cups|tbsp|tsp|oz)';
const _number = r'(\d+([.,/]\d+)?|\d*\s?[½¼¾⅓⅔]|ca\.?\s*\d+)';

/// Nur eine Menge, z. B. "200 g" oder "2 EL" (in Rezepten oft eigene Spalte).
final _quantityOnly = RegExp(
  '^$_number(\\s*-\\s*$_number)?\\s*($_units\\.?)?\$',
  caseSensitive: false,
);

/// Zeile beginnt mit einer Menge oder einem typischen Mengenwort.
final _startsLikeIngredient = RegExp(
  '^($_number|eine?\\s|etwas\\s|prise\\s|n\\.\\s?b\\.|salz|pfeffer)',
  caseSensitive: false,
);

final _bullet = RegExp(r'^[•·\-–*◦▪●o]\s+');
final _stepNumber = RegExp(r'^(\d+[.)]|schritt\s+\d+)\s*', caseSensitive: false);

RecipeDraft parseRecipeText(String text) {
  final lines = [
    for (final raw in text.split('\n'))
      if (raw.trim().isNotEmpty) raw.trim().replaceFirst(_bullet, ''),
  ];
  if (lines.isEmpty) {
    return const RecipeDraft(title: '', ingredients: [], instructions: '');
  }

  final ingIdx = lines.indexWhere(_isIngredientsHeading);
  final instIdx = lines.indexWhere(_isInstructionsHeading);

  // Name: erste Zeile, die keine Überschrift ist.
  final titleIdx = lines.indexWhere(
    (l) => !_isIngredientsHeading(l) && !_isInstructionsHeading(l),
  );
  final title = titleIdx == -1 ? '' : lines[titleIdx];

  List<String> ingredientLines;
  List<String> instructionLines;

  if (ingIdx != -1 && instIdx > ingIdx) {
    ingredientLines = lines.sublist(ingIdx + 1, instIdx);
    instructionLines = lines.sublist(instIdx + 1);
  } else if (instIdx != -1 && ingIdx > instIdx) {
    instructionLines = lines.sublist(instIdx + 1, ingIdx);
    ingredientLines = lines.sublist(ingIdx + 1);
  } else {
    // Ohne passende Überschriften: kurze Zeilen und Zeilen mit Mengen sind
    // Zutaten, ganze Sätze gehören zur Zubereitung.
    final start = ingIdx != -1
        ? ingIdx + 1
        : instIdx != -1
        ? instIdx + 1
        : titleIdx + 1;
    ingredientLines = [];
    instructionLines = [];
    for (final line in lines.skip(start)) {
      if (instIdx == -1 && _looksLikeIngredient(line)) {
        ingredientLines.add(line);
      } else {
        instructionLines.add(line);
      }
    }
  }

  return RecipeDraft(
    title: title,
    ingredients: _mergeQuantities(ingredientLines),
    instructions: _joinParagraphs(instructionLines),
  );
}

bool _isIngredientsHeading(String l) =>
    l.length <= 40 && _ingredientsHeading.hasMatch(l);
bool _isInstructionsHeading(String l) =>
    l.length <= 40 && _instructionsHeading.hasMatch(l);

bool _looksLikeIngredient(String l) =>
    !_stepNumber.hasMatch(l) &&
    l.length <= 50 &&
    (_startsLikeIngredient.hasMatch(l) ||
        (l.length <= 35 && !RegExp(r'[.!?]$').hasMatch(l)));

/// Fügt allein stehende Mengen mit der zugehörigen Zutat zusammen. Steht
/// erst eine Spalte Mengen und dann eine Spalte Zutaten da, werden beide
/// der Reihe nach gepaart.
List<String> _mergeQuantities(List<String> lines) {
  final result = <String>[];
  var i = 0;
  while (i < lines.length) {
    var q = i;
    while (q < lines.length && _quantityOnly.hasMatch(lines[q])) {
      q++;
    }
    final quantities = q - i;
    if (quantities == 0) {
      result.add(lines[i]);
      i++;
      continue;
    }
    var n = q;
    while (n < lines.length &&
        n - q < quantities &&
        !_quantityOnly.hasMatch(lines[n])) {
      n++;
    }
    final names = n - q;
    for (var k = 0; k < quantities; k++) {
      result.add(k < names ? '${lines[i + k]} ${lines[q + k]}' : lines[i + k]);
    }
    i = n;
  }
  return result;
}

/// Die Texterkennung bricht Sätze an jedem Zeilenende um. Zeilen werden
/// wieder zusammengefügt; ein neuer Absatz beginnt bei einer Schrittnummer
/// oder nach einem Satzende.
String _joinParagraphs(List<String> lines) {
  final paragraphs = <String>[];
  for (final line in lines) {
    final newStep = _stepNumber.hasMatch(line);
    final cleaned = line.replaceFirst(_stepNumber, '');
    if (cleaned.isEmpty) continue;
    if (paragraphs.isEmpty ||
        newStep ||
        RegExp(r'[.!?:]$').hasMatch(paragraphs.last)) {
      paragraphs.add(cleaned);
    } else if (paragraphs.last.endsWith('-')) {
      paragraphs.last =
          paragraphs.last.substring(0, paragraphs.last.length - 1) + cleaned;
    } else {
      paragraphs.last = '${paragraphs.last} $cleaned';
    }
  }
  return paragraphs.join('\n\n');
}
