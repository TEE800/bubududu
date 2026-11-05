import 'dart:convert';

import 'package:bubududu/services/product_image.dart';
import 'package:bubududu/widgets/item_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Mengen und Füllwörter fallen weg', () {
    expect(cleanProductName('2 x 500 g Bio Spaghetti'), 'Spaghetti');
    expect(cleanProductName('Milch 1,5%'), 'Milch');
    expect(cleanProductName('Klopapier'), 'Klopapier');
  });

  test('Suchbegriffe: Name, erkanntes Stichwort, längstes Wort', () {
    expect(
      productQueries('Bio Vollmilch 3,5%', keyword: itemKeyword('Vollmilch')),
      ['Vollmilch', 'Milch'],
    );
    expect(productQueries('Rote Linsen'), ['Rote Linsen', 'Linsen']);
  });

  test('Treffer müssen zum Namen passen', () {
    expect(productMatches('Nudeln', 'Nudel'), isTrue);
    expect(productMatches('Vollmilch', 'Milch'), isTrue);
    expect(productMatches('Eis', 'Reis'), isFalse);
    expect(productMatches('Zahnpasta', 'Zahnbürste'), isFalse);
  });

  test('nimmt das frei lizenzierte Bild des Artikels', () async {
    final asked = <String>[];
    final client = MockClient((request) async {
      final q = request.url.queryParameters;
      asked.add(q['titles'] ?? 'Suche: ${q['gsrsearch']}');
      if (q['titles'] == 'Klopapier') {
        return http.Response(
          jsonEncode({
            'query': {
              'pages': [
                {
                  'title': 'Toilettenpapier',
                  'fullurl': 'https://de.wikipedia.org/wiki/Toilettenpapier',
                  'thumbnail': {'source': 'https://upload.wikimedia.org/t.jpg'},
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'query': {'pages': []},
        }),
        200,
      );
    });
    final image = await fetchProductImage(
      client,
      '4 Klopapier',
      keyword: itemKeyword('Klopapier'),
    );
    expect(image?.url, 'https://upload.wikimedia.org/t.jpg');
    expect(image?.page, contains('Toilettenpapier'));
    expect(asked.first, 'Klopapier');
  });

  test('nichts Passendes: null', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'query': {'pages': []},
        }),
        200,
      ),
    );
    expect(await fetchProductImage(client, 'Xyzabc'), isNull);
  });
}
