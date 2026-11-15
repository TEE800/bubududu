import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/models.dart';
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

  test('Bubu ist als Platzhalter wählbar, solange er nicht beigetreten ist',
      () async {
    await repo.createHousehold(
      uid: 'kevin',
      displayName: 'Dudu',
      name: 'Zuhause',
    );
    final householdId =
        (await db.doc('users/kevin').get()).data()!['householdId'] as String;
    final alone = await repo.watchHousehold(householdId).first;
    expect(alone.people, ['kevin', kPartnerPlaceholder]);
    expect(alone.peopleNames, {'kevin': 'Dudu', kPartnerPlaceholder: 'Bubu'});

    await db.doc('households/$householdId/expenses/e1').set({
      'title': 'Pizza',
      'paidBy': kPartnerPlaceholder,
      'amountCents': 1200,
    });
    await db.doc('households/$householdId/contracts/c1').set({
      'name': 'Strom',
      'paidBy': 'kevin',
    });
    await db.doc('households/$householdId/trips/t1').set({
      'packing': [
        {'text': 'Zelt', 'who': kPartnerPlaceholder},
      ],
    });

    await repo.joinHousehold(
      uid: 'fritzi',
      displayName: 'Bubu',
      code: alone.inviteCode,
    );

    final both = await repo.watchHousehold(householdId).first;
    expect(both.people, ['kevin', 'fritzi']);
    expect(both.peopleNames, {'kevin': 'Dudu', 'fritzi': 'Bubu'});
    final expense = await db.doc('households/$householdId/expenses/e1').get();
    expect(expense.data()!['paidBy'], 'fritzi');
    expect(expense.data()!['title'], 'Pizza');
    final contract = await db.doc('households/$householdId/contracts/c1').get();
    expect(contract.data()!['paidBy'], 'kevin');
    final trip = await db.doc('households/$householdId/trips/t1').get();
    expect((trip.data()!['packing'] as List).first['who'], 'fritzi');
  });

  test('Platzhalter wird auch in Maps und Schlüsseln ersetzt', () {
    final data = {
      'a': 1,
      'shares': {kPartnerPlaceholder: 5, 'kevin': 3},
    };
    expect(replacePlaceholder(data, 'f'), {
      'a': 1,
      'shares': {'f': 5, 'kevin': 3},
    });
    final unchanged = {'paidBy': 'kevin'};
    expect(identical(replacePlaceholder(unchanged, 'f'), unchanged), isTrue);
  });

  test('Unbekannter Code wirft eine verständliche Meldung', () async {
    expect(
      () => repo.joinHousehold(uid: 'x', displayName: 'X', code: 'NOPE12'),
      throwsA(isA<StateError>()),
    );
  });

  test('Code mit falschem Format wird gar nicht erst gesucht', () async {
    for (final code in ['', 'AB', 'ABC/DE', 'ABCDEFG']) {
      expect(
        () => repo.joinHousehold(uid: 'x', displayName: 'X', code: code),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('6')),
        ),
      );
    }
  });

  test('Rezepte alphabetisch, egal ob groß oder klein', () async {
    for (final t in ['zucchini-Pfanne', 'Apfelkuchen', 'banane']) {
      await repo.saveRecipe(
        'h1',
        title: t,
        ingredients: const [],
        instructions: '',
        uid: 'kevin',
      );
    }
    await pumpEventQueue();
    final recipes = await repo.watchRecipes('h1').first;
    expect(recipes.map((r) => r.title), [
      'Apfelkuchen',
      'banane',
      'zucchini-Pfanne',
    ]);
  });

  test('Einkaufsliste: hinzufügen, abhaken, Erledigte entfernen', () async {
    await repo.addShoppingItem('h1', 'Milch', 'kevin');
    await repo.addShoppingItem('h1', 'Brot', 'kevin');

    var items = await repo.watchShoppingItems('h1').first;
    expect(items.map((i) => i.text), ['Milch', 'Brot']);

    await repo.setShoppingItemDone('h1', items.first.id, true);
    await repo.clearDoneItems('h1', [items.first.id]);
    await pumpEventQueue();

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

  test('Alexa: Code anlegen, Verbindung sehen und trennen', () async {
    final code = await repo.createAlexaCode('h1', 'kevin');
    expect(code, matches(RegExp(r'^[0-9]{6}$')));
    final saved = (await db.doc('alexaCodes/$code').get()).data()!;
    expect(saved['uid'], 'kevin');
    expect(saved['householdId'], 'h1');

    expect(await repo.watchAlexaLinks('kevin').first, 0);
    // Das Einlösen macht die Cloud Function.
    await db.doc('alexaLinks/amzn1').set({'uid': 'kevin', 'householdId': 'h1'});
    await db.doc('alexaLinks/amzn2').set({
      'uid': 'fritzi',
      'householdId': 'h1',
    });
    expect(await repo.watchAlexaLinks('kevin').first, 1);

    await repo.unlinkAlexa('kevin');
    expect(await repo.watchAlexaLinks('kevin').first, 0);
    expect((await db.doc('alexaLinks/amzn2').get()).exists, isTrue);
  });
}
