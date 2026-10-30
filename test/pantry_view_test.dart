import 'package:bubududu/features/pantry.dart';
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

  test('nach Räumen: alphabetisch, „Ohne Raum“ zuletzt', () {
    final sections = pantrySections(items, PantrySort.rooms, now);
    expect(sections.map((s) => s.$1), ['Bad', 'Küche', 'Ohne Raum']);
    expect(sections[1].$2.map((i) => i.name), ['Apfelsaft', 'Nudeln']);
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

    testWidgets('Sortierung umstellen', (tester) async {
      await db.collection('households/h1/pantry').add({
        'name': 'Zahnpasta',
        'level': 'low',
        'place': 'Bad',
      });
      await pumpPage(tester, const PantryScreen(householdId: 'h1'));
      expect(find.textContaining('Bad ('), findsOneWidget);
      expect(find.text('🪥'), findsOneWidget);

      await tester.tap(find.byTooltip('Sortieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alphabetisch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bad ('), findsNothing);
      expect(find.textContaining('Bad'), findsWidgets);
    });
  });
}
