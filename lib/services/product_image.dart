import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ein frei lizenziertes Bild zu einem Produkt aus der deutschen Wikipedia.
class ProductImage {
  const ProductImage({required this.url, required this.page});

  /// Direkter Link aufs Bild (etwa 400 px breit).
  final String url;

  /// Der Wikipedia-Artikel, aus dem das Bild stammt (für die Bildquelle).
  final String page;
}

/// Mengen, Einheiten und Wörter, die nichts über das Produkt sagen.
const _fuellwoerter = {
  'bio',
  'frisch',
  'frische',
  'frischer',
  'frisches',
  'packung',
  'packungen',
  'pack',
  'dose',
  'dosen',
  'flasche',
  'flaschen',
  'glas',
  'beutel',
  'tüte',
  'stück',
  'liter',
  'gramm',
  'kilo',
  'groß',
  'große',
  'großer',
  'großes',
  'klein',
  'kleine',
  'kleiner',
  'kleines',
  'neue',
  'neuer',
  'neues',
  'vorrat',
  'extra',
};

/// Die aussagekräftigen Wörter eines Produktnamens, längste zuerst.
List<String> productWords(String name) {
  final words = name
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüß]+'))
      .where((w) => w.length >= 3 && !_fuellwoerter.contains(w))
      .toSet()
      .toList();
  words.sort((a, b) => b.length.compareTo(a.length));
  return words;
}

/// Der Name ohne Mengen und Füllwörter: „2 x 500 g Bio Spaghetti“ →
/// „Spaghetti“.
String cleanProductName(String name) => name
    .split(RegExp(r'\s+'))
    .where(
      (w) =>
          w.isNotEmpty &&
          !RegExp(
            r'^[\d.,x×%]+([a-zA-Z]{0,3}|stk\.?)$',
            caseSensitive: false,
          ).hasMatch(w) &&
          !RegExp(
            r'^(g|kg|ml|l|cl|stk\.?|x|×|à)$',
            caseSensitive: false,
          ).hasMatch(w) &&
          !_fuellwoerter.contains(w.toLowerCase()),
    )
    .join(' ')
    .trim();

/// Passt der Artikel [article] zum Produkt [name]? Ein aussagekräftiges Wort
/// muss in beiden vorkommen, eins darf das andere verlängern
/// („Nudel“ passt zu „Nudeln“, „Vollmilch“ zu „Milch“).
bool productMatches(String name, String article) {
  final a = productWords(name);
  final b = productWords(article);
  bool fits(String x, String y) {
    final (short, long) = x.length <= y.length ? (x, y) : (y, x);
    // Hinten angehängt nur ab 4 Buchstaben, damit „Eis“ nicht zu „Reis“ passt.
    return long.startsWith(short) ||
        (short.length >= 4 && long.endsWith(short));
  }

  return a.any((x) => b.any((y) => fits(x, y)));
}

/// Suchbegriffe vom genauesten zum gröbsten: der bereinigte Name, das
/// Stichwort, an dem die App das Produkt erkannt hat ([keyword], z. B.
/// „milch“ in „Vollmilch“), zuletzt das längste einzelne Wort.
List<String> productQueries(String name, {String? keyword}) {
  final clean = cleanProductName(name);
  final words = productWords(clean);
  String cap(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
  final queries = <String, String>{};
  for (final q in [
    clean,
    if (keyword != null && keyword.length >= 3) cap(keyword),
    if (words.isNotEmpty) cap(words.first),
  ]) {
    if (q.isNotEmpty) queries.putIfAbsent(q.toLowerCase(), () => q);
  }
  return queries.values.toList();
}

/// Sucht ein Bild zum Produkt [name]. Zuerst der genaue Artikel (mit
/// Weiterleitungen, „Klopapier“ → „Toilettenpapier“), dann eine Suche, deren
/// Treffer aber zum Namen passen muss. Nur frei lizenzierte Bilder.
/// Nichts Passendes: null.
Future<ProductImage?> fetchProductImage(
  http.Client client,
  String name, {
  String? keyword,
}) async {
  const base = {
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'origin': '*',
    'prop': 'pageimages|info|pageprops',
    'ppprop': 'disambiguation',
    'piprop': 'thumbnail',
    'pithumbsize': '400',
    'pilicense': 'free',
    'inprop': 'url',
    'redirects': '1',
  };
  final queries = productQueries(name, keyword: keyword);
  for (final query in queries) {
    final exact = await _query(client, {...base, 'titles': query});
    if (exact != null) return exact;
  }
  for (final query in queries) {
    final hit = await _query(client, {
      ...base,
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': '5',
    }, matches: (article) => productMatches(query, article));
    if (hit != null) return hit;
  }
  return null;
}

Future<ProductImage?> _query(
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
  final Object? body;
  try {
    body = jsonDecode(res.body);
  } on FormatException {
    return null;
  }
  if (body is! Map) return null;
  final pages = [
    for (final p in (body['query']?['pages'] as List?) ?? const [])
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
    return ProductImage(
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
