import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'offline.dart';

/// Alle Lese- und Schreibzugriffe auf Firestore für Haushalt und Einkauf.
///
/// Struktur:
///   users/{uid}                         Profil + householdId
///   invites/{code}                      verweist auf einen Haushalt
///   households/{id}                     Name, Mitglieder, Einladungscode
///   households/{id}/shoppingItems/{id}  Einträge der Einkaufsliste
///   households/{id}/recipes/{id}        gemeinsame Rezepte
///   alexaCodes/{code}                   Code zum Verbinden mit Alexa
///   alexaLinks/{alexaUser}              verbundenes Amazon-Konto (functions/)
class HouseholdRepository {
  HouseholdRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.doc('users/$uid');
  DocumentReference<Map<String, dynamic>> _household(String id) =>
      _db.doc('households/$id');
  CollectionReference<Map<String, dynamic>> _items(String householdId) =>
      _household(householdId).collection('shoppingItems');
  CollectionReference<Map<String, dynamic>> _recipes(String householdId) =>
      _household(householdId).collection('recipes');

  Stream<UserProfile?> watchProfile(String uid) =>
      _user(uid)
          .snapshots()
          .map((s) => s.data() == null ? null : UserProfile.fromMap(s.data()!));

  Future<void> createProfile(String uid, String displayName) =>
      _user(uid).set({'displayName': displayName}, SetOptions(merge: true));

  Future<void> setNotify(String uid, NotifyKind kind, bool on) =>
      writeInBackground(
        _user(uid).set({
          'notify': {kind.name: on},
        }, SetOptions(merge: true)),
      );

  /// Merkt sich das Gerät für Push-Nachrichten.
  Future<void> addPushToken(String uid, String token) => writeInBackground(
    _user(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true)),
  );

  Future<void> removePushToken(String uid, String token) => writeInBackground(
    _user(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true)),
  );

  Stream<Household> watchHousehold(String id) =>
      _household(id).snapshots().map(Household.fromDoc);

  Future<void> createHousehold({
    required String uid,
    required String displayName,
    required String name,
  }) async {
    final code = _randomCode();
    final householdRef = _db.collection('households').doc();
    final batch = _db.batch()
      ..set(householdRef, {
        'name': name,
        'inviteCode': code,
        'members': [uid],
        'memberNames': {uid: displayName},
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.doc('invites/$code'), {
        'householdId': householdRef.id,
        'createdBy': uid,
      })
      ..set(_user(uid), {
        'householdId': householdRef.id,
      }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Tritt einem Haushalt per Einladungscode bei. Wirft [StateError] mit
  /// einer deutschen Meldung, wenn der Code ungültig oder der Haushalt voll ist.
  Future<void> joinHousehold({
    required String uid,
    required String displayName,
    required String code,
  }) async {
    final clean = code.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(clean)) {
      throw StateError('Der Code hat 6 Zeichen, z. B. K7M2QX.');
    }
    final invite = await _db.doc('invites/$clean').get();
    final householdId = invite.data()?['householdId'] as String?;
    if (householdId == null) {
      throw StateError('Diesen Einladungscode gibt es nicht.');
    }
    final batch = _db.batch()
      ..update(_household(householdId), {
        'members': FieldValue.arrayUnion([uid]),
        'memberNames.$uid': displayName,
      })
      ..set(_user(uid), {'householdId': householdId}, SetOptions(merge: true));
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError('Dieser Haushalt hat schon zwei Mitglieder.');
      }
      rethrow;
    }
  }

  Stream<List<ShoppingItem>> watchShoppingItems(String householdId) =>
      _items(householdId)
          .orderBy('createdAt')
          .snapshots(includeMetadataChanges: true)
          .map((s) => s.docs.map(ShoppingItem.fromDoc).toList());

  // Einkauf und Rezepte warten nicht auf den Server, damit sie offline
  // funktionieren (siehe offline.dart). Haushalt anlegen/beitreten braucht Netz.
  Future<void> addShoppingItem(
    String householdId,
    String text,
    String uid, {
    bool done = false,
  }) => writeInBackground(
    _items(householdId).doc().set({
      'text': text,
      'done': done,
      'addedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Legt mehrere Einträge auf einmal an, z. B. die Zutaten eines Rezepts.
  Future<void> addShoppingItems(
    String householdId,
    List<String> texts,
    String uid,
  ) {
    final batch = _db.batch();
    for (final text in texts) {
      batch.set(_items(householdId).doc(), {
        'text': text,
        'done': false,
        'addedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return writeInBackground(batch.commit());
  }

  Future<void> setShoppingItemDone(
    String householdId,
    String itemId,
    bool done,
  ) =>
      writeInBackground(_items(householdId).doc(itemId).update({'done': done}));

  Future<void> deleteShoppingItem(String householdId, String itemId) =>
      writeInBackground(_items(householdId).doc(itemId).delete());

  /// Löscht die angezeigten erledigten Einträge. Bekommt die IDs von der
  /// Liste, statt neu abzufragen, damit es auch ohne Netz sofort klappt.
  Future<void> clearDoneItems(String householdId, List<String> itemIds) {
    final batch = _db.batch();
    for (final id in itemIds) {
      batch.delete(_items(householdId).doc(id));
    }
    return writeInBackground(batch.commit());
  }

  Stream<List<Recipe>> watchRecipes(String householdId) => _recipes(householdId)
      .snapshots()
      .map(
        (s) => s.docs.map(Recipe.fromDoc).toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          ),
      );

  /// Legt ein Rezept an ([recipeId] == null) oder überschreibt ein bestehendes.
  Future<void> saveRecipe(
    String householdId, {
    String? recipeId,
    required String title,
    required List<String> ingredients,
    required String instructions,
    required String uid,
  }) {
    final data = {
      'title': title,
      'ingredients': ingredients,
      'instructions': instructions,
    };
    if (recipeId == null) {
      return writeInBackground(
        _recipes(householdId).doc().set({
          ...data,
          'addedBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    return writeInBackground(_recipes(householdId).doc(recipeId).update(data));
  }

  Future<void> deleteRecipe(String householdId, String recipeId) =>
      writeInBackground(_recipes(householdId).doc(recipeId).delete());

  /// Legt einen sechsstelligen Code an, den man Alexa sagt, um den Skill
  /// "Bubu Dudu" mit diesem Haushalt zu verbinden. 15 Minuten gültig.
  /// Braucht Netz, weil Alexa den Code sofort auf dem Server sucht.
  Future<String> createAlexaCode(String householdId, String uid) async {
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = (100000 + rnd.nextInt(900000)).toString();
      try {
        // Ein schon vergebener Code wäre ein Update und wird abgelehnt.
        await _db.doc('alexaCodes/$code').set({
          'uid': uid,
          'householdId': householdId,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 15)),
          ),
        });
        return code;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    throw StateError('Gerade kein Code möglich. Versuch es gleich nochmal.');
  }

  /// Wie viele Amazon-Konten mit dieser Person verbunden sind.
  Stream<int> watchAlexaLinks(String uid) => _db
      .collection('alexaLinks')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> unlinkAlexa(String uid) async {
    final links = await _db
        .collection('alexaLinks')
        .where('uid', isEqualTo: uid)
        .get();
    await Future.wait(links.docs.map((d) => d.reference.delete()));
  }

  // Ohne 0/O und 1/I, damit der Code leicht abzutippen ist.
  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
