/// Pflegetipps für häufige Zimmer- und Balkonpflanzen, nach Gattung.
/// Damit füllt die Pflanzenerkennung das Profil vor. Alles nur Richtwerte.
class PlantCareHint {
  const PlantCareHint({
    required this.intervalDays,
    required this.light,
    required this.waterNote,
    this.fertilizeDays = 14,
    this.fertilizeNote = 'Grünpflanzendünger, März bis September',
  });

  final int intervalDays;

  /// Einer der Werte aus plantLights (Sonnig, Hell, Halbschatten, Schattig).
  final String light;
  final String waterNote;

  /// 0 = nicht düngen.
  final int fertilizeDays;
  final String fertilizeNote;
}

const _sukkulente = PlantCareHint(
  intervalDays: 14,
  light: 'Sonnig',
  waterNote:
      'Erde komplett austrocknen lassen, dann durchdringend gießen. '
      'Im Winter kaum gießen.',
  fertilizeDays: 30,
  fertilizeNote: 'Kakteendünger, April bis August',
);

const _kaktus = PlantCareHint(
  intervalDays: 21,
  light: 'Sonnig',
  waterNote:
      'Nur gießen, wenn die Erde ganz trocken ist. '
      'Im Winter fast gar nicht.',
  fertilizeDays: 30,
  fertilizeNote: 'Kakteendünger, April bis August',
);

const _aronstab = PlantCareHint(
  intervalDays: 7,
  light: 'Hell',
  waterNote:
      'Obere Erdschicht antrocknen lassen, keine Staunässe. '
      'Blätter ab und zu besprühen.',
);

const _farn = PlantCareHint(
  intervalDays: 3,
  light: 'Halbschatten',
  waterNote:
      'Erde gleichmäßig feucht halten, nie austrocknen lassen. '
      'Mag hohe Luftfeuchtigkeit.',
  fertilizeDays: 30,
  fertilizeNote: 'Schwach dosierter Grünpflanzendünger, April bis September',
);

const _kraut = PlantCareHint(
  intervalDays: 2,
  light: 'Sonnig',
  waterNote: 'Erde feucht halten, morgens gießen, nicht über die Blätter.',
  fertilizeDays: 14,
  fertilizeNote: 'Kräuter- oder Biodünger, nur sparsam',
);

const _mediterran = PlantCareHint(
  intervalDays: 5,
  light: 'Sonnig',
  waterNote: 'Zwischendurch antrocknen lassen, verträgt keine Staunässe.',
  fertilizeDays: 30,
  fertilizeNote: 'Kräuterdünger, nur sparsam',
);

const _balkon = PlantCareHint(
  intervalDays: 2,
  light: 'Sonnig',
  waterNote:
      'Im Sommer täglich prüfen, an heißen Tagen morgens und abends gießen.',
  fertilizeDays: 7,
  fertilizeNote: 'Blühpflanzendünger, Mai bis September',
);

const _orchidee = PlantCareHint(
  intervalDays: 7,
  light: 'Hell',
  waterNote:
      'Einmal pro Woche 10 Minuten tauchen, gut abtropfen lassen. '
      'Kein Wasser im Übertopf stehen lassen.',
  fertilizeDays: 14,
  fertilizeNote: 'Orchideendünger, schwach dosiert',
);

