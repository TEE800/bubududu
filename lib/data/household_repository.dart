import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// Alle Lese- und Schreibzugriffe auf Firestore für Haushalt und Einkauf.
///
/// Struktur:
///   users/{uid}                         Profil + householdId
///   invites/{code}                      verweist auf einen Haushalt
///   households/{id}                     Name, Mitglieder, Einladungscode
///   households/{id}/shoppingItems/{id}  Einträge der Einkaufsliste
class HouseholdRepository {
  HouseholdRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.doc('users/$uid');
  DocumentReference<Map<String, dynamic>> _household(String id) =>
      _db.doc('households/$id');
  CollectionReference<Map<String, dynamic>> _items(String householdId) =>
      _household(householdId).collection('shoppingItems');

  Stream<UserProfile?> watchProfile(String uid) =>
      _user(uid)
          .snapshots()
          .map((s) => s.data() == null ? null : UserProfile.fromMap(s.data()!));

  Future<void> createProfile(String uid, String displayName) =>
      _user(uid).set({'displayName': displayName}, SetOptions(merge: true));

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
    final invite = await _db.doc('invites/${code.trim().toUpperCase()}').get();
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
          .snapshots()
          .map((s) => s.docs.map(ShoppingItem.fromDoc).toList());

  Future<void> addShoppingItem(String householdId, String text, String uid) =>
      _items(householdId).add({
        'text': text,
        'done': false,
        'addedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> setShoppingItemDone(
    String householdId,
    String itemId,
    bool done,
  ) => _items(householdId).doc(itemId).update({'done': done});

  Future<void> deleteShoppingItem(String householdId, String itemId) =>
      _items(householdId).doc(itemId).delete();

  Future<void> clearDoneItems(String householdId) async {
    final done = await _items(householdId).where('done', isEqualTo: true).get();
    final batch = _db.batch();
    for (final doc in done.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Ohne 0/O und 1/I, damit der Code leicht abzutippen ist.
  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
