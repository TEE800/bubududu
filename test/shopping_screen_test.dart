import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/providers.dart';
import 'package:bubududu/data/store.dart';
import 'package:bubududu/screens/shopping_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Eintrag über das X löschen', (tester) async {
    final db = FakeFirebaseFirestore();
    final repo = HouseholdRepository(db);
    await repo.addShoppingItem('h1', 'Milch', 'kevin');
    await repo.addShoppingItem('h1', 'Brot', 'kevin');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          householdRepositoryProvider.overrideWithValue(repo),
          householdProvider.overrideWith((ref, id) => const Stream.empty()),
        ],
        child: const MaterialApp(home: ShoppingScreen(householdId: 'h1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milch'), findsOneWidget);

    await tester.tap(find.byTooltip('Löschen').first);
    await tester.pumpAndSettle();

    expect(find.text('Milch'), findsNothing);
    expect(find.text('Brot'), findsOneWidget);
  });

  testWidgets('Menge eingeben, anzeigen und ändern', (tester) async {
    final db = FakeFirebaseFirestore();
    final repo = HouseholdRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          householdRepositoryProvider.overrideWithValue(repo),
          householdProvider.overrideWith((ref, id) => const Stream.empty()),
        ],
        child: const MaterialApp(home: ShoppingScreen(householdId: 'h1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Mehl');
    await tester.enterText(find.byType(TextField).at(1), '500 g');
    await tester.tap(find.byTooltip('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('Mehl'), findsOneWidget);
    expect(find.text('500 g'), findsOneWidget);
    var docs = (await db.collection('households/h1/shoppingItems').get()).docs;
    expect(docs.single.data()['text'], 'Mehl');
    expect(docs.single.data()['amount'], '500 g');

    // Ohne Menge: kein Feld.
    await tester.enterText(find.byType(TextField).first, 'Brot');
    await tester.tap(find.byTooltip('Hinzufügen'));
    await tester.pumpAndSettle();
    docs = (await db.collection('households/h1/shoppingItems').get()).docs;
    final brot = docs.firstWhere((d) => d.data()['text'] == 'Brot');
    expect(brot.data().containsKey('amount'), isFalse);

    // Lange drücken: Menge ändern.
    await tester.longPress(find.text('Mehl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name und Menge ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Menge (optional)'),
      '1 kg',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('500 g'), findsNothing);
  });
}
