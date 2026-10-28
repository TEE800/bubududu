import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({required this.displayName, this.householdId});

  final String displayName;
  final String? householdId;

  factory UserProfile.fromMap(Map<String, dynamic> data) => UserProfile(
    displayName: data['displayName'] as String? ?? '',
    householdId: data['householdId'] as String?,
  );
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
  });

  final String id;
  final String text;
  final bool done;
  final String addedBy;

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
  });

  final String id;
  final String title;
  final List<String> ingredients;
  final String instructions;
  final String addedBy;

  factory Recipe.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Recipe(
      id: doc.id,
      title: data['title'] as String? ?? '',
      ingredients: List<String>.from(data['ingredients'] as List? ?? const []),
      instructions: data['instructions'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
    );
  }
}
