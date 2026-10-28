import 'dart:convert';

import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/providers.dart';
import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/contracts.dart';
import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/finance.dart';
import 'package:bubududu/features/location.dart';
import 'package:bubududu/features/meals.dart';
import 'package:bubududu/features/notes.dart';
import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/features/tasks.dart';
import 'package:bubududu/features/trips.dart';
import 'package:bubududu/features/us.dart';
import 'package:bubududu/screens/home_screen.dart';
import 'package:bubududu/screens/household_screen.dart';
import 'package:bubududu/screens/more_screen.dart';
import 'package:bubududu/screens/recipes_screen.dart';
import 'package:bubududu/services/weather.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

late FakeFirebaseFirestore db;

final mockHttp = MockClient((request) async {
  if (request.url.host == 'api.open-meteo.com') {
    return http.Response(
      jsonEncode({
        'current': {'temperature_2m': 11.4, 'weather_code': 3},
        'daily': {
          'time': ['2026-10-28', '2026-10-29', '2026-10-30'],
          'temperature_2m_max': [12.1, 14.0, 9.0],
          'temperature_2m_min': [5.2, 6.8, 2.0],
          'weather_code': [3, 61, 0],
          'precipitation_probability_max': [10, 80, 0],
        },
      }),
      200,
    );
  }
  if (request.url.host == 'query1.finance.yahoo.com') {
    return http.Response(
      jsonEncode({
        'chart': {
          'result': [
            {
              'meta': {
                'regularMarketPrice': 220.0,
                'chartPreviousClose': 200.0,
                'currency': 'EUR',
                'shortName': 'SAP SE',
              },
            },
          ],
        },
      }),
      200,
    );
  }
  return http.Response('', 404);
});

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  // Typische Handygröße, damit Überläufe auffallen.
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(db)),
        uidProvider.overrideWithValue('kevin'),
        httpClientProvider.overrideWithValue(mockHttp),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('households/h1').set({
      'name': 'Zuhause',
      'inviteCode': 'ABC123',
      'members': ['kevin', 'fritzi'],
      'memberNames': {'kevin': 'Dudu', 'fritzi': 'Bubu'},
      'togetherSince': Timestamp.fromDate(DateTime(2022, 5, 1)),
      'weatherPlace': {'name': 'Leipzig, Sachsen', 'lat': 51.3, 'lng': 12.4},
      'stocks': ['SAP.DE'],
    });
    final now = DateTime.now();
    final store = HouseholdStore(db, 'h1', 'kevin');
    await store.add('tasks', {
      'title': 'Bad putzen',
      'assignee': 'fritzi',
      'due': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'repeat': 'weekly',
      'points': 2,
      'done': false,
    });
    await store.add('events', {
      'title': 'Kino',
      'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1)),
      'time': '20:00',
      'who': '',
      'yearly': false,
    });
    await store.add('expenses', {
      'title': 'Wocheneinkauf',
      'amountCents': 4000,
      'paidBy': 'kevin',
      'split': 'half',
      'category': 'Lebensmittel',
      'date': Timestamp.fromDate(now),
    });
    await store.add('contracts', {
      'name': 'Strom',
      'costCents': 9000,
      'interval': 'monthly',
      'cancelBy': Timestamp.fromDate(now.add(const Duration(days: 10))),
    });
    await store.add('care', {
      'name': 'Monstera',
      'kind': 'plant',
      'action': 'Gießen',
      'intervalDays': 7,
    });
    await store.add('pantry', {'name': 'Nudeln', 'level': 'low'});
    await store.add('notes', {
      'title': 'WLAN',
      'body': 'geheim',
      'pinned': true,
    });
    await store.add('trips', {
      'name': 'Ostsee',
      'packing': [
        {'text': 'Badehose', 'done': false},
      ],
    });
    await store.add('ideas', {
      'text': 'Picknick',
      'kind': 'date',
      'done': false,
    });
    await store.addToShoppingList('Milch');
    await store.add('recipes', {
      'title': 'Pfannkuchen',
      'ingredients': ['Mehl', 'Milch'],
      'instructions': '',
    });
  });

  testWidgets('Startseite zeigt Wetter, Aufgaben, Termine, Geld und Aktien', (
    tester,
  ) async {
    await pumpPage(
      tester,
      DashboardScreen(householdId: 'h1', onOpenTab: (_) {}, onOpenPage: (_) {}),
    );
    expect(find.textContaining('Dudu'), findsWidgets);
    Future<void> see(Finder f) async {
      await tester.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(f, findsOneWidget);
    }

    await see(find.text('11°'));
    await see(find.textContaining('Bad putzen'));
    await see(find.textContaining('Kino'));
    await see(find.textContaining('Bubu schuldet Dudu 20,00 €'));
    await see(find.textContaining('Strom kündigen bis'));
    await see(find.text('+10,00 %'));
    await see(find.textContaining('Tage zusammen'));
  });

  testWidgets('Ganze App-Navigation mit allen Tabs', (tester) async {
    await pumpPage(tester, const HomeScreen(householdId: 'h1'));
    for (final tab in ['Einkauf', 'Haushalt', 'Kalender', 'Mehr', 'Start']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  final pages = <String, (Widget, String)>{
    'Haushalt': (const TasksScreen(householdId: 'h1'), 'Bad putzen'),
    'Kalender': (const CalendarScreen(householdId: 'h1'), 'Kino'),
    'Finanzen': (const FinanceScreen(householdId: 'h1'), 'Wocheneinkauf'),
    'Verträge': (const ContractsScreen(householdId: 'h1'), 'Strom'),
    'Essensplan': (
      const MealPlanScreen(householdId: 'h1'),
      'Noch nichts geplant',
    ),
    'Notizen': (const NotesScreen(householdId: 'h1'), 'WLAN'),
    'Vorräte': (const PantryScreen(householdId: 'h1'), 'Nudeln'),
    'Reisen': (const TripsScreen(householdId: 'h1'), 'Ostsee'),
    'Pflege': (const CareScreen(householdId: 'h1'), 'Monstera: Gießen'),
    'Wir': (const HouseholdScreen(householdId: 'h1'), 'Date-Ideen'),
    'Ideen': (
      const IdeasScreen(householdId: 'h1', kind: IdeaKind.date),
      'Picknick',
    ),
    'Standort': (
      const LocationScreen(householdId: 'h1'),
      'Meinen Standort teilen',
    ),
    'Mehr': (const MoreScreen(householdId: 'h1'), 'Tiere & Pflanzen'),
    'Rezepte': (const RecipesScreen(householdId: 'h1'), 'Pfannkuchen'),
    'Einrichten': (
      const DashboardSettingsScreen(householdId: 'h1'),
      'Leipzig, Sachsen',
    ),
  };
  for (final entry in pages.entries) {
    testWidgets('Seite ${entry.key} zeigt ihre Daten', (tester) async {
      await pumpPage(tester, entry.value.$1);
      expect(find.textContaining(entry.value.$2), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  final editPages = <String, Widget>{
    'Aufgabe': const TaskEditScreen(householdId: 'h1'),
    'Termin': const EventEditScreen(householdId: 'h1'),
    'Ausgabe': const ExpenseEditScreen(householdId: 'h1'),
    'Vertrag': const ContractEditScreen(householdId: 'h1'),
    'Notiz': const NoteEditScreen(householdId: 'h1'),
    'Vorrat': const PantryEditScreen(householdId: 'h1'),
    'Reise': const TripEditScreen(householdId: 'h1'),
    'Pflege': const CareEditScreen(householdId: 'h1'),
  };
  for (final entry in editPages.entries) {
    testWidgets('Neu-Formular ${entry.key} öffnet', (tester) async {
      await pumpPage(tester, entry.value);
      expect(find.text('Speichern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Aufgabe anlegen über das Formular', (tester) async {
    await pumpPage(tester, const TaskEditScreen(householdId: 'h1'));
    await tester.enterText(find.byType(TextField).first, 'Fenster putzen');
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    final tasks = await db.collection('households/h1/tasks').get();
    expect(
      tasks.docs.map((d) => d.data()['title']),
      contains('Fenster putzen'),
    );
  });

  testWidgets('Ausgabe anlegen über das Formular', (tester) async {
    await pumpPage(tester, const ExpenseEditScreen(householdId: 'h1'));
    await tester.enterText(find.byType(TextField).at(0), 'Pizza');
    await tester.enterText(find.byType(TextField).at(1), '23,40');
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    final docs = (await db.collection('households/h1/expenses').get()).docs;
    final pizza = docs.firstWhere((d) => d.data()['title'] == 'Pizza').data();
    expect(pizza['amountCents'], 2340);
    expect(pizza['paidBy'], 'kevin');
  });

  testWidgets('Packliste abhaken', (tester) async {
    final id = (await db.collection('households/h1/trips').get()).docs.first.id;
    await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
    await tester.tap(find.text('Badehose'));
    await tester.pump(const Duration(milliseconds: 100));
    final trip = (await db.doc('households/h1/trips/$id').get()).data()!;
    expect((trip['packing'] as List).first['done'], isTrue);
  });

  testWidgets('Fehlende Vorräte auf die Einkaufsliste', (tester) async {
    await pumpPage(tester, const PantryScreen(householdId: 'h1'));
    await tester.tap(find.textContaining('auf die Einkaufsliste'));
    await tester.pump(const Duration(milliseconds: 100));
    final items =
        (await db.collection('households/h1/shoppingItems').get()).docs;
    expect(
      items.map((d) => d.data()['text']),
      containsAll(['Milch', 'Nudeln']),
    );
  });
}
