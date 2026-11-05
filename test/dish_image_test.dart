import 'dart:convert';

import 'package:bubududu/services/dish_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Suchbegriffe ohne Füllwörter und "mit …"', () {
    expect(dishQueries('Omas Kartoffelsalat mit Speck'), [
      'Omas Kartoffelsalat mit Speck',
      'Kartoffelsalat',
    ]);
    expect(dishQueries('Pfannkuchen'), ['Pfannkuchen']);
    expect(dishQueries('Schnelle Linsensuppe'), [
      'Schnelle Linsensuppe',
      'Linsensuppe',
    ]);
  });

  test('Treffer muss zum Rezept passen', () {
    expect(dishMatches('Omas Kartoffelsalat', 'Kartoffelsalat'), isTrue);
    expect(dishMatches('Pfannkuchen', 'Pfannkuchen (Begriffsklärung)'), isTrue);
    expect(dishMatches('Chili sin carne', 'Bundesautobahn 7'), isFalse);
  });

  test('Nimmt den genauen Artikel, sonst den passenden Suchtreffer', () async {
    final requests = <Map<String, String>>[];
    final client = MockClient((request) async {
      final q = request.url.queryParameters;
      requests.add(q);
      if (q['titles'] != null) {
        // Genaue Artikel haben hier kein freies Bild.
        return http.Response(
          jsonEncode({
            'query': {
              'pages': [
                {'title': q['titles'], 'missing': true},
              ],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'query': {
            'pages': [
              {
                'title': 'Bundesstraße 1',
                'index': 1,
                'thumbnail': {'source': 'https://x/strasse.jpg'},
              },
              {
                'title': 'Kartoffelsalat',
                'index': 2,
                'fullurl': 'https://de.wikipedia.org/wiki/Kartoffelsalat',
                'thumbnail': {'source': 'https://x/salat.jpg'},
              },
            ],
          },
        }),
        200,
      );
    });
    final image = await fetchDishImage(client, 'Omas Kartoffelsalat');
    expect(image?.url, 'https://x/salat.jpg');
    expect(image?.page, 'https://de.wikipedia.org/wiki/Kartoffelsalat');
    expect(requests.first['pilicense'], 'free');
  });

  test('Nichts gefunden: null', () async {
    final client = MockClient((_) async => http.Response('', 500));
    expect(await fetchDishImage(client, 'Pfannkuchen'), isNull);
  });
}
