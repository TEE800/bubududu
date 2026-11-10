import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    this.householdId,
    this.notify = const {},
  });

  final String displayName;
  final String? householdId;

  /// Benachrichtigungs-Einstellungen, siehe [NotifyKind].
  final Map<String, bool> notify;

  bool wants(NotifyKind kind) => notify[kind.name] ?? true;

  factory UserProfile.fromMap(Map<String, dynamic> data) => UserProfile(
    displayName: data['displayName'] as String? ?? '',
    householdId: data['householdId'] as String?,
    notify: Map<String, bool>.from(data['notify'] as Map? ?? const {}),
  );
}

/// Arten von Benachrichtigungen, die man einzeln abschalten kann.
/// Die Namen stehen so auch in Firestore (users/{uid}.notify) und in functions/.
enum NotifyKind {
  /// Termine, Aufgaben, Fristen, Pflege – plant das Handy selbst.
  reminders,

  /// Wenn der Partner etwas einträgt – kommt als Push vom Server.
  partner,
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    required this.memberNames,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;
  final Map<String, String> memberNames;

  factory Household.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Household(
      id: doc.id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? const []),
      memberNames: Map<String, String>.from(
        data['memberNames'] as Map? ?? const {},
      ),
    );
  }
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.done,
    required this.addedBy,
    this.pending = false,
    this.pantryUndo,
  });

  final String id;
  final String text;
  final bool done;
  final String addedBy;

  /// Beim Abhaken in die Vorräte gebucht: was rückgängig zu machen ist.
  final Map<String, dynamic>? pantryUndo;

  /// Offline geändert und noch nicht beim Server angekommen.
  final bool pending;

  factory ShoppingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShoppingItem(
      id: doc.id,
      text: data['text'] as String? ?? '',
      done: data['done'] as bool? ?? false,
      addedBy: data['addedBy'] as String? ?? '',
      pending: doc.metadata.hasPendingWrites,
      pantryUndo: data['pantryUndo'] is Map
          ? Map<String, dynamic>.from(data['pantryUndo'] as Map)
          : null,
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    required this.addedBy,
    this.imageUrl,
    this.imagePage,
  });

  final String id;
  final String title;
  final List<String> ingredients;
  final String instructions;
  final String addedBy;

  /// Automatisch gefundenes Bild des Gerichts (Wikipedia). null = noch nicht
  /// gesucht, '' = gesucht, aber nichts Passendes gefunden. Ein eigenes Foto
  /// liegt getrennt in households/{id}/recipePhotos/{recipeId}.
  final String? imageUrl;

  /// Wikipedia-Artikel, aus dem [imageUrl] stammt.
  final String? imagePage;

  factory Recipe.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Recipe(
      id: doc.id,
      title: data['title'] as String? ?? '',
      ingredients: List<String>.from(data['ingredients'] as List? ?? const []),
      instructions: data['instructions'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      imagePage: data['imagePage'] as String?,
    );
  }
}
