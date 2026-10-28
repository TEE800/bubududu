import 'package:bubududu/data/household_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late HouseholdRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = HouseholdRepository(db);
  });

  test('Haushalt anlegen und per Code beitreten', () async {
    await repo.createHousehold(
      uid: 'kevin',
      displayName: 'Kevin',
      name: 'Zuhause',
    );

    final householdId =
        (await db.doc('users/kevin').get()).data()!['householdId'] as String;
    final household = await repo.watchHousehold(householdId).first;
    expect(household.members, ['kevin']);
    expect(household.inviteCode, hasLength(6));

    await repo.joinHousehold(
      uid: 'partner',
      displayName: 'Dudu',
      code: household.inviteCode.toLowerCase(),
    );

    final joined = await repo.watchHousehold(householdId).first;
    expect(joined.members, ['kevin', 'partner']);
    expect(joined.memberNames['partner'], 'Dudu');
    expect(
      (await db.doc('users/partner').get()).data()!['householdId'],
      householdId,
    );
  });

  test('Unbekannter Code wirft eine verständliche Meldung', () async {
    expect(
      () => repo.joinHousehold(uid: 'x', displayName: 'X', code: 'NOPE12'),
      throwsA(isA<StateError>()),
    );
  });

  test('Einkaufsliste: hinzufügen, abhaken, Erledigte entfernen', () async {
    await repo.addShoppingItem('h1', 'Milch', 'kevin');
    await repo.addShoppingItem('h1', 'Brot', 'kevin');

    var items = await repo.watchShoppingItems('h1').first;
    expect(items.map((i) => i.text), ['Milch', 'Brot']);

    await repo.setShoppingItemDone('h1', items.first.id, true);
    await repo.clearDoneItems('h1');

    items = await repo.watchShoppingItems('h1').first;
    expect(items.map((i) => i.text), ['Brot']);
  });

  test('Rezept anlegen, ändern und Zutaten auf die Einkaufsliste', () async {
    await repo.saveRecipe(
      'h1',
      title: 'Pfannkuchen',
      ingredients: ['Mehl', 'Milch', 'Eier'],
      instructions: 'Alles verrühren.',
      uid: 'kevin',
    );

    var recipes = await repo.watchRecipes('h1').first;
    expect(recipes.single.title, 'Pfannkuchen');
    expect(recipes.single.ingredients, ['Mehl', 'Milch', 'Eier']);

    await repo.saveRecipe(
      'h1',
      recipeId: recipes.single.id,
      title: 'Pfannkuchen',
      ingredients: ['Mehl', 'Milch', 'Eier', 'Zucker'],
      instructions: 'Alles verrühren.',
      uid: 'partner',
    );
    recipes = await repo.watchRecipes('h1').first;
    expect(recipes.single.ingredients, hasLength(4));
    expect(recipes.single.addedBy, 'kevin');

    await repo.addShoppingItems('h1', recipes.single.ingredients, 'partner');
    // Schreiben wartet nicht auf den Server; die Test-Datenbank braucht einen Moment.
    await pumpEventQueue();
    final items = await repo.watchShoppingItems('h1').first;
    expect(
      items.map((i) => i.text),
      unorderedEquals(['Mehl', 'Milch', 'Eier', 'Zucker']),
    );
    expect(items.every((i) => !i.done && i.addedBy == 'partner'), isTrue);

    await repo.deleteRecipe('h1', recipes.single.id);
    expect(await repo.watchRecipes('h1').first, isEmpty);
  });
}
