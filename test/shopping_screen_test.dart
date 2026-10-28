import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/providers.dart';
import 'package:bubududu/screens/shopping_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Eintrag über das X löschen', (tester) async {
    final repo = HouseholdRepository(FakeFirebaseFirestore());
    await repo.addShoppingItem('h1', 'Milch', 'kevin');
    await repo.addShoppingItem('h1', 'Brot', 'kevin');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
}
