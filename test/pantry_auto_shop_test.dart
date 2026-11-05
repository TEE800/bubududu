import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/features/pantry_auto_shop.dart';
import 'package:bubududu/data/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

PantryItem _item(
  String name,
  StockLevel level, {
  ShopRule rule = ShopRule.standard,
  bool shopped = false,
  int? uses,
  double? left,
  int? shopAt,
}) => PantryItem(
  id: name,
  name: name,
  level: level,
  bestBefore: null,
  place: '',
  uses: uses,
  usesLeft: left,
  shopRule: rule,
  shopAt: shopAt,
  autoShopped: shopped,
);

void main() {
  final now = DateTime(2026, 11, 5);

  group('Ab wann auf die Einkaufsliste', () {
    test('Grundeinstellung aus: nichts', () {
      final plan = planAutoShop(
        [_item('Nudeln', StockLevel.low)],
        {},
        ShopDefault.off,
        now,
      );
      expect(plan.isEmpty, isTrue);
    });

    test('sobald knapp vs. erst wenn leer', () {
      final items = [
        _item('Nudeln', StockLevel.low),
        _item('Reis', StockLevel.empty),
        _item('Mehl', StockLevel.full),
      ];
      expect(
        planAutoShop(items, {}, ShopDefault.low, now).add.map((i) => i.name),
        ['Nudeln', 'Reis'],
      );
      expect(
        planAutoShop(items, {}, ShopDefault.empty, now).add.map((i) => i.name),
        ['Reis'],
      );
    });

    test('eigene Regel je Vorrat geht vor', () {
      final items = [
        _item('Nudeln', StockLevel.low, rule: ShopRule.never),
        _item('Kaffee', StockLevel.low, rule: ShopRule.low),
      ];
      expect(
        planAutoShop(items, {}, ShopDefault.empty, now).add.map((i) => i.name),
        ['Kaffee'],
      );
    });

    test('bei bestimmter Restmenge', () {
      final bath = _item(
        'Badezusatz',
        StockLevel.full,
        rule: ShopRule.uses,
        uses: 10,
        left: 3,
        shopAt: 3,
      );
      expect(planAutoShop([bath], {}, ShopDefault.off, now).add, [bath]);
      final more = _item(
        'Badezusatz',
        StockLevel.full,
        rule: ShopRule.uses,
        uses: 10,
        left: 4,
        shopAt: 3,
      );
      expect(planAutoShop([more], {}, ShopDefault.off, now).isEmpty, isTrue);
    });

    test('nicht doppelt, nach Auffüllen wieder bereit', () {
      final onList = _item('Milch', StockLevel.low);
      final done = _item('Nudeln', StockLevel.low, shopped: true);
      final refilled = _item('Reis', StockLevel.full, shopped: true);
      final plan = planAutoShop(
        [onList, done, refilled],
        {'milch'},
        ShopDefault.low,
        now,
      );
      expect(plan.add, isEmpty);
      expect(plan.alreadyListed, [onList]);
      expect(plan.reset, [refilled]);
    });
  });

  group('Automatik', () {
    setUp(seedHousehold);

    testWidgets('setzt Knappes auf die Liste, aber nur einmal', (tester) async {
      await db.doc('households/h1/settings/pantry').set({'autoShop': 'low'});
      await db.collection('households/h1/pantry').add({
        'name': 'Kaffee',
        'level': 'low',
      });
      await pumpPage(
        tester,
        const PantryAutoShop(householdId: 'h1', child: SizedBox()),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      Future<List<Map<String, dynamic>>> list() async => [
        for (final d
            in (await db.collection('households/h1/shoppingItems').get()).docs)
          d.data(),
      ];
      expect((await list()).where((d) => d['text'] == 'Kaffee'), hasLength(1));
      // Nudeln (knapp) aus den Beispieldaten kommt auch dazu.
      expect((await list()).map((d) => d['text']), contains('Nudeln'));
      final coffee = (await db.collection('households/h1/pantry').get()).docs
          .firstWhere((d) => d['name'] == 'Kaffee');
      expect(coffee['autoShopped'], isTrue);

      // Abhaken und löschen: kommt nicht gleich wieder.
      for (final d
          in (await db.collection('households/h1/shoppingItems').get()).docs) {
        await d.reference.delete();
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(await list(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Einstellung in den Vorräten ändern', (tester) async {
      await pumpPage(tester, const PantryScreen(householdId: 'h1'));
      await tester.tap(find.text('Automatisch auf die Einkaufsliste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erst wenn etwas leer ist'));
      await tester.pumpAndSettle();
      final s = await db.doc('households/h1/settings/pantry').get();
      expect(s.data()?['autoShop'], 'empty');
      expect(find.text('Erst wenn etwas leer ist'), findsOneWidget);
    });

    testWidgets('eigene Restmenge je Vorrat speichern', (tester) async {
      final ref = await db.collection('households/h1/pantry').add({
        'name': 'Badezusatz',
        'level': 'full',
        'uses': 10,
        'usesLeft': 10,
        'usesAt': Timestamp.now(),
      });
      final item = PantryItem.fromDoc(Doc(ref.id, (await ref.get()).data()!));
      await pumpPage(tester, PantryEditScreen(householdId: 'h1', item: item));
      final dropdown = find.text('Wie für alle eingestellt');
      await tester.scrollUntilVisible(
        dropdown,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bei einer bestimmten Restmenge').last);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(
        TextField,
        'Auf die Liste, wenn nur noch so viele übrig sind',
      );
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '2');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final saved = (await ref.get()).data()!;
      expect(saved['shopRule'], 'uses');
      expect(saved['shopAt'], 2);
    });
  });
}
