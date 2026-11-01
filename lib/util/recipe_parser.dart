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

  bool get isEmpty =>
      title.isEmpty && ingredients.isEmpty && instructions.isEmpty;
}

/// Eine erkannte Textzeile. [height] ist die Schrifthöhe in Pixeln (0, wenn
/// unbekannt); damit wird die große Überschrift als Name erkannt.
class OcrLine {
  const OcrLine(this.text, {this.height = 0});

  final String text;
  final double height;
}

final _ingredientsHeading = RegExp(
  r'^((haupt)?zutaten|ingredients|einkaufsliste|rezept\s+für\b|'
  r'für\s+\d+\s+(portionen|personen|stück)|\d+\s+(portionen|personen)\b)',
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

final _bullet = RegExp(r'^[•·\-–*◦▪●○■□☐◻✓✔o]\s*(?=\S)');
final _stepNumber = RegExp(
  r'^(\d+[.)]|schritt\s+\d+)\s*',
  caseSensitive: false,
);

// --- Störtext aus Screenshots und Webseiten --------------------------------

/// Uhrzeit oder Akkustand aus der Statusleiste, z. B. "08:45" oder "87 %".
final _statusBar = RegExp(
  r'^(\d{1,2}:\d{2}(\s*(uhr|am|pm))?|\d{1,3}\s?%)$',
  caseSensitive: false,
);

/// Bedienelemente von Instagram, Blogs usw.
const _uiWords = {
  'all posts',
  'posts',
  'post',
  'follow',
  'following',
  'folgen',
  'gefolgt',
  'abonnieren',
  'share',
  'teilen',
  'speichern',
  'save',
  'saved',
  'like',
  'likes',
  'gefällt mir',
  'kommentieren',
  'comment',
  'comments',
  'kommentare',
  'reply',
  'antworten',
  'more',
  'mehr',
  'mehr anzeigen',
  'see more',
  'see translation',
  'übersetzung anzeigen',
  'home',
  'startseite',
  'menu',
  'menü',
  'suche',
  'search',
  'back',
  'zurück',
  'instagram',
  'tiktok',
  'pinterest',
  'facebook',
  'youtube',
  'werbung',
  'anzeige',
  'gesponsert',
  'sponsored',
  'newsletter',
  'jump to recipe',
  'zum rezept',
  'rezept drucken',
  'print recipe',
  'drucken',
  'print',
  'reels',
  'stories',
  'markiert',
  'nachricht',
  'message',
  'original audio',
  'originalton',
};

final _uiPatterns = RegExp(
  r'^([@#]|https?://|www\.)|\.(com|de|at|ch)(/|$)|'
  r'^[\d.,]+\s?(k|tsd\.?|mio\.?)?\s+(likes?|gefällt|kommentare|comments|views|aufrufe|follower)|'
  r'^gefällt\s|^vor\s\d+\s(sek|min|std|stunden?|tag|tagen|woche|wochen)\b|'
  r'\b\d+\s(seconds?|minutes?|hours?|days?|weeks?)\sago$|'
  r'^(zubereitungszeit|vorbereitungszeit|arbeitszeit|kochzeit|backzeit|'
  r'ruhezeit|gesamtzeit|schwierigkeit|kalorien)\b',
  caseSensitive: false,
);

final _letter = RegExp(r'[A-Za-zÄÖÜäöüß]');
final _digitOrFraction = RegExp(r'[\d½¼¾⅓⅔]');

bool _isNoise(String l) {
  if (_statusBar.hasMatch(l)) return true;
  // Einzelne Buchstaben und Symbole (Icons, abgeschnittene Wörter).
  if (!_digitOrFraction.hasMatch(l) && _letter.allMatches(l).length < 2) {
    return true;
  }
  return _uiWords.contains(l.toLowerCase()) || _uiPatterns.hasMatch(l);
}

/// Zwischenüberschrift innerhalb der Zutaten, z. B. "MARINADE" oder
/// "Für die Soße:". Sie gehört nicht auf die Einkaufsliste.
bool _isSubHeading(String l, {required bool allowCaps}) {
  if (l.contains(_digitOrFraction) || l.length > 40) return false;
  if (l.endsWith(':')) return true;
  if (RegExp(r'^für\s+(den|die|das)\s', caseSensitive: false).hasMatch(l)) {
    return true;
  }
  return allowCaps && _isAllCaps(l);
}

bool _isAllCaps(String l) =>
    _letter.allMatches(l).length >= 3 && l == l.toUpperCase();

/// Typische Lesefehler der Texterkennung in Mengenangaben beheben.
String _cleanIngredient(String l) {
  var s = l;
  // Aufzählungszeichen oder Kästchen werden oft als einzelner Buchstabe
  // gelesen: "F 30 g Mehl", "S1TL Paprika", "R%TL Pfeffer".
  s = s.replaceFirst(RegExp(r'^[A-Za-z]\s?(?=[\d%½¼¾⅓⅔])'), '');
  // "½" wird gern als "%" erkannt ("%TL", "1%TL").
  s = s.replaceFirstMapped(
    RegExp(r'^(\d?)\s?%(?=\s?[A-Za-zÄÖÜäöü])'),
    (m) => '${m[1]}½',
  );
  // Leerzeichen zwischen Menge und Wort: "1Spitzkohl", "250g", "½TL".
  s = s.replaceFirstMapped(
    RegExp(r'^(\d+(?:[.,/]\d+)?[½¼¾⅓⅔]?|[½¼¾⅓⅔])(?=[A-WYZa-wyzÄÖÜäöüß])'),
    (m) => '${m[1]} ',
  );
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Fügt die Zeilen mehrerer Bilder eines Rezepts (z. B. Screenshots beim
/// Herunterscrollen) in Reihenfolge zusammen. Was ein Bild mit dem vorigen
/// doppelt zeigt, wird nur einmal übernommen, samt der Leiste oben im
/// Folgebild, die vor dem doppelten Stück steht.
List<OcrLine> mergeOcrPages(List<List<OcrLine>> pages) {
  final merged = <OcrLine>[];
  for (final page in pages) {
    final lines = [
      for (final l in page)
        if (l.text.trim().isNotEmpty && !_isNoise(l.text.trim())) l,
    ];
    if (merged.isEmpty) {
      merged.addAll(lines);
      continue;
    }
    final overlap = _findOverlap(merged, lines);
    if (overlap == null) {
      merged.addAll(lines);
    } else {
      merged.removeRange(overlap.prevEnd, merged.length);
      merged.addAll(lines.sublist(overlap.nextStart));
    }
  }
  return merged;
}

String _key(String t) =>
    t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß½¼¾⅓⅔]'), '');

/// Sucht das längste Stück, mit dem [next] (nahe am Anfang) das Ende von
/// [prev] wiederholt. Ergebnis: ab [prevEnd] wird [prev] abgeschnitten (dort
/// stand nur noch Leiste oder ein angeschnittener Rest, den [next] ganz
/// zeigt), ab [nextStart] geht es mit [next] weiter.
({int prevEnd, int nextStart})? _findOverlap(
  List<OcrLine> prev,
  List<OcrLine> next,
) {
  final p = [for (final l in prev) _key(l.text)];
  final n = [for (final l in next) _key(l.text)];
  ({int prevEnd, int nextStart})? best;
  var bestChars = 0;
  // Bis zu 4 Zeilen Leiste/Anschnitt am Ende von prev, bis zu 15 Zeilen
  // Kopfleiste am Anfang von next.
  for (var e = p.length; e >= p.length - 4 && e > 0; e--) {
    for (var s = 0; s < n.length && s < 15; s++) {
      final run = _runLength(p, n, e, s);
      if (run == 0) continue;
      var chars = 0;
      for (var i = 0; i < run; i++) {
        chars += n[s + i].length;
      }
      // Eine einzelne kurze Zeile wie "1 Ei" reicht nicht als Beweis.
      if ((run >= 2 || chars >= 20) && chars > bestChars) {
        bestChars = chars;
        best = (prevEnd: e, nextStart: s + run);
      }
    }
  }
  return best;
}

/// Länge k, für die p[e-k..e) == n[s..s+k) gilt (größtes k).
int _runLength(List<String> p, List<String> n, int e, int s) {
  final maxK = [e, n.length - s].reduce((a, b) => a < b ? a : b);
  for (var k = maxK; k > 0; k--) {
    var ok = true;
    for (var i = 0; i < k; i++) {
      if (p[e - k + i] != n[s + i] || p[e - k + i].isEmpty) {
        ok = false;
        break;
      }
    }
    if (ok) return k;
  }
  return 0;
}

RecipeDraft parseRecipeText(String text) =>
    parseRecipeLines([for (final l in text.split('\n')) OcrLine(l)]);

RecipeDraft parseRecipeLines(List<OcrLine> raw) {
  final lines = <OcrLine>[
    for (final r in raw)
      if (r.text.trim().replaceFirst(_bullet, '').trim() case final t
          when t.isNotEmpty && !_isNoise(t))
        OcrLine(t, height: r.height),
  ];
  if (lines.isEmpty) {
    return const RecipeDraft(title: '', ingredients: [], instructions: '');
  }
  final texts = [for (final l in lines) l.text];

  final ingIdx = texts.indexWhere(_isIngredientsHeading);
  final instIdx = texts.indexWhere(_isInstructionsHeading);

  // Alles vor der ersten Überschrift ist Kopfbereich mit dem Namen. Ohne
  // Überschriften endet er vor der ersten Zeile, die mit einer Menge beginnt.
  final headings = [ingIdx, instIdx].where((i) => i != -1);
  var headEnd = headings.isEmpty
      ? texts.length
      : headings.reduce((a, b) => a < b ? a : b);
  if (ingIdx == -1 && instIdx != 0) {
    final limit = instIdx == -1 ? texts.length : instIdx;
    final firstQty = texts.indexWhere(
      (l) => RegExp('^$_number').hasMatch(_cleanIngredient(l)),
      1,
    );
    headEnd = firstQty != -1 && firstQty < limit ? firstQty : 1;
  }
  final title = _pickTitle(lines.sublist(0, headEnd));

  List<String> ingredientLines;
  List<String> instructionLines;

  if (ingIdx != -1 && instIdx > ingIdx) {
    ingredientLines = texts.sublist(ingIdx + 1, instIdx);
    instructionLines = texts.sublist(instIdx + 1);
  } else if (instIdx != -1 && ingIdx > instIdx) {
    instructionLines = texts.sublist(instIdx + 1, ingIdx);
    ingredientLines = texts.sublist(ingIdx + 1);
  } else {
    // Ohne passende Überschriften: kurze Zeilen und Zeilen mit Mengen sind
    // Zutaten, ganze Sätze gehören zur Zubereitung.
    final start = ingIdx != -1 ? ingIdx + 1 : headEnd;
    final end = instIdx > start ? instIdx : texts.length;
    ingredientLines = [];
    instructionLines = [];
    for (final line in texts.sublist(start, end)) {
      if (_looksLikeIngredient(_cleanIngredient(line))) {
        ingredientLines.add(line);
      } else {
        instructionLines.add(line);
      }
    }
    if (instIdx != -1 && instIdx >= start) {
      instructionLines.addAll(texts.sublist(instIdx + 1));
    }
  }

  return RecipeDraft(
    title: title,
    ingredients: _mergeQuantities(_tidyIngredients(ingredientLines)),
    instructions: _joinParagraphs(
      instructionLines.where((l) => !_isInstructionsHeading(l)).toList(),
    ),
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

/// Name aus dem Kopfbereich: die Zeile mit der größten Schrift (samt
/// gleich großer Nachbarzeilen, falls der Name umbricht). Ohne Schrifthöhen
/// die erste Zeile, die wie ein Name aussieht.
String _pickTitle(List<OcrLine> head) {
  final candidates = [
    for (final l in head)
      if (!_quantityOnly.hasMatch(l.text) &&
          !RegExp(r'[.!?]$').hasMatch(l.text))
        l,
  ];
  if (candidates.isEmpty) {
    return head.isEmpty ? '' : head.first.text;
  }

  String tidy(String t) => t.replaceFirst(RegExp(r'\s*:$'), '');

  final maxHeight = candidates
      .map((l) => l.height)
      .reduce((a, b) => a > b ? a : b);
  if (maxHeight > 0) {
    final top = candidates.indexWhere((l) => l.height == maxHeight);
    bool big(int i) => candidates[i].height >= maxHeight * 0.8;
    var from = top, to = top;
    while (from > 0 && big(from - 1)) {
      from--;
    }
    while (to < candidates.length - 1 && big(to + 1)) {
      to++;
    }
    return tidy(candidates.sublist(from, to + 1).map((l) => l.text).join(' '));
  }
  final named = candidates.firstWhere(
    (l) => RegExp(r'^[A-ZÄÖÜ0-9]').hasMatch(l.text),
    orElse: () => candidates.first,
  );
  return tidy(named.text);
}

/// Überschriften entfernen und Lesefehler korrigieren.
List<String> _tidyIngredients(List<String> lines) {
  // Steht alles in Großbuchstaben, sind Großbuchstaben kein Zeichen für
  // eine Zwischenüberschrift.
  final caps = lines.where(_isAllCaps).length;
  final allowCaps = caps * 2 < lines.length;
  return [
    for (final l in lines)
      if (!_isIngredientsHeading(l) &&
          !_isInstructionsHeading(l) &&
          !_isSubHeading(l, allowCaps: allowCaps))
        _cleanIngredient(l),
  ];
}

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
