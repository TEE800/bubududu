import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/receipt_import.dart';
import 'package:bubududu/util/rewe_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// Text eines echten eBons (aus dem PDF), Markt und Guthaben geändert.
const _bon = '''
             R E W E - Markt
        Musterstrasse 1
             12345 Musterstadt
                                   EUR
SCHINKENWUERFEL                  4,98 B
             2 Stk x    2,49
PARMIGIANO REGG.                 5,99 B
WEIZENBROETCH.                   1,59 B
DIE FEINEN KART.                 2,69 B
SPITZKOHL                        2,06 B
ROSMARIN                         0,99 B
THYMIAN                          0,99 B
EIER 10ER KL. L                  4,79 B
JA! MARKENBUTTER                 1,19 B
H-MILCH GVO-FREI                 0,95 B
MANDELDRINK                      1,49 A
FR.SCHLAGSAHNE                   2,69 B
 --------------------------------------
 SUMME                   EUR     30,40
 ======================================
 Geg. VISA               EUR     30,40
 Steuer %           Netto       Steuer         Brutto
 A= 19,0%            1,25         0,24           1,49
 B=   7,0%          27,02         1,89          28,91
 Gesamtbetrag       28,27         2,13          30,40

  29.10.2026          15:06         Bon-Nr.:7983
  Markt:0000          Kasse:4       Bed.:000000

 ****************************************
    Deine REWE Bonus-Vorteile heute

  Mit diesem Einkauf hast du 1,61 EUR
     REWE Bonus-Guthaben gesammelt:
  Bonus-Coupon(s)
     10% auf REWE Regiona     0,21 EUR
     15% auf Sahne & Saue     0,40 EUR

Aktuelles Bonus-Guthaben: 12,34 EUR
''';

void main() {
  receiptScreenTests();

  group('parseReweReceipt', () {
    final r = parseReweReceipt(_bon);

    test('liest Produkte, Mengen und Summe', () {
      expect(r.lines, hasLength(12));
      expect(r.lines.first.name, 'SCHINKENWUERFEL');
      expect(r.lines.first.cents, 498);
      expect(r.lines.first.quantity, 2);
      expect(r.lines[8].name, 'JA! MARKENBUTTER');
      expect(r.lines.last.cents, 269);
      expect(r.totalCents, 3040);
      expect(r.lines.fold(0, (s, l) => s + l.cents), r.totalCents);
    });

    test('liest Datum und Bonus-Guthaben', () {
      expect(r.date, DateTime(2026, 10, 29, 15, 6));
      expect(r.bonusEarnedCents, 161);
      expect(r.bonusBalanceCents, 1234);
    });

    test('Pfand und Leergut sind keine Produkte', () {
      final p = parseReweReceipt('''
COLA                             1,29 A
PFAND 0,25 EURO                  0,25 A *
LEERGUT                         -0,75 A
 SUMME                   EUR      0,79
''');
      expect(p.lines, hasLength(3));
      expect(p.products.map((l) => l.name), ['COLA']);
      expect(p.totalCents, 79);
    });

    test('liest auch den Text aus dem PDF (einfache Leerzeichen, CR)', () {
      final p = parseReweReceipt(
        ' EUR\r\nSCHINKENWUERFEL 4,98 B\r\n 2 Stk x 2,49\r\n'
        'EIER 10ER KL. L 4,79 B\r\n --------\r\n SUMME EUR 9,77\r\n'
        ' 29.10.2026 15:06 Bon-Nr.:7983\r\n'
        'Aktuelles Bonus-Guthaben: 1,00 EUR\r\n',
      );
      expect(p.lines.map((l) => l.name), [
        'SCHINKENWUERFEL',
        'EIER 10ER KL. L',
      ]);
      expect(p.lines.first.quantity, 2);
      expect(p.totalCents, 977);
      expect(p.date, DateTime(2026, 10, 29, 15, 6));
      expect(p.bonusBalanceCents, 100);
    });

    test('anderer Text ist kein Bon', () {
      expect(
        () => parseReweReceipt('Hallo Welt'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('prettyName', () {
    expect(prettyName('JA! MARKENBUTTER'), 'Ja! Markenbutter');
    expect(prettyName('H-MILCH GVO-FREI'), 'H-Milch Gvo-Frei');
  });

  group('receiptMatches', () {
    test('passt trotz Abkürzungen', () {
      expect(receiptMatches('Butter', 'JA! MARKENBUTTER'), isTrue);
      expect(receiptMatches('Milch', 'H-MILCH GVO-FREI'), isTrue);
      expect(receiptMatches('Eier', 'EIER 10ER KL. L'), isTrue);
      expect(receiptMatches('Brötchen', 'WEIZENBROETCH.'), isTrue);
      expect(receiptMatches('Sahne', 'FR.SCHLAGSAHNE'), isTrue);
      expect(receiptMatches('Parmesan', 'PARMIGIANO REGG.'), isFalse);
    });

    test('passt nicht auf Fremdes', () {
      expect(receiptMatches('Butter', 'H-MILCH GVO-FREI'), isFalse);
      expect(receiptMatches('Kaffee', 'SPITZKOHL'), isFalse);
    });
  });
}

void receiptScreenTests() {
  group('Kassenbon einlesen', () {
    setUp(() async {
      await seedHousehold();
      final store = HouseholdStore(db, 'h1', 'kevin');
      await store.addToShoppingList('Butter');
      await store.addToShoppingList('Kaffee');
      await store.add('pantry', {
        'name': 'Eier',
        'level': 'empty',
        'place': 'Küche',
      });
    });

    testWidgets('hakt ab, füllt auf und trägt die Ausgabe ein', (tester) async {
      await pumpPage(
        tester,
        ReceiptImportScreen(householdId: 'h1', receipt: parseReweReceipt(_bon)),
      );
      expect(find.text('Rewe · 30,40 €'), findsOneWidget);
      expect(find.text('1,61 € Bonus gesammelt'), findsOneWidget);
      expect(find.text('Butter'), findsOneWidget);
      expect(find.text('Kaffee'), findsNothing);
      expect(find.text('Eier'), findsOneWidget);

      await tester.tap(find.text('Übernehmen'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final items = await db.collection('households/h1/shoppingItems').get();
      final done = {
        for (final d in items.docs) d.data()['text']: d.data()['done'],
      };
      expect(done['Butter'], isTrue);
      expect(done['Kaffee'], isFalse);
      final pantry = await db.collection('households/h1/pantry').get();
      expect(
        pantry.docs
            .map((d) => d.data())
            .singleWhere((p) => p['name'] == 'Eier')['level'],
        'full',
      );
      final expenses = await db.collection('households/h1/expenses').get();
      final rewe = expenses.docs
          .map((d) => d.data())
          .where((e) => e['title'] == reweExpenseTitle)
          .single;
      expect(rewe['amountCents'], 3040);
      expect(rewe['paidBy'], 'kevin');
    });
  });
}
