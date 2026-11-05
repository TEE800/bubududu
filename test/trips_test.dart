import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/trip_widgets.dart';
import 'package:bubududu/features/trips.dart';
import 'package:bubududu/services/place_image.dart';
import 'package:bubududu/services/weather.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Trip trip(
  String name, {
  DateTime? start,
  DateTime? end,
  bool wish = false,
  Place? place,
}) => Trip(
  id: name,
  name: name,
  start: start,
  end: end,
  packing: const [],
  notes: '',
  wish: wish,
  place: place,
);

void main() {
  group('Reisen: Logik', () {
    final now = DateTime(2026, 11, 5);

    test('Countdown', () {
      expect(
        tripCountdown(trip('a', start: DateTime(2026, 11, 17)), now),
        'noch 12 Tage',
      );
      expect(
        tripCountdown(trip('a', start: DateTime(2026, 11, 6)), now),
        'morgen geht’s los',
      );
      expect(
        tripCountdown(
          trip('a', start: DateTime(2026, 11, 4), end: DateTime(2026, 11, 7)),
          now,
        ),
        'Tag 2 von 4',
      );
      expect(
        tripCountdown(trip('a', start: DateTime(2027, 4, 1)), now),
        'noch 5 Monate',
      );
      expect(
        tripCountdown(trip('a', start: DateTime(2026, 10, 1)), now),
        isNull,
      );
      expect(tripCountdown(trip('a'), now), isNull);
      expect(
        tripCountdown(trip('a', start: DateTime(2026, 11, 9), wish: true), now),
        isNull,
      );
    });

    test('Übersicht: nächste Reise, geplant, Wunschziele, Erinnerungen', () {
      final g = groupTrips(
        sortTrips([
          trip('Rom', start: DateTime(2027, 4, 1)),
          trip('Island', wish: true),
          trip('Wien', start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 4)),
          trip('Sylt', start: DateTime(2026, 11, 20)),
          trip('Harz'),
        ], now: now),
        now,
      );
      expect(g.next?.name, 'Sylt');
      expect(g.planned.map((t) => t.name), ['Rom', 'Harz']);
      expect(g.wishes.map((t) => t.name), ['Island']);
      expect(g.past.map((t) => t.name), ['Wien']);
    });

    test('Vorlage ohne Doppelte, wer packt reihum', () {
      final items = addTemplate(
        [(text: 'sonnencreme', done: true, who: 'kevin')],
        ['Sonnencreme', 'Strandtuch'],
      );
      expect(items.map((p) => p.text), ['sonnencreme', 'Strandtuch']);
      expect(items.first.done, isTrue);
      const members = ['kevin', 'fritzi'];
      expect(nextPacker('', members), 'kevin');
      expect(nextPacker('kevin', members), 'fritzi');
      expect(nextPacker('fritzi', members), '');
    });

    test('Ortswörter für das Foto', () {
      expect(placeQueries('Wochenende Sylt'), ['Sylt']);
      expect(
        placeQueries('Städtetrip nach Rom', place: 'Rom, Latium, Italien'),
        ['Rom'],
      );
      expect(placeQueries('Wandern Harz'), ['Harz']);
      expect(placeMatches('Rom', 'Rom'), isTrue);
      expect(placeMatches('Rom', 'Roman'), isFalse);
    });

    test('Wetter nur für die Reisetage', () {
      final days = [
        for (var i = 0; i < 10; i++)
          DayForecast(
            date: DateTime(2026, 11, 5 + i),
            min: 1,
            max: 9,
            code: 3,
            rainChance: 0,
          ),
      ];
      final t = trip(
        'Sylt',
        start: DateTime(2026, 11, 8),
        end: DateTime(2026, 11, 10),
        place: const Place(name: 'Sylt', lat: 54.9, lng: 8.3),
      );
      expect(tripHasForecast(t, now), isTrue);
      expect(tripWeatherDays(t, days, now).map((d) => d.date.day), [8, 9, 10]);
      expect(
        tripHasForecast(trip('Rom', start: DateTime(2027, 4, 1)), now),
        isFalse,
      );
    });
  });

  group('Reisen: Bildschirme', () {
    setUp(seedHousehold);

    Future<String> addTrip(Map<String, dynamic> data) async {
      final store = HouseholdStore(db, 'h1', 'kevin');
      final id = store.newId('trips');
      await store.add('trips', data, id: id);
      return id;
    }

    testWidgets('Übersicht zeigt nächste Reise groß mit Countdown', (
      tester,
    ) async {
      await addTrip({
        'name': 'Sylt',
        'start': Timestamp.fromDate(addDaysFromToday(12)),
        'packing': [
          {'text': 'Ausweis', 'done': true},
          {'text': 'Jacke', 'done': false},
        ],
      });
      await addTrip({'name': 'Island', 'wish': true});
      await pumpPage(tester, const TripsScreen(householdId: 'h1'));
      expect(find.text('Als Nächstes'), findsOneWidget);
      expect(find.text('noch 12 Tage'), findsOneWidget);
      expect(find.textContaining('1/2 gepackt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Wunschziele'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Idee von Dudu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Packliste: wer packt was, Vorlage dazunehmen', (tester) async {
      final id =
          (await db.collection('households/h1/trips').get()).docs.first.id;
      await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
      await tester.tap(find.widgetWithText(ActionChip, 'beide'));
      await tester.pump(const Duration(milliseconds: 100));
      var packing =
          (await db.doc('households/h1/trips/$id').get()).data()!['packing']
              as List;
      expect(packing.first['who'], 'kevin');

      await tester.scrollUntilVisible(
        find.text('Strand'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Strand'));
      await tester.pump(const Duration(milliseconds: 100));
      packing =
          (await db.doc('households/h1/trips/$id').get()).data()!['packing']
              as List;
      expect(packing.map((p) => p['text']), contains('Sonnencreme'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Kosten der Reise', (tester) async {
      final id = await addTrip({
        'name': 'Sylt',
        'start': Timestamp.fromDate(addDaysFromToday(3)),
      });
      final store = HouseholdStore(db, 'h1', 'kevin');
      await store.add('expenses', {
        'title': 'Ferienwohnung',
        'amountCents': 32000,
        'paidBy': 'fritzi',
        'split': 'half',
        'category': 'Reisen',
        'date': Timestamp.now(),
        'tripId': id,
      });
      await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
      await tester.tap(find.text('Kosten'));
      await settle(tester);
      expect(find.text('Ferienwohnung'), findsOneWidget);
      expect(find.textContaining('Bubu hat 320,00'), findsOneWidget);
      expect(find.textContaining('Dudu schuldet Bubu 160,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Plan und Erinnerung', (tester) async {
      final id = await addTrip({
        'name': 'Wien',
        'start': Timestamp.fromDate(addDaysFromToday(-10)),
        'end': Timestamp.fromDate(addDaysFromToday(-7)),
        'travel': 'Nachtzug',
      });
      await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
      // Vorbei: zuerst die Erinnerung.
      expect(find.text('Wie war’s?'), findsOneWidget);
      await tester.tap(find.byTooltip('4 Sterne'));
      await tester.pump(const Duration(milliseconds: 100));
      expect((await db.doc('households/h1/trips/$id').get())['rating'], 4);
      await tester.tap(find.text('Plan'));
      await settle(tester);
      expect(find.text('Nachtzug'), findsOneWidget);
      expect(find.text('Ticket oder Buchung anhängen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Wunschziel planen', (tester) async {
      final id = await addTrip({'name': 'Island', 'wish': true});
      await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
      await tester.tap(find.text('Jetzt planen'));
      await settle(tester);
      await save(tester);
      expect((await db.doc('households/h1/trips/$id').get())['wish'], isFalse);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Speichern'));
  await settle(tester);
}

DateTime addDaysFromToday(int days) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + days);
}
