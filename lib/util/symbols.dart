/// Passende Symbole für die Bildkacheln, wenn es kein Foto gibt. Gesucht
/// wird nach Wortteilen im Namen, der erste Treffer gewinnt.
typedef SymbolTable = List<(List<String>, String)>;

String symbolFor(String text, SymbolTable table, String fallback) {
  final t = text.toLowerCase();
  for (final (keys, symbol) in table) {
    for (final k in keys) {
      if (t.contains(k)) return symbol;
    }
  }
  return fallback;
}

/// Verträge und Abos.
const contractSymbols = <(List<String>, String)>[
  (['miete', 'wohnung', 'nebenkosten', 'hausgeld'], '🏠'),
  (['strom', 'energie', 'ökostrom'], '⚡'),
  (['gas', 'heiz', 'fernwärme'], '🔥'),
  (['wasser'], '💧'),
  (['internet', 'dsl', 'glasfaser', 'wlan', 'vodafone', 'telekom', 'o2'], '🌐'),
  (['handy', 'mobil', 'telefon', 'smartphone'], '📱'),
  (['netflix', 'disney', 'prime video', 'wow', 'sky', 'dazn', 'joyn'], '🎬'),
  (['spotify', 'musik', 'apple music', 'deezer', 'audible'], '🎵'),
  (['amazon', 'prime'], '📦'),
  (['rundfunk', 'gez', 'tv', 'fernseh'], '📺'),
  (['fitness', 'gym', 'sport', 'urban sports', 'verein'], '🏋️'),
  (['auto', 'kfz', 'leasing', 'tank', 'parkplatz', 'garage'], '🚗'),
  (['bahn', 'deutschlandticket', 'ticket', 'öpnv', 'bvg', 'mvv', 'hvv'], '🚆'),
  (['kranken', 'zahn', 'pflege'], '🩺'),
  (['haftpflicht', 'hausrat', 'versicherung', 'rechtsschutz'], '🛡️'),
  (['kredit', 'darlehen', 'bank', 'konto', 'karte', 'spar', 'etf'], '🏦'),
  (['cloud', 'icloud', 'google one', 'dropbox', 'software', 'office'], '☁️'),
  (['zeitung', 'zeitschrift', 'magazin', 'abo'], '📰'),
  (['spiel', 'playstation', 'xbox', 'nintendo', 'steam', 'game'], '🎮'),
  (['tier', 'hund', 'katze'], '🐾'),
  (['spende'], '💚'),
];

/// Haushaltsaufgaben.
const taskSymbols = <(List<String>, String)>[
  (['müll', 'abfall', 'tonne', 'gelber sack', 'altglas', 'papier'], '🗑️'),
  (['wäsche', 'waschen', 'bügeln', 'bettwäsche'], '🧺'),
  (['spül', 'abwasch', 'geschirr'], '🍽️'),
  (['saug', 'staub'], '🧹'),
  (['wisch', 'boden'], '🧽'),
  (['bad', 'toilette', 'klo', 'dusche'], '🛁'),
  (['fenster'], '🪟'),
  (['küche', 'kühlschrank', 'backofen', 'herd'], '🍳'),
  (['einkauf', 'einkaufen'], '🛒'),
  (['kochen', 'essen'], '🥘'),
  (['gieß', 'pflanze', 'blume', 'garten', 'rasen'], '🪴'),
  (['bett'], '🛏️'),
  (['aufräumen', 'ordnung', 'sortieren'], '📦'),
  (['auto', 'reifen', 'tanken'], '🚗'),
  (['rechnung', 'überweis', 'steuer', 'bezahlen'], '🧾'),
  (['reparier', 'werkzeug', 'bohren', 'lampe', 'glühbirne'], '🔧'),
  (['katze', 'hund', 'tier', 'füttern', 'katzenklo'], '🐾'),
  (['anrufen', 'termin'], '📞'),
  (['putz'], '🧼'),
];

/// Kategorien und Titel bei den Finanzen.
const expenseSymbols = <(List<String>, String)>[
  (['ausgleich'], '🤝'),
  (
    [
      'lebensmittel',
      'rewe',
      'edeka',
      'aldi',
      'lidl',
      'penny',
      'netto',
      'supermarkt',
    ],
    '🛒',
  ),
  (
    [
      'restaurant',
      'pizza',
      'sushi',
      'döner',
      'burger',
      'essen',
      'café',
      'cafe',
    ],
    '🍝',
  ),
  (['haushalt', 'drogerie', 'dm', 'rossmann'], '🧴'),
  (['wohnen', 'miete', 'möbel', 'ikea'], '🛋️'),
  (['reise', 'urlaub', 'hotel', 'flug', 'bahn'], '✈️'),
  (['geschenk'], '🎁'),
  (['freizeit', 'kino', 'konzert', 'museum', 'bar'], '🎉'),
  (['tank', 'benzin', 'auto'], '⛽'),
  (['apotheke', 'arzt'], '💊'),
  (['kleidung', 'schuhe'], '👕'),
];

/// Kategorien der Notizen.
const noteSymbols = <(List<String>, String)>[
  (['wlan', 'passwort', 'pin'], '🔑'),
  (['wichtig'], '❗'),
  (['geschenk'], '🎁'),
  (['kontakt', 'nummer', 'telefon', 'handwerker'], '📞'),
  (['größe', 'maße'], '📏'),
  (['rezept', 'essen'], '🍳'),
];

/// Termine im Kalender.
const eventSymbols = <(List<String>, String)>[
  (['geburtstag', 'bday'], '🎂'),
  (['jahrestag', 'hochzeit', 'kennenlern', 'date'], '💞'),
  (['arzt', 'zahnarzt', 'termin beim', 'praxis', 'impf'], '🩺'),
  (['friseur', 'haare'], '💇'),
  (['urlaub', 'reise', 'flug', 'zug'], '✈️'),
  (['essen', 'restaurant', 'brunch', 'frühstück', 'dinner'], '🍽️'),
  (['party', 'feier', 'fest'], '🎉'),
  (['konzert', 'kino', 'theater', 'musical'], '🎭'),
  (['sport', 'training', 'gym', 'fußball', 'laufen'], '🏃'),
  (['arbeit', 'meeting', 'büro'], '💼'),
  (['handwerker', 'reparatur'], '🔧'),
  (['müll', 'abfuhr'], '🗑️'),
];

/// Date-Ideen, Bucket-Liste und Ziele.
const ideaSymbols = <(List<String>, String)>[
  (['picknick'], '🧺'),
  (['kino', 'film'], '🎬'),
  (['kochen', 'backen'], '👩‍🍳'),
  (['essen', 'restaurant', 'brunch', 'sushi', 'pizza'], '🍝'),
  (['polarlicht', 'nordlicht', 'sterne'], '🌌'),
  (['meer', 'strand', 'insel'], '🏖️'),
  (['berg', 'wandern', 'alpen'], '🏔️'),
  (['ski', 'snowboard'], '⛷️'),
  (['konzert', 'festival'], '🎶'),
  (['museum', 'ausstellung'], '🖼️'),
  (['spar', '€', 'euro', 'geld'], '🐷'),
  (['sport', 'lauf', 'marathon', 'fit'], '🏃'),
  (['reise', 'urlaub', 'fliegen', 'flug', 'japan', 'italien', 'usa'], '✈️'),
  (['wohnung', 'haus', 'umzug'], '🏡'),
  (['hund', 'katze', 'tier'], '🐾'),
  (['wellness', 'sauna', 'therme'], '🧖'),
  (['tanz'], '💃'),
  (['spiel', 'brettspiel'], '🎲'),
];
