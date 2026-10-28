import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/contracts.dart';
import 'package:bubududu/features/notes.dart';
import 'package:bubududu/features/pantry.dart';
import 'package:bubududu/features/trips.dart';
import 'package:bubududu/screens/recipes_screen.dart';
import 'package:bubududu/screens/settings_screen.dart';
import 'package:bubududu/screens/shopping_screen.dart';
import 'package:bubududu/util/recipe_parser.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Ablauf-Tests pro Bereich: anlegen, ändern, löschen über die Oberfläche.
void main() {
  setUp(() async {
    db = FakeFirebaseFirestore();
    await seedHousehold();
  });

  Future<List<Map<String, dynamic>>> docs(String collection) async => [
    for (final d
        in (await db.collection('households/h1/$collection').get()).docs)
      d.data(),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextField, label), text);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Speichern'));
    await settle(tester);
  }

  group('Einkauf', () {
    testWidgets('Eintrag hinzufügen, abhaken, Erledigte löschen', (
      tester,
    ) async {
      await pumpPage(tester, const ShoppingScreen(householdId: 'h1'));
      await tester.enterText(find.byType(TextField), 'Käse');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Käse'), findsOneWidget);
      expect((await docs('shoppingItems')).last['addedBy'], 'kevin');

      await tester.tap(find.text('Käse'));
      await settle(tester);
      await tester.tap(find.text('Erledigte löschen'));
      await settle(tester);
      expect(find.text('Käse'), findsNothing);
      expect(find.text('Milch'), findsOneWidget);
    });

    testWidgets('Leere Eingabe legt nichts an', (tester) async {
      await pumpPage(tester, const ShoppingScreen(householdId: 'h1'));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(await docs('shoppingItems'), hasLength(1));
    });
  });

  group('Rezepte', () {
    testWidgets('Rezept anlegen', (tester) async {
      await pumpPage(tester, const RecipeEditScreen(householdId: 'h1'));
      await fill(tester, 'Name', 'Kartoffelsuppe');
      await fill(tester, 'Zutaten', 'Kartoffeln\n\nLauch\n  Brühe ');
      await save(tester);
      final soup = (await docs('recipes'))
          .firstWhere((r) => r['title'] == 'Kartoffelsuppe');
      expect(soup['ingredients'], ['Kartoffeln', 'Lauch', 'Brühe']);
    });

    testWidgets('Gescanntes Rezept prüfen und speichern', (tester) async {
      await pumpPage(
        tester,
        const RecipeEditScreen(
          householdId: 'h1',
          draft: RecipeDraft(
            title: 'Pfannkuchen vom Foto',
            ingredients: ['250 g Mehl', '3 Eier'],
            instructions: 'Verrühren.',
          ),
        ),
      );
      expect(find.text('Aus dem Foto erkannt'), findsOneWidget);
      await fill(tester, 'Name', 'Omas Pfannkuchen');
      await save(tester);
      final saved = (await docs('recipes'))
          .firstWhere((r) => r['title'] == 'Omas Pfannkuchen');
      expect(saved['ingredients'], ['250 g Mehl', '3 Eier']);
      expect(saved['instructions'], 'Verrühren.');
    });

    testWidgets('Zutaten auf die Einkaufsliste', (tester) async {
      final id =
          (await db.collection('households/h1/recipes').get()).docs.single.id;
      await pumpPage(
        tester,
        RecipeDetailScreen(householdId: 'h1', recipeId: id),
      );
      await tester.tap(find.text('Zutaten auf die Einkaufsliste'));
      await settle(tester);
      // Milch steht schon drauf und ist deshalb nicht vorausgewählt.
      expect(find.text('steht schon auf der Liste'), findsOneWidget);
      await tester.tap(find.text('1 auf die Einkaufsliste'));
      await settle(tester);
      final texts = (await docs('shoppingItems')).map((d) => d['text']);
      expect(texts, ['Milch', 'Mehl']);
    });

    testWidgets('Rezept löschen', (tester) async {
      final id =
          (await db.collection('households/h1/recipes').get()).docs.single.id;
      await pumpPage(
        tester,
        RecipeDetailScreen(householdId: 'h1', recipeId: id),
      );
      await tester.tap(find.byTooltip('Löschen'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await settle(tester);
      expect(await docs('recipes'), isEmpty);
    });
  });

  group('Kalender', () {
    testWidgets('Termin anlegen', (tester) async {
      await pumpPage(tester, const EventEditScreen(householdId: 'h1'));
      await fill(tester, 'Was?', 'Zahnarzt');
      await save(tester);
      final event = (await docs('events'))
          .firstWhere((e) => e['title'] == 'Zahnarzt');
      expect(event['createdBy'], 'kevin');
      expect(event['date'], isNotNull);
    });

    testWidgets('Termin ohne Namen wird nicht gespeichert', (tester) async {
      await pumpPage(tester, const EventEditScreen(householdId: 'h1'));
      await save(tester);
      expect(find.text('Bitte gib dem Termin einen Namen.'), findsOneWidget);
      expect(await docs('events'), hasLength(1));
    });
  });

  group('Verträge', () {
    testWidgets('Vertrag mit Betrag anlegen', (tester) async {
      await pumpPage(tester, const ContractEditScreen(householdId: 'h1'));
      await fill(tester, 'Was?', 'Internet');
      await fill(tester, 'Betrag', '39,99');
      await save(tester);
      final c = (await docs('contracts'))
          .firstWhere((c) => c['name'] == 'Internet');
      expect(c['costCents'], 3999);
    });

    testWidgets('Falscher Betrag gibt einen Hinweis', (tester) async {
      await pumpPage(tester, const ContractEditScreen(householdId: 'h1'));
      await fill(tester, 'Was?', 'Internet');
      await fill(tester, 'Betrag', 'viel');
      await save(tester);
      expect(find.textContaining('Bitte gib einen Betrag ein'), findsOneWidget);
    });
  });

  group('Notizen', () {
    testWidgets('Notiz anlegen', (tester) async {
      await pumpPage(tester, const NoteEditScreen(householdId: 'h1'));
      await fill(tester, 'Titel', 'Mülltage');
      await fill(tester, 'Inhalt', 'Gelb: Dienstag');
      await save(tester);
      final note = (await docs('notes'))
          .firstWhere((n) => n['title'] == 'Mülltage');
      expect(note['body'], 'Gelb: Dienstag');
    });
  });

  group('Vorräte', () {
    testWidgets('Vorrat anlegen', (tester) async {
      await pumpPage(tester, const PantryEditScreen(householdId: 'h1'));
      await fill(tester, 'Was?', 'Reis');
      await fill(tester, 'Wo? (optional)', 'Keller');
      await save(tester);
      final rice = (await docs('pantry'))
          .firstWhere((p) => p['name'] == 'Reis');
      expect(rice['place'], 'Keller');
    });
  });

  group('Reisen', () {
    testWidgets('Reise anlegen', (tester) async {
      await pumpPage(tester, const TripEditScreen(householdId: 'h1'));
      await fill(tester, 'Wohin?', 'Harz');
      await save(tester);
      expect((await docs('trips')).map((t) => t['name']), contains('Harz'));
    });

    testWidgets('Packliste ergänzen', (tester) async {
      final id =
          (await db.collection('households/h1/trips').get()).docs.single.id;
      await pumpPage(tester, TripDetailScreen(householdId: 'h1', tripId: id));
      await tester.enterText(
        find.widgetWithText(TextField, 'Was muss mit?'),
        'Sonnencreme',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      final packing =
          (await db.doc('households/h1/trips/$id').get()).data()!['packing']
              as List;
      expect(packing.map((p) => p['text']), contains('Sonnencreme'));
    });
  });

  group('Tiere & Pflanzen', () {
    testWidgets('Pflege anlegen', (tester) async {
      await pumpPage(tester, const CareEditScreen(householdId: 'h1'));
      await fill(tester, 'Name', 'Kaktus');
      await fill(tester, 'Was ist zu tun?', 'Gießen');
      await fill(tester, 'Alle wie viele Tage?', '14');
      await save(tester);
      final cactus = (await docs('care'))
          .firstWhere((c) => c['name'] == 'Kaktus');
      expect(cactus['intervalDays'], 14);
    });

    testWidgets('Als erledigt markieren merkt sich wer und wann', (
      tester,
    ) async {
      await pumpPage(tester, const CareScreen(householdId: 'h1'));
      await tester.tap(find.byTooltip('Erledigt'));
      await settle(tester);
      final monstera = (await docs('care')).single;
      expect(monstera['lastBy'], 'kevin');
      expect(monstera['lastDone'], isNotNull);
    });
  });

  group('Einstellungen', () {
    testWidgets('Partner-Benachrichtigungen abschalten', (tester) async {
      await db.doc('users/kevin').set({'displayName': 'Dudu'});
      await pumpPage(tester, const SettingsScreen(householdId: 'h1'));
      expect(find.text('Wenn Bubu etwas einträgt'), findsOneWidget);
      await tester.tap(find.text('Wenn Bubu etwas einträgt'));
      await settle(tester);
      final user = (await db.doc('users/kevin').get()).data()!;
      expect(user['notify'], {'partner': false});
      expect(user['displayName'], 'Dudu');
    });
  });
}
