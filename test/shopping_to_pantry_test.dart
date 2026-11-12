import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/features/shopping_to_pantry.dart';
import 'package:bubududu/screens/shopping_screen.dart';
import 'package:bubududu/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

PantryItem _item(
  String id,
  String name, {
  int? count,
  StockLevel level = StockLevel.full,
}) => PantryItem(
  id: id,
  name: name,
  level: level,
  bestBefore: null,
  place: '',
  count: count,
);

void main() {
  final now = DateTime(2026, 11, 10);

  group('Einkauf erkennen', () {
    test('Namen vergleichen', () {
      expect(productKey('  Haferflocken '), 'haferflocken');
      expect(productKey('Käse'), productKey('kaese'));
      expect(productKey('Klo-Papier'), 'klo papier');
    });

    test('Anzahl aus dem Text', () {
      expect(parsePurchase('Milch'), (name: 'Milch', amount: 1));
      expect(parsePurchase('3 Eier'), (name: 'Eier', amount: 3));
      expect(parsePurchase('2x Milch'), (name: 'Milch', amount: 2));
      expect(parsePurchase('2 Packungen Nudeln'), (name: 'Nudeln', amount: 2));
      expect(parsePurchase('500 g Mehl'), (name: 'Mehl', amount: 1));
      expect(parsePurchase('1,5 l Milch'), (name: 'Milch', amount: 1));
      expect(parsePurchase('Milch x2'), (name: 'Milch', amount: 2));
      expect(parsePurchase('7up'), (name: '7up', amount: 1));
    });

    test('passender Vorrat, auch Einzahl/Mehrzahl', () {
      final pantry = [
        _item('a', 'Tomaten'),
        _item('b', 'Ei'),
        _item('c', 'Milch'),
      ];
      expect(findPantryMatch(pantry, 'tomate')?.id, 'a');
      expect(findPantryMatch(pantry, 'Eier')?.id, 'b');
      expect(findPantryMatch(pantry, 'MILCH ')?.id, 'c');
      expect(findPantryMatch(pantry, 'Milchreis'), isNull);
    });
  });

  group('Eigene Mengenangabe', () {
    test('Anzahl aus dem Mengenfeld', () {
      expect(amountCount(''), 1);
      expect(amountCount('2'), 2);
      expect(amountCount('3 Stück'), 3);
      expect(amountCount('2 Packungen'), 2);
      expect(amountCount('2x'), 2);
      expect(amountCount('500 g'), 1);
      expect(amountCount('500g'), 1);
      expect(amountCount('1,5 l'), 1);
      expect(amountCount('etwas'), 1);
      expect(amountCount('0'), 1);
    });

    test('Mengenfeld gilt statt Zahl im Namen', () {
      expect(parseShoppingItem('Eier', '6'), (name: 'Eier', amount: 6));
      expect(parseShoppingItem('3 Eier', ''), (name: 'Eier', amount: 3));
      expect(parseShoppingItem('Mehl', '500 g'), (name: 'Mehl', amount: 1));
    });

    test('beim Abhaken zählt die Menge', () {
      final p = planPurchase(
        [_item('a', 'Milch', count: 1)],
        'Milch',
        now,
        amount: '2',
      );
      expect(p.pantryId, 'a');
      expect(p.count, 3);
    });
  });

  group('In die Vorräte buchen', () {
    test('neues Produkt wird angelegt', () {
      final p = planPurchase([], 'äpfel', now);
      expect(p.created, isTrue);
      expect(p.fields['name'], 'Äpfel');
      expect(p.fields['count'], 1);
    });

    test('vorhandenes Produkt: Anzahl steigt', () {
      final p = planPurchase([_item('a', 'Milch', count: 2)], '2x milch', now);
      expect(p.created, isFalse);
      expect(p.pantryId, 'a');
      expect(p.count, 4);
      expect(p.fields['level'], 'full');
      expect(p.before['count'], 2);
    });

    test('ohne Anzahl: leer zählt 0, sonst 1', () {
      expect(
        planPurchase(
          [_item('a', 'Milch', level: StockLevel.empty)],
          'Milch',
          now,
        ).count,
        1,
      );
      expect(planPurchase([_item('a', 'Milch')], 'Milch', now).count, 2);
    });

    test('automatisch gesetzter Eintrag trifft seinen Vorrat', () {
      final p = planPurchase(
        [_item('a', 'Spülmittel'), _item('b', 'Spüli')],
        'Spüli',
        now,
        pantryId: 'a',
      );
      expect(p.pantryId, 'a');
    });
  });

  group('Abhaken in der Einkaufsliste', () {
    setUp(seedHousehold);

    testWidgets('Abhaken bucht in die Vorräte, Wieder offen nimmt es zurück', (
      tester,
    ) async {
      final store = HouseholdStore(db, 'h1', 'kevin');
      await store.add('pantry', {'name': 'Kaffee', 'level': 'low', 'count': 1});
      await db.collection('households/h1/shoppingItems').doc('s1').set({
        'text': 'Kaffee',
        'done': false,
        'addedBy': 'kevin',
        'createdAt': DateTime(2026, 1, 1),
      });
      await db.collection('households/h1/shoppingItems').doc('s2').set({
        'text': 'Zahnpasta',
        'done': false,
        'addedBy': 'kevin',
        'createdAt': DateTime(2026, 1, 2),
      });
      await pumpPage(tester, const ShoppingScreen(householdId: 'h1'));

      Future<List<Map<String, dynamic>>> pantry() async => [
        for (final d
            in (await db.collection('households/h1/pantry').get()).docs)
          d.data(),
      ];

      await tester.tap(find.text('Kaffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zahnpasta'));
      await tester.pumpAndSettle();

      var items = await pantry();
      expect(items, hasLength(3)); // mit den Nudeln aus den Beispieldaten
      final milch = items.firstWhere((m) => m['name'] == 'Kaffee');
      expect(milch['count'], 2);
      expect(milch['level'], 'full');
      expect(
        items.any((m) => m['name'] == 'Zahnpasta' && m['count'] == 1),
        isTrue,
      );

      // Wieder offen: alles wie vorher.
      await tester.tap(find.text('Kaffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zahnpasta'));
      await tester.pumpAndSettle();
      items = await pantry();
      expect(items, hasLength(2));
      final kaffee = items.firstWhere((m) => m['name'] == 'Kaffee');
      expect(kaffee['count'], 1);
      expect(kaffee['level'], 'low');
      final s1 = await db.doc('households/h1/shoppingItems/s1').get();
      expect(s1.data()!['done'], isFalse);
      expect(s1.data()!.containsKey('pantryUndo'), isFalse);
    });
  });
}
