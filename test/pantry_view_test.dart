import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/services/product_image.dart';
import 'package:bubududu/widgets/item_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

PantryItem _item(String name, String place, StockLevel level) => PantryItem(
  id: name,
  name: name,
  level: level,
  bestBefore: null,
  place: place,
);

void main() {
  final now = DateTime(2026, 10, 30);
  final items = [
    _item('Nudeln', 'Küche', StockLevel.full),
    _item('Klopapier', 'Bad', StockLevel.low),
    _item('Batterien', '', StockLevel.full),
    _item('Apfelsaft', 'küche', StockLevel.empty),
  ];

  test('nach Räumen: alphabetisch, „Ohne Zimmer“ zuletzt', () {
    final sections = pantrySections(items, PantrySort.rooms, now);
    expect(sections.map((s) => s.$1), ['Bad', 'Küche', 'Ohne Zimmer']);
    expect(sections[1].$2.map((i) => i.name), ['Apfelsaft', 'Nudeln']);
  });

  test('nach Produktgruppen: in Einkaufsreihenfolge', () {
    final sections = pantrySections(items, PantrySort.groups, now);
    expect(sections.map((s) => s.$1), [
      'Nudeln, Reis & Konserven',
      'Getränke',
      'Haushalt',
    ]);
    expect(sections[2].$2.map((i) => i.name), ['Batterien', 'Klopapier']);
  });

  test('alphabetisch: ein Abschnitt ohne Überschrift', () {
    final sections = pantrySections(items, PantrySort.name, now);
    expect(sections.single.$1, '');
    expect(sections.single.$2.map((i) => i.name), [
      'Apfelsaft',
      'Batterien',
      'Klopapier',
      'Nudeln',
    ]);
  });

  test('nach Restmenge: was fast alle ist, zuerst', () {
    final sections = pantrySections(items, PantrySort.left, now);
    expect(sections.single.$2.map((i) => i.name), [
      'Apfelsaft',
      'Klopapier',
      'Batterien',
      'Nudeln',
    ]);
  });

  group('Kacheln', () {
    setUp(seedHousehold);

    testWidgets('Sortierung umstellen: Thema, Zimmer, A–Z', (tester) async {
      await db.collection('households/h1/pantry').add({
        'name': 'Zahnpasta',
        'level': 'low',
        'place': 'Bad',
      });
      await pumpPage(tester, const PantryScreen(householdId: 'h1'));
      // Standard: nach Thema.
      expect(find.textContaining('Drogerie & Gesundheit ('), findsOneWidget);
      expect(find.textContaining('Bad ('), findsNothing);
      expect(find.text('🪥'), findsOneWidget);

      await tester.tap(find.text('Zimmer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bad ('), findsOneWidget);

      await tester.tap(find.text('A–Z'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bad ('), findsNothing);
      expect(find.textContaining('Drogerie'), findsNothing);
      expect(find.textContaining('Bad'), findsWidgets);
    });

    testWidgets('Kachel zeigt automatisch gefundenes Bild', (tester) async {
      await db.collection('households/h1/pantry').add({
        'name': 'Kaffee',
        'level': 'full',
      });
      final searched = <String>[];
      await pumpPage(
        tester,
        const PantryScreen(householdId: 'h1'),
        overrides: [
          productImageFinderProvider.overrideWithValue((name) async {
            searched.add(name);
            return const ProductImage(
              url: 'https://upload.wikimedia.org/kaffee.jpg',
              page: 'https://de.wikipedia.org/wiki/Kaffee',
            );
          }),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(searched, contains('Kaffee'));
      final saved = await db.doc('households/h1/itemImages/kaffee').get();
      expect(saved.data()?['url'], 'https://upload.wikimedia.org/kaffee.jpg');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Image), findsWidgets);
    });
    testWidgets('alte Treffer werden neu gesucht, ausgesuchte nicht', (
      tester,
    ) async {
      await db.collection('households/h1/pantry').add({
        'name': 'Quark',
        'level': 'full',
      });
      await db.collection('households/h1/pantry').add({
        'name': 'Senf',
        'level': 'full',
      });
      // Quark: von der alten Suche (Physik-Bild). Senf: von Hand ausgesucht.
      await db.doc('households/h1/itemImages/quark').set({
        'url': 'https://upload.wikimedia.org/physik.png',
      });
      await db.doc('households/h1/itemImages/senf').set({
        'url': 'https://upload.wikimedia.org/mein-senf.jpg',
        'picked': true,
      });
      final searched = <String>[];
      await pumpPage(
        tester,
        const PantryScreen(householdId: 'h1'),
        overrides: [
          productImageFinderProvider.overrideWithValue((name) async {
            searched.add(name);
            return const ProductImage(
              url: 'https://upload.wikimedia.org/quark.jpg',
              page: 'https://commons.wikimedia.org/wiki/File:Quark.jpg',
            );
          }),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(searched, ['Quark']);
      final quark = await db.doc('households/h1/itemImages/quark').get();
      expect(quark.data()?['url'], 'https://upload.wikimedia.org/quark.jpg');
      expect(quark.data()?['v'], itemImageVersion);
      final senf = await db.doc('households/h1/itemImages/senf').get();
      expect(senf.data()?['url'], 'https://upload.wikimedia.org/mein-senf.jpg');
    });

    testWidgets('Bild aus Vorschlägen aussuchen', (tester) async {
      final asked = <String>[];
      await pumpPage(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showItemPhotoSheet(
                context,
                ref,
                householdId: 'h1',
                name: 'Paprika',
                hasPhoto: false,
              ),
              child: const Text('Bild'),
            ),
          ),
        ),
        overrides: [
          productImageChoicesProvider.overrideWithValue((name) async {
            asked.add(name);
            return [
              for (final n in ['rot', 'gelb', 'gruen'])
                ProductImage(
                  url: 'https://upload.wikimedia.org/paprika-$n.jpg',
                  page: 'https://commons.wikimedia.org/wiki/File:$n.jpg',
                ),
            ];
          }),
        ],
      );
      await tester.tap(find.text('Bild'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bild aus Vorschlägen aussuchen'));
      await tester.pumpAndSettle();
      expect(asked, ['Paprika']);
      expect(find.text('Bild für „Paprika“ aussuchen'), findsOneWidget);

      // Eigener Suchbegriff.
      await tester.enterText(find.byType(TextField), 'Rote Paprika');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(asked, ['Paprika', 'Rote Paprika']);

      await tester.tap(find.bySemanticsLabel('Bild 2 nehmen'));
      await tester.pumpAndSettle();
      final saved = await db.doc('households/h1/itemImages/paprika').get();
      expect(
        saved.data()?['url'],
        'https://upload.wikimedia.org/paprika-gelb.jpg',
      );
      expect(saved.data()?['picked'], isTrue);
    });
  });
}
