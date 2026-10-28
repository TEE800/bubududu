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
}
