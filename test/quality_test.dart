import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/contracts.dart';
import 'package:bubududu/features/meals.dart';
import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/features/tasks.dart';
import 'package:bubududu/features/trips.dart';
import 'package:bubududu/notifications/reminders.dart';
import 'package:bubududu/screens/household_screen.dart';
import 'package:bubududu/screens/shopping_screen.dart';
import 'package:bubududu/theme.dart';
import 'package:bubududu/util/dates.dart';
import 'package:bubududu/util/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Fehler aus der Qualitätsprüfung. Die Zeitumstellungs-Tests greifen nur in
/// deutscher Zeitzone, deshalb laufen die Tests in der CI mit TZ=Europe/Berlin.
void main() {
  group('Zeitumstellung', () {
    // 25.10.2026: Uhren werden zurückgestellt, der Tag hat 25 Stunden.
    // 29.03.2026: Uhren werden vorgestellt, der Tag hat 23 Stunden.
    test('addDays landet immer um Mitternacht am richtigen Tag', () {
      expect(addDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 30), -1), DateTime(2026, 3, 29));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    });

    test(
      'Geburtstag am Tag der Zeitumstellung hängt den Kalender nicht auf',
      () {
        final birthday = CalendarEvent(
          id: 'b',
          title: 'Geburtstag Oma',
          date: DateTime(1950, 10, 25),
          time: null,
          who: '',
          yearly: true,
          note: '',
        );
        final list = occurrences(
          [birthday],
          DateTime(2026, 10, 1),
          DateTime(2028, 12, 31),
        );
        expect(list.map((o) => o.day), [
          DateTime(2026, 10, 25),
          DateTime(2027, 10, 25),
          DateTime(2028, 10, 25),
        ]);
      },
    );

    test(
      'Wochen im Essensplan beginnen über die Umstellung hinweg am Montag',
      () {
        expect(startOfWeek(DateTime(2026, 10, 28, 15)), DateTime(2026, 10, 26));
        expect(startOfWeek(DateTime(2026, 10, 25, 23)), DateTime(2026, 10, 19));
        final week = startOfWeek(DateTime(2026, 10, 21));
        expect(mealDocId(addDays(week, 6)), '2026-10-25');
        expect(mealDocId(addDays(week, 7)), '2026-10-26');
      },
    );

    test('Pflege ist nach Intervall am richtigen Tag fällig', () {
      final item = CareItem(
        id: 'c',
        name: 'Monstera',
        kind: CareKind.plant,
        action: 'Gießen',
        intervalDays: 7,
        lastDone: DateTime(2026, 10, 20),
        lastBy: '',
      );
      expect(item.nextDue, DateTime(2026, 10, 27));
      expect(item.isDue(DateTime(2026, 10, 26, 23)), isFalse);
      expect(item.isDue(DateTime(2026, 10, 27, 8)), isTrue);
    });

    test('Erinnerung am Vorabend liegt am Vortag', () {
      final reminders = computeReminders(
        uid: 'kevin',
        now: DateTime(2026, 3, 20),
        events: [
          CalendarEvent(
            id: 'e',
            title: 'Jahrestag',
            date: DateTime(2022, 3, 30),
            time: null,
            who: '',
            yearly: true,
            note: '',
          ),
        ],
      );
      final eve = reminders.firstWhere((r) => r.key.endsWith(':eve'));
      expect(eve.at, DateTime(2026, 3, 29, 18));
    });
  });

  group('Kleinigkeiten', () {
    test('Tausenderpunkt ohne Komma', () {
      expect(parseCents('1.234'), 123400);
      expect(parseCents('12.000'), 1200000);
      expect(parseCents('12.50'), 1250);
      expect(parseCents('1.5'), 150);
    });

    test('Ein Tag, zwei Tage', () {
      expect(daysText(1), '1 Tag');
      expect(daysText(0), '0 Tage');
      expect(daysText(12), '12 Tage');
    });

    test('Vorräte: nichts doppelt auf die Einkaufsliste', () {
      PantryItem item(String name) => PantryItem(
        id: name,
        name: name,
        level: StockLevel.low,
        bestBefore: null,
        place: '',
      );
      expect(
        missingForShopping(
          [item('Nudeln'), item('Milch'), item('nudeln'), item('Reis')],
          {'milch'},
        ),
        ['Nudeln', 'Reis'],
      );
    });

    test('Verträge: abgelaufene Fristen rutschen nach unten', () {
      Contract c(String name, DateTime? by) => Contract(
        id: name,
        name: name,
        provider: '',
        costCents: 100,
        interval: BillingInterval.monthly,
        cancelBy: by,
        note: '',
      );
      final now = DateTime(2026, 10, 28);
      final sorted = sortContracts([
        c('Handy', DateTime(2026, 1, 1)),
        c('strom', null),
        c('Netflix', DateTime(2026, 12, 1)),
        c('Gas', DateTime(2026, 11, 1)),
      ], now: now);
      expect(sorted.map((c) => c.name), ['Gas', 'Netflix', 'Handy', 'strom']);
    });

    test('Reisen: kommende oben, vergangene unten', () {
      Trip t(String name, DateTime? start, [DateTime? end]) => Trip(
        id: name,
        name: name,
        start: start,
        end: end,
        packing: const [],
        notes: '',
      );
      final now = DateTime(2026, 10, 28);
      final sorted = sortTrips([
        t('Rom', DateTime(2025, 5, 1), DateTime(2025, 5, 7)),
        t('Ostsee', DateTime(2026, 12, 1)),
        t('Irgendwann', null),
        t('Harz', DateTime(2026, 10, 27), DateTime(2026, 10, 30)),
        t('Prag', DateTime(2026, 3, 1)),
      ], now: now);
      expect(sorted.map((t) => t.name), [
        'Harz',
        'Ostsee',
        'Irgendwann',
        'Prag',
        'Rom',
      ]);
    });
  });

  group('Bildschirme', () {
    setUp(() async {
      await seedHousehold();
    });

    testWidgets('Einkauf: Löschen lässt sich rückgängig machen', (
      tester,
    ) async {
      await pumpPage(tester, const ShoppingScreen(householdId: 'h1'));
      expect(find.text('Milch'), findsOneWidget);

      await tester.tap(find.byTooltip('Löschen'));
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('„Milch“ gelöscht'), findsOneWidget);

      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final items = await db.collection('households/h1/shoppingItems').get();
      expect(items.docs.map((d) => d.data()['text']), ['Milch']);
    });

    testWidgets(
      'Einkauf: „Erledigte löschen“ ist auf der grünen Leiste lesbar',
      (tester) async {
        final items = await db.collection('households/h1/shoppingItems').get();
        await items.docs.first.reference.update({'done': true});
        await pumpPage(
          tester,
          const ShoppingScreen(householdId: 'h1'),
          theme: appTheme(Brightness.light),
        );

        final label = tester.widget<Text>(find.text('Erledigte löschen'));
        final style = DefaultTextStyle.of(
          tester.element(find.text('Erledigte löschen')),
        ).style.merge(label.style);
        // Ohne eigene Farbe wäre der Text dunkelgrün auf dunkelgrün.
        expect(style.color, Colors.white);

        await tester.tap(find.text('Erledigte löschen'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          (await db.collection('households/h1/shoppingItems').get()).docs,
          isEmpty,
        );
      },
    );

    testWidgets('Abmelden schließt die geöffnete „Wir“-Seite', (tester) async {
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HouseholdScreen(householdId: 'h1'),
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Abmelden'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(find.byType(HouseholdScreen), findsNothing);
    });
  });

  test('Termin mit kaputter Uhrzeit hat trotzdem einen Tagesplan', () {
    final e = CalendarEvent.fromDoc(
      Doc('x', {
        'title': 'Import',
        'date': Timestamp.fromDate(DateTime(2026, 11, 2)),
        'time': 'ganztags',
      }),
    );
    expect(e.time, 'ganztags');
    expect(
      occurrences([e], DateTime(2026, 11, 1), DateTime(2026, 11, 3)),
      hasLength(1),
    );
  });
}
