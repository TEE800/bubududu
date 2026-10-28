import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'household_repository.dart';
import 'models.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(FirebaseFirestore.instance),
);

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(householdRepositoryProvider).watchProfile(user.uid);
});

final householdProvider = StreamProvider.family<Household, String>(
  (ref, id) => ref.watch(householdRepositoryProvider).watchHousehold(id),
);

final shoppingItemsProvider = StreamProvider.family<List<ShoppingItem>, String>(
  (ref, householdId) =>
      ref.watch(householdRepositoryProvider).watchShoppingItems(householdId),
);

final recipesProvider = StreamProvider.family<List<Recipe>, String>(
  (ref, householdId) =>
      ref.watch(householdRepositoryProvider).watchRecipes(householdId),
);
