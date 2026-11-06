import 'package:http/http.dart' as http;

import 'dish_image.dart';

/// Wörter, die in Reisenamen oft stehen, aber keinen Ort nennen.
const _reiseWoerter = {
  'wochenende',
  'kurztrip',
  'kurzurlaub',
  'urlaub',
  'ausflug',
  'reise',
  'städtetrip',
  'staedtetrip',
  'roadtrip',
  'trip',
  'tour',
  'wandern',
  'wanderung',
  'radtour',
  'skiurlaub',
  'skifahren',
  'strand',
  'strandurlaub',
  'sommer',
  'sommerurlaub',
  'winter',
  'winterurlaub',
  'frühling',
  'herbst',
  'ostern',
  'pfingsten',
  'silvester',
  'weihnachten',
  'geburtstag',
  'jahrestag',
  'hochzeit',
  'flitterwochen',
  'besuch',
  'familie',
  'freunde',
  'unser',
  'unsere',
  'erster',
  'erste',
  'nach',
  'zum',
  'zur',
  'bei',
  'mit',
  'und',
  'ans',
  'auf',
  'den',
  'der',
  'die',
  'das',
  'ins',
};

/// Die Wörter eines Reisenamens, die einen Ort nennen könnten,
/// in ihrer Schreibweise und Reihenfolge.
List<String> placeWords(String name) => [
  for (final w in name.split(RegExp(r'[^A-Za-zÄÖÜäöüß\-]+')))
    if (w.length >= 3 && !_reiseWoerter.contains(w.toLowerCase())) w,
];

/// Suchbegriffe für das Bild eines Reiseziels, vom genauesten zum gröbsten:
/// der gesuchte Ort (ohne Bundesland und Land), der Name ohne Reisewörter,
/// dann jedes Wort einzeln, das längste zuerst.
List<String> placeQueries(String name, {String? place}) {
  final words = placeWords(name);
  final single = [...words]..sort((a, b) => b.length.compareTo(a.length));
  final queries = <String, String>{};
  for (final q in [
    if (place != null) place.split(',').first.trim(),
    words.join(' '),
    ...single,
  ]) {
    if (q.isNotEmpty) queries.putIfAbsent(q.toLowerCase(), () => q);
  }
  return queries.values.toList();
}

/// Passt der Artikel zum Suchbegriff? Ein Wort muss in beiden vorkommen
/// ("Sylt" passt zu "Sylt", "Rom" zu "Rom", aber nicht zu "Roman").
bool placeMatches(String query, String article) {
  final a = article.toLowerCase().split(RegExp(r'[^a-zäöüß]+')).toSet();
  return query
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüß]+'))
      .where((w) => w.length >= 3)
      .any(a.contains);
}

/// Sucht ein frei lizenziertes Foto des Reiseziels in der Wikipedia.
Future<DishImage?> fetchPlaceImage(
  http.Client client,
  String name, {
  String? place,
}) async {
  for (final query in placeQueries(name, place: place)) {
    final hit = await findWikiImage(
      client,
      query,
      matches: (article) => placeMatches(query, article),
    );
    if (hit != null) return hit;
  }
  return null;
}
