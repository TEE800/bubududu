import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline.dart';
import 'providers.dart';

/// Ein Dokument aus einer Unter-Sammlung des Haushalts.
class Doc {
  const Doc(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

typedef CollectionKey = ({String householdId, String collection});

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Die eigene Nutzer-ID ('' wenn nicht angemeldet).
final uidProvider = Provider<String>(
  (ref) => ref.watch(authStateProvider).value?.uid ?? '',
);

/// Alle Dokumente von households/{householdId}/{collection}, live.
/// Sortiert wird in den einzelnen Bereichen, damit keine Firestore-Indizes nötig sind.
final collectionProvider = StreamProvider.family<List<Doc>, CollectionKey>((
  ref,
  key,
) {
  return ref
      .watch(firestoreProvider)
      .collection('households/${key.householdId}/${key.collection}')
      .snapshots()
      .map((s) => [for (final d in s.docs) Doc(d.id, d.data())]);
});

/// Das Haushalts-Dokument selbst als Rohdaten (z. B. für "Zusammen seit").
final householdDataProvider =
    StreamProvider.family<Map<String, dynamic>, String>(
      (ref, id) => ref
          .watch(firestoreProvider)
          .doc('households/$id')
          .snapshots()
          .map((s) => s.data() ?? const {}),
    );

final storeProvider = Provider.family<HouseholdStore, String>(
  (ref, householdId) => HouseholdStore(
    ref.watch(firestoreProvider),
    householdId,
    ref.watch(uidProvider),
  ),
);

/// Schreibzugriffe auf die Unter-Sammlungen eines Haushalts.
class HouseholdStore {
  HouseholdStore(this._db, this.householdId, this.uid);

  final FirebaseFirestore _db;
  final String householdId;
  final String uid;

  FirebaseFirestore get firestore => _db;

  CollectionReference<Map<String, dynamic>> col(String name) =>
      _db.collection('households/$householdId/$name');

  // Alle Schreibzugriffe warten nicht auf den Server, siehe offline.dart.
  Future<void> add(String collection, Map<String, dynamic> data) =>
      writeInBackground(
        col(collection).doc().set({
          ...data,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );

  Future<void> update(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) => writeInBackground(col(collection).doc(id).update(data));

  /// Legt an ([id] == null) oder aktualisiert.
  Future<void> save(String collection, String? id, Map<String, dynamic> data) =>
      id == null ? add(collection, data) : update(collection, id, data);

  Future<void> set(String collection, String id, Map<String, dynamic> data) =>
      writeInBackground(
        col(collection).doc(id).set(data, SetOptions(merge: true)),
      );

  Future<void> delete(String collection, String id) =>
      writeInBackground(col(collection).doc(id).delete());

  Future<void> updateHousehold(Map<String, dynamic> data) =>
      writeInBackground(_db.doc('households/$householdId').update(data));

  /// Setzt einen Eintrag auf die Einkaufsliste (gleiches Format wie dort).
  Future<void> addToShoppingList(String text) => writeInBackground(
    col('shoppingItems').doc().set({
      'text': text,
      'done': false,
      'addedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );
}
