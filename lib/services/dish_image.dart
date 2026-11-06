import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ein frei lizenziertes Bild eines Gerichts aus der deutschen Wikipedia.
class DishImage {
  const DishImage({required this.url, required this.page});

  /// Direkter Link aufs Bild (etwa 800 px breit).
  final String url;

  /// Der Wikipedia-Artikel, aus dem das Bild stammt (für die Bildquelle).
  final String page;
}

/// Wörter, die in Rezeptnamen oft stehen, aber nichts über das Gericht sagen.
const _fuellwoerter = {
  'omas',
  'opas',
  'mamas',
  'papas',
  'bubus',
  'dudus',
  'unser',
  'unsere',
  'unseren',
  'meine',
  'meiner',
  'einfach',
  'einfache',
  'einfacher',
  'einfaches',
  'schnell',
  'schnelle',
  'schneller',
  'schnelles',
  'beste',
  'bester',
  'bestes',
  'leckere',
  'leckerer',
  'leckeres',
  'klassisch',
  'klassische',
  'klassischer',
  'klassisches',
  'vegan',
  'vegane',
  'veganer',
  'veganes',
  'vegetarisch',
  'vegetarische',
  'vegetarischer',
  'vegetarisches',
  'rezept',
  'nach',
  'art',
  'style',
  'with',
};

/// Die aussagekräftigen Wörter eines Rezeptnamens, längste zuerst.
List<String> dishWords(String title) {
  final words = title
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüß]+'))
      .where((w) => w.length >= 4 && !_fuellwoerter.contains(w))
      .toSet()
      .toList();
  words.sort((a, b) => b.length.compareTo(a.length));
  return words;
}

/// Passt der Artikel [article] zum Rezept [title]? Ein aussagekräftiges Wort
/// muss in beiden vorkommen, eins darf das andere verlängern
/// ("Pfannkuchen" passt zu "Pfannkuchens", "Kartoffelsalat" zu "Kartoffel").
bool dishMatches(String title, String article) {
  final a = dishWords(title);
  final b = dishWords(article);
  return a.any((x) => b.any((y) => x.startsWith(y) || y.startsWith(x)));
}

/// Suchbegriffe vom genauesten zum gröbsten: der ganze Name, der Name ohne
/// Füllwörter und ohne "mit …", zuletzt das längste einzelne Wort.
List<String> dishQueries(String title) {
  final clean = title.trim();
  final words = dishWords(clean);
  final main = clean
      .split(
        RegExp(
          r'\s+(mit|und|an|auf|in|à la|a la|nach)\s+',
          caseSensitive: false,
        ),
      )
      .first
      .split(RegExp(r'\s+'))
      .where((w) => !_fuellwoerter.contains(w.toLowerCase()))
      .join(' ');
  final queries = <String, String>{};
  for (final q in [
    clean,
    main,
    if (words.isNotEmpty)
      words.first[0].toUpperCase() + words.first.substring(1),
  ]) {
    if (q.isNotEmpty) queries.putIfAbsent(q.toLowerCase(), () => q);
  }
  return queries.values.toList();
}

/// Sucht ein Bild zum Gericht [title]. Zuerst der genaue Artikel (mit
/// Weiterleitungen), dann eine Suche, deren Treffer aber zum Namen passen
/// muss. Nur frei lizenzierte Bilder. Nichts Passendes: null.
Future<DishImage?> fetchDishImage(http.Client client, String title) async {
  for (final query in dishQueries(title)) {
    final hit = await findWikiImage(
      client,
      query,
      matches: (article) => dishMatches(title, article),
    );
    if (hit != null) return hit;
  }
  return null;
}

/// Ein frei lizenziertes Bild zum Begriff [query]: zuerst der genaue Artikel
/// (mit Weiterleitungen), dann eine Suche, deren Treffer [matches] erfüllen
/// muss. Begriffsklärungen zählen nicht. Nichts Passendes: null.
Future<DishImage?> findWikiImage(
  http.Client client,
  String query, {
  required bool Function(String article) matches,
}) async {
  const base = {
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'origin': '*',
    'prop': 'pageimages|info|pageprops',
    'ppprop': 'disambiguation',
    'piprop': 'thumbnail',
    'pithumbsize': '800',
    'pilicense': 'free',
    'inprop': 'url',
    'redirects': '1',
  };
  final exact = await _query(client, {...base, 'titles': query});
  if (exact != null) return exact;
  return _query(client, {
    ...base,
    'generator': 'search',
    'gsrsearch': query,
    'gsrlimit': '5',
  }, matches: matches);
}

Future<DishImage?> _query(
  http.Client client,
  Map<String, String> params, {
  bool Function(String article)? matches,
}) async {
  final uri = Uri.https('de.wikipedia.org', '/w/api.php', params);
  final res = await client.get(
    uri,
    headers: {'Api-User-Agent': 'BubuDudu-App'},
  );
  if (res.statusCode != 200) return null;
  final pages = [
    for (final p in (jsonDecode(res.body)['query']?['pages'] as List?) ?? [])
      if (p is Map) p,
  ]..sort((a, b) => _index(a).compareTo(_index(b)));
  for (final p in pages) {
    if (p['missing'] == true || p['invalid'] == true) continue;
    if ((p['pageprops'] as Map?)?.containsKey('disambiguation') ?? false) {
      continue;
    }
    final source = (p['thumbnail'] as Map?)?['source'];
    if (source is! String || source.isEmpty) continue;
    final title = p['title'] as String? ?? '';
    if (matches != null && !matches(title)) continue;
    return DishImage(
      url: source,
      page:
          p['fullurl'] as String? ??
          'https://de.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
    );
  }
  return null;
}

/// Reihenfolge der Suchtreffer (bei einer genauen Abfrage gibt es keine).
num _index(Map p) => (p['index'] as num?) ?? 0;
