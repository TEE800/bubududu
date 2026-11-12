import 'dart:convert';

import 'package:bubududu/services/product_image.dart';
import 'package:bubududu/services/product_photos.dart';
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
    expect(productMatches('Milch', 'Milchstraße'), isFalse);
    expect(productMatches('Käse', 'Käsekuchen'), isFalse);
  });

  test('Suchtreffer über etwas anderes, das nur so heißt, zählen nicht', () {
    expect(searchHitFits('Quark', 'Quark (Physik)'), isFalse);
    expect(searchHitFits('Sahne', 'Sahne (Band)'), isFalse);
    expect(searchHitFits('Nudeln', 'Nudel (Lebensmittel)'), isTrue);
    expect(searchHitFits('Tomaten', 'Tomate'), isTrue);
  });

  test('Pflanzenzeichnungen, Karten und Flaggen sind keine Produktbilder', () {
    expect(
      looksLikeNoProduct(
        'https://upload.wikimedia.org/x/400px-Illustration_Solanum_tuberosum0.jpg',
      ),
      isTrue,
    );
    expect(
      looksLikeNoProduct(
        'https://upload.wikimedia.org/x/Flag_of_Gouda.svg.png',
      ),
      isTrue,
    );
    expect(
      looksLikeNoProduct('https://upload.wikimedia.org/x/400px-Toast-2.jpg'),
      isFalse,
    );
  });

  test('häufige Produkte haben ein handverlesenes Foto', () {
    for (final name in [
      'Eier',
      '6 Eier',
      'Quark',
      'Sahne',
      'Kartoffeln',
      'Äpfel',
      'Chips',
      'Gouda',
      'Hafermilch',
    ]) {
      expect(curatedProductPhoto(name), isNotNull, reason: name);
    }
    expect(curatedProductPhoto('Hafermilch')!.url, contains('commons'));
    expect(
      curatedProductPhoto('Hafermilch')!.url,
      isNot(curatedProductPhoto('Milch')!.url),
    );
    // „Ei“ nur als ganzes Wort, nicht in „Eis“ oder „Eimer“; „Reis“ nicht
    // mitten in „Preiselbeeren“.
    expect(curatedProductPhoto('Eimer'), isNull);
    expect(curatedProductPhoto('Preiselbeeren'), isNull);
    expect(
      curatedProductPhoto('Bio-Eier')!.url,
      curatedProductPhoto('Eier')!.url,
    );
    expect(
      curatedProductPhoto('Kartoffelchips')!.url,
      curatedProductPhoto('Chips')!.url,
    );
    expect(
      curatedProductPhoto('Vollmilch 3,5%')!.url,
      curatedProductPhoto('Milch')!.url,
    );
    expect(
      curatedProductPhoto('Eis')?.url,
      isNot(curatedProductPhoto('Eier')!.url),
    );
  });

  test('nimmt das frei lizenzierte Bild des Artikels', () async {
    final asked = <String>[];
    final client = MockClient((request) async {
      final q = request.url.queryParameters;
      asked.add(q['titles'] ?? 'Suche: ${q['gsrsearch']}');
      if (q['titles'] == 'Spekulatius') {
        return http.Response(
          jsonEncode({
            'query': {
              'pages': [
                {
                  'title': 'Spekulatius',
                  'fullurl': 'https://de.wikipedia.org/wiki/Spekulatius',
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
      '2 Pack Spekulatius',
      keyword: itemKeyword('Spekulatius'),
    );
    expect(image?.url, 'https://upload.wikimedia.org/t.jpg');
    expect(image?.page, contains('Spekulatius'));
    expect(asked.first, 'Spekulatius');
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
