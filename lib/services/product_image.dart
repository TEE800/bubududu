import 'dart:convert';

import 'package:http/http.dart' as http;

import 'product_photos.dart';

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
    if (short == long) return true;
    // Nur Mehrzahl- und Beugungsendungen („Nudel“ – „Nudeln“), sonst passt
    // „Milch“ zu „Milchstraße“ oder „Käse“ zu „Käsekuchen“.
    if (long.startsWith(short) && long.length - short.length <= 2) return true;
    // Hinten angehängt („Vollmilch“ ist eine Milch) nur ab 4 Buchstaben,
    // damit „Eis“ nicht zu „Reis“ passt.
    return short.length >= 4 && long.endsWith(short);
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
  final curated = curatedProductPhoto(name);
  if (curated != null) return curated;
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
    }, matches: (article) => searchHitFits(query, article));
    if (hit != null) return hit;
  }
  return null;
}

/// Ein Suchtreffer muss zum Namen passen und darf kein Artikel über etwas
/// ganz anderes sein, das nur so heißt: „Quark (Physik)“, „Sahne (Band)“.
bool searchHitFits(String query, String article) {
  final paren = RegExp(r'\(([^)]*)\)').firstMatch(article);
  if (paren != null &&
      !RegExp(
        r'lebensmittel|speise|getränk|gericht|gewürz|käse|wurst|brot|obst|gemüse|pflanze',
        caseSensitive: false,
      ).hasMatch(paren.group(1)!)) {
    return false;
  }
  return productMatches(query, article.replaceAll(RegExp(r'\(.*?\)'), ''));
}

/// Bilder, die zwar zum Artikel gehören, aber kein Produkt zeigen: alte
/// Pflanzenzeichnungen (Köhler, Thomé), Herbarbelege, Karten, Flaggen,
/// Wappen, Strukturformeln, Mikroskopbilder.
bool looksLikeNoProduct(String imageUrl) {
  final file = Uri.decodeFull(imageUrl.split('/').last).toLowerCase();
  return RegExp(
    r'koehler|köhler|thom[eé]|illustration|herbar|mhnt|botanical|tafel|'
    r'flag|flagge|wappen|coat_of_arms|karte|map|locator|lokalisierung|'
    r'structur|struktur|formel|formula|skeletal|molecule|microscop|mikroskop|'
    r'\.svg|diagram|logo|portrait|porträt',
  ).hasMatch(file);
}

/// Mehrere Bildvorschläge zum Produkt [name], zum Aussuchen von Hand:
/// das handverlesene Foto, Bilder passender Wikipedia-Artikel und Fotos
/// aus Wikimedia Commons. Höchstens [limit] Stück, ohne doppelte.
Future<List<ProductImage>> searchProductImages(
  http.Client client,
  String name, {
  int limit = 18,
}) async {
  final clean = cleanProductName(name);
  if (clean.isEmpty) return const [];
  final found = <String, ProductImage>{};
  void add(ProductImage? image) {
    if (image != null && found.length < limit) {
      found.putIfAbsent(image.url, () => image);
    }
  }

  add(curatedProductPhoto(name));
  try {
    final wiki = await _get(client, 'de.wikipedia.org', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
      'generator': 'search',
      'gsrsearch': clean,
      'gsrlimit': '12',
      'prop': 'pageimages|info',
      'piprop': 'thumbnail',
      'pithumbsize': '500',
      'pilicense': 'free',
      'inprop': 'url',
    });
    for (final p in _pages(wiki)) {
      final source = (p['thumbnail'] as Map?)?['source'];
      if (source is! String || source.isEmpty) continue;
      add(
        ProductImage(
          url: source,
          page: p['fullurl'] as String? ?? 'https://de.wikipedia.org',
        ),
      );
    }
  } on Exception {
    // Dann eben nur die anderen Quellen.
  }
  try {
    final commons = await _get(client, 'commons.wikimedia.org', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
      'generator': 'search',
      'gsrnamespace': '6',
      'gsrsearch': '$clean filetype:bitmap',
      'gsrlimit': '18',
      'prop': 'imageinfo',
      'iiprop': 'url',
      'iiurlwidth': '500',
    });
    for (final p in _pages(commons)) {
      final info = ((p['imageinfo'] as List?) ?? const []).firstOrNull;
      if (info is! Map) continue;
      final thumb = info['thumburl'];
      if (thumb is! String || thumb.isEmpty) continue;
      add(
        ProductImage(
          url: thumb,
          page:
              info['descriptionurl'] as String? ??
              'https://commons.wikimedia.org',
        ),
      );
    }
  } on Exception {
    // Nichts gefunden.
  }
  return found.values.toList();
}

Future<Object?> _get(
  http.Client client,
  String host,
  Map<String, String> params,
) async {
  final res = await client.get(
    Uri.https(host, '/w/api.php', params),
    headers: {'Api-User-Agent': 'BubuDudu-App'},
  );
  if (res.statusCode != 200) return null;
  try {
    return jsonDecode(res.body);
  } on FormatException {
    return null;
  }
}

List<Map> _pages(Object? body) {
  if (body is! Map) return const [];
  return [
    for (final p in (body['query']?['pages'] as List?) ?? const [])
      if (p is Map) p,
  ]..sort((a, b) => _index(a).compareTo(_index(b)));
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
    if (looksLikeNoProduct(source)) continue;
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
