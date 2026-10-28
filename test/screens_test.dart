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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    await seedHousehold();
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
