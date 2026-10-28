import 'package:flutter/material.dart';

import '../features/care.dart';
import '../features/contracts.dart';
import '../features/finance.dart';
import '../features/health.dart';
import '../features/meals.dart';
import '../features/notes.dart';
import '../features/pantry.dart';
import '../features/trips.dart';
import 'household_screen.dart';
import 'recipes_screen.dart';

typedef MoreEntry = ({
  String label,
  IconData icon,
  Widget Function(String) page,
});

final moreEntries = <MoreEntry>[
  (
    label: 'Finanzen',
    icon: Icons.euro,
    page: (id) => FinanceScreen(householdId: id),
  ),
  (
    label: 'Essensplan',
    icon: Icons.restaurant_outlined,
    page: (id) => MealPlanScreen(householdId: id),
  ),
  (
    label: 'Rezepte',
    icon: Icons.menu_book_outlined,
    page: (id) => RecipesScreen(householdId: id),
  ),
  (
    label: 'Gesundheit',
    icon: Icons.health_and_safety_outlined,
    page: (id) => HealthScreen(householdId: id),
  ),
  (
    label: 'Notizen',
    icon: Icons.sticky_note_2_outlined,
    page: (id) => NotesScreen(householdId: id),
  ),
  (
    label: 'Vorräte',
    icon: Icons.kitchen_outlined,
    page: (id) => PantryScreen(householdId: id),
  ),
  (
    label: 'Verträge',
    icon: Icons.description_outlined,
    page: (id) => ContractsScreen(householdId: id),
  ),
  (
    label: 'Reisen',
    icon: Icons.luggage_outlined,
    page: (id) => TripsScreen(householdId: id),
  ),
  (
    label: 'Tiere & Pflanzen',
    icon: Icons.local_florist_outlined,
    page: (id) => CareScreen(householdId: id),
  ),
  (
    label: 'Wir',
    icon: Icons.favorite_outline,
    page: (id) => HouseholdScreen(householdId: id),
  ),
];

/// Tab "Mehr": alle weiteren Bereiche als Kacheln.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
        children: [
          for (final e in moreEntries)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => e.page(householdId))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(e.icon, size: 32, color: scheme.primary),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        e.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
