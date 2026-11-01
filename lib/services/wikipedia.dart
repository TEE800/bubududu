import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'weather.dart' show httpClientProvider;

/// Die Einleitung eines Artikels der deutschen Wikipedia.
class WikiArticle {
  const WikiArticle({
    required this.title,
    required this.extract,
    required this.url,
  });

  final String title;
  final String extract;
  final String url;
}

/// Lädt den Wikipedia-Artikel zu einem Aktionstag. Zuerst wird der genaue
/// Titel [title] versucht (Weiterleitungen inklusive), dann der Name des
/// Tages, zuletzt eine Suche, deren Treffer aber nur genommen wird, wenn er
/// zum Namen passt. Kein passender Artikel: null.
Future<WikiArticle?> fetchWikiArticle(
  http.Client client,
  String title, {
  String? name,
}) async {
  name ??= title;
  const base = {
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'origin': '*',
    'prop': 'extracts|info|pageprops',
    'exintro': '1',
    'explaintext': '1',
    'inprop': 'url',
    'ppprop': 'disambiguation',
    'redirects': '1',
  };
  for (final t in {title, name}) {
    final exact = await _query(client, {...base, 'titles': t});
    if (exact != null) return exact;
  }
  final hit = await _query(client, {
    ...base,
    'generator': 'search',
    'gsrsearch': name,
    'gsrlimit': '1',
  });
  if (hit != null && titleMatches(name, hit.title)) return hit;
  return null;
}

Future<WikiArticle?> _query(
  http.Client client,
  Map<String, String> params,
) async {
  final uri = Uri.https('de.wikipedia.org', '/w/api.php', params);
  final res = await client.get(
    uri,
    headers: {'Api-User-Agent': 'BubuDudu-App'},
  );
  if (res.statusCode != 200) return null;
  final pages = (jsonDecode(res.body)['query']?['pages'] as List?) ?? const [];
  for (final p in pages) {
    if (p is! Map || p['missing'] == true || p['invalid'] == true) continue;
    if ((p['pageprops'] as Map?)?.containsKey('disambiguation') ?? false) {
      continue;
    }
    final extract = (p['extract'] as String? ?? '').trim();
    if (extract.length < 40) continue;
    return WikiArticle(
      title: p['title'] as String,
      extract: shortenExtract(extract),
      url:
          p['fullurl'] as String? ??
          'https://de.wikipedia.org/wiki/${Uri.encodeComponent(p['title'] as String)}',
    );
  }
  return null;
}

/// Kürzt den Text auf ganze Absätze, höchstens etwa [max] Zeichen.
String shortenExtract(String text, {int max = 1500}) {
  final paragraphs = text
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final out = StringBuffer();
  for (final p in paragraphs) {
    if (out.isNotEmpty && out.length + p.length > max) break;
    if (out.isNotEmpty) out.write('\n\n');
    out.write(p);
  }
  return out.toString();
}

const _fuellwoerter = {
  'internationaler',
  'internationale',
  'internationalen',
  'welttag',
  'europäischer',
  'europäische',
  'deutschen',
  'deutsche',
  'gedenktag',
  'gegen',
  'opfer',
  'tages',
};

Iterable<String> _woerter(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-zäöüß]+'))
    .where((w) => w.length >= 5 && !_fuellwoerter.contains(w));

/// Passt ein Suchtreffer zum Namen des Tages? Mindestens ein
/// aussagekräftiges Wort muss in beiden vorkommen (ein Wort darf das
/// andere verlängern, damit "Pinguin" und "Pinguine" zusammenpassen).
bool titleMatches(String name, String title) {
  final a = _woerter(name).toList();
  final b = _woerter(title).toList();
  return a.any((x) => b.any((y) => x.startsWith(y) || y.startsWith(x)));
}

/// Schlüssel: (Wikipedia-Titel, Name des Tages).
final wikiArticleProvider =
    FutureProvider.family<WikiArticle?, (String, String)>(
      (ref, key) =>
          fetchWikiArticle(ref.watch(httpClientProvider), key.$1, name: key.$2),
    );