const Map<String, PlantCareHint> _byGenus = {
  // Aronstabgewächse und andere Grünpflanzen
  'monstera': _aronstab,
  'philodendron': _aronstab,
  'epipremnum': PlantCareHint(
    intervalDays: 7,
    light: 'Halbschatten',
    waterNote: 'Erde antrocknen lassen, dann gießen. Hängende Blätter = Durst.',
  ),
  'scindapsus': _aronstab,
  'syngonium': _aronstab,
  'alocasia': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, keine Staunässe, hohe Luftfeuchtigkeit.',
  ),
  'anthurium': PlantCareHint(
    intervalDays: 7,
    light: 'Hell',
    waterNote:
        'Obere Erde antrocknen lassen, kalkarmes Wasser, gern besprühen.',
    fertilizeNote: 'Blühpflanzendünger, März bis September',
  ),
  'spathiphyllum': PlantCareHint(
    intervalDays: 5,
    light: 'Halbschatten',
    waterNote:
        'Erde feucht halten. Lässt die Blätter hängen, wenn sie Durst hat.',
  ),
  'zamioculcas': PlantCareHint(
    intervalDays: 21,
    light: 'Halbschatten',
    waterNote: 'Speichert Wasser in den Knollen: erst gießen, wenn die Erde ganz trocken ist.',
    fertilizeDays: 30,
  ),
  'dieffenbachia': _aronstab,
  'aglaonema': PlantCareHint(
    intervalDays: 7,
    light: 'Halbschatten',
    waterNote: 'Leicht feucht halten, zwischendurch antrocknen lassen.',
  ),
  'calathea': PlantCareHint(
    intervalDays: 5,
    light: 'Halbschatten',
    waterNote: 'Gleichmäßig feucht mit kalkarmem Wasser, keine pralle Sonne.',
  ),
  'goeppertia': PlantCareHint(
    intervalDays: 5,
    light: 'Halbschatten',
    waterNote: 'Gleichmäßig feucht mit kalkarmem Wasser, keine pralle Sonne.',
  ),
  'maranta': PlantCareHint(
    intervalDays: 5,
    light: 'Halbschatten',
    waterNote: 'Gleichmäßig feucht, kalkarmes Wasser, gern besprühen.',
  ),
  'ficus': PlantCareHint(
    intervalDays: 7,
    light: 'Hell',
    waterNote: 'Obere Erde antrocknen lassen. Mag keinen Standortwechsel und keine Zugluft.',
  ),
  'dracaena': PlantCareHint(
    intervalDays: 10,
    light: 'Hell',
    waterNote: 'Erde zur Hälfte abtrocknen lassen, keine Staunässe.',
  ),
  'sansevieria': PlantCareHint(
    intervalDays: 21,
    light: 'Hell',
    waterNote: 'Sehr sparsam: erst gießen, wenn die Erde ganz trocken ist.',
    fertilizeDays: 30,
  ),
  'yucca': PlantCareHint(
    intervalDays: 10,
    light: 'Sonnig',
    waterNote: 'Antrocknen lassen, im Winter wenig gießen.',
    fertilizeDays: 30,
  ),
  'chlorophytum': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, verzeiht auch mal Trockenheit.',
  ),
  'pilea': PlantCareHint(
    intervalDays: 7,
    light: 'Hell',
    waterNote: 'Antrocknen lassen, dann gießen. Ab und zu drehen, damit sie gerade wächst.',
    fertilizeDays: 30,
  ),
  'peperomia': PlantCareHint(
    intervalDays: 10,
    light: 'Hell',
    waterNote: 'Dicke Blätter speichern Wasser: Erde antrocknen lassen.',
    fertilizeDays: 30,
  ),
  'hoya': PlantCareHint(
    intervalDays: 10,
    light: 'Hell',
    waterNote:
        'Antrocknen lassen. Blüten nicht abschneiden, sie kommen wieder.',
    fertilizeDays: 30,
  ),
  'tradescantia': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, nicht nass.',
  ),
  'schefflera': PlantCareHint(
    intervalDays: 7,
    light: 'Hell',
    waterNote: 'Obere Erde antrocknen lassen.',
  ),
  'strelitzia': PlantCareHint(
    intervalDays: 7,
    light: 'Sonnig',
    waterNote: 'Im Sommer reichlich, im Winter sparsam gießen.',
  ),
  'begonia': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, nicht über die Blätter gießen.',
    fertilizeNote: 'Blühpflanzendünger, März bis September',
  ),
  'hedera': PlantCareHint(
    intervalDays: 7,
    light: 'Halbschatten',
    waterNote: 'Leicht feucht halten, mag es eher kühl.',
  ),
  'ctenanthe': PlantCareHint(
    intervalDays: 5,
    light: 'Halbschatten',
    waterNote: 'Gleichmäßig feucht mit kalkarmem Wasser.',
  ),
  // Palmen
  'chamaedorea': PlantCareHint(
    intervalDays: 7,
    light: 'Halbschatten',
    waterNote: 'Leicht feucht halten, gern besprühen.',
  ),
  'dypsis': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Gleichmäßig feucht, keine Staunässe, gern besprühen.',
  ),
  'howea': PlantCareHint(
    intervalDays: 7,
    light: 'Halbschatten',
    waterNote: 'Leicht feucht halten.',
  ),
  // Farne
  'nephrolepis': _farn,
  'asplenium': _farn,
  'adiantum': _farn,
  'platycerium': _farn,
  // Sukkulenten und Kakteen
  'aloe': _sukkulente,
  'echeveria': _sukkulente,
  'crassula': _sukkulente,
  'haworthia': _sukkulente,
  'haworthiopsis': _sukkulente,
  'kalanchoe': _sukkulente,
  'sedum': _sukkulente,
  'senecio': _sukkulente,
  'curio': _sukkulente,
  'euphorbia': _sukkulente,
  'opuntia': _kaktus,
  'mammillaria': _kaktus,
  'echinocactus': _kaktus,
  'cereus': _kaktus,
  'schlumbergera': PlantCareHint(
    intervalDays: 7,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, während der Blüte nicht umstellen.',
    fertilizeDays: 30,
  ),
  // Blühpflanzen
  'phalaenopsis': _orchidee,
  'dendrobium': _orchidee,
  'orchis': _orchidee,
  'saintpaulia': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Von unten gießen, Blätter nicht nass machen.',
    fertilizeNote: 'Blühpflanzendünger, schwach dosiert',
  ),
  'streptocarpus': PlantCareHint(
    intervalDays: 5,
    light: 'Hell',
    waterNote: 'Leicht feucht halten, von unten gießen.',
    fertilizeNote: 'Blühpflanzendünger, schwach dosiert',
  ),
  'cyclamen': PlantCareHint(
    intervalDays: 4,
    light: 'Hell',
    waterNote: 'Von unten gießen, mag es kühl.',
    fertilizeNote: 'Blühpflanzendünger, während der Blüte',
  ),
  'hibiscus': PlantCareHint(
    intervalDays: 3,
    light: 'Sonnig',
    waterNote: 'Im Sommer reichlich gießen, Ballen nie austrocknen lassen.',
    fertilizeDays: 7,
    fertilizeNote: 'Blühpflanzendünger, März bis September',
  ),
  'rosa': PlantCareHint(
    intervalDays: 3,
    light: 'Sonnig',
    waterNote: 'Morgens an die Wurzel gießen, nicht über die Blätter.',
    fertilizeDays: 21,
    fertilizeNote: 'Rosendünger, März bis Juli',
  ),
  'pelargonium': _balkon,
  'petunia': _balkon,
  'calibrachoa': _balkon,
  'fuchsia': _balkon,
  'bougainvillea': _balkon,
  // Kräuter und Mediterranes
  'ocimum': _kraut,
  'petroselinum': _kraut,
  'mentha': _kraut,
  'allium': _kraut,
  'coriandrum': _kraut,
  'rosmarinus': _mediterran,
  'salvia': _mediterran,
  'thymus': _mediterran,
  'lavandula': _mediterran,
  'origanum': _mediterran,
  'olea': _mediterran,
  'citrus': PlantCareHint(
    intervalDays: 4,
    light: 'Sonnig',
    waterNote:
        'Antrocknen lassen, dann durchdringend gießen, kalkarmes Wasser.',
    fertilizeDays: 7,
    fertilizeNote: 'Zitrusdünger, März bis September',
  ),
  'solanum': PlantCareHint(
    intervalDays: 1,
    light: 'Sonnig',
    waterNote: 'Täglich an die Wurzel gießen, Blätter trocken halten.',
    fertilizeDays: 7,
    fertilizeNote: 'Tomatendünger ab der ersten Blüte',
  ),
  'capsicum': PlantCareHint(
    intervalDays: 2,
    light: 'Sonnig',
    waterNote: 'Gleichmäßig feucht halten, keine Staunässe.',
    fertilizeDays: 14,
    fertilizeNote: 'Tomatendünger ab der ersten Blüte',
  ),
};

/// Pflegetipps zur Gattung (oder zum ersten Wort des wissenschaftlichen Namens).
PlantCareHint? careHintFor(String genusOrSpecies) {
  final genus = genusOrSpecies.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return _byGenus[genus];
}
