import 'package:flutter/material.dart';

import '../features/care.dart';
import '../features/contracts.dart';
import '../features/depot.dart';
import '../features/finance.dart';
import '../features/health.dart';
import '../features/meals.dart';
import '../features/notes.dart';
import '../features/pantry.dart';
import '../features/trips.dart';
import '../widgets/cute.dart';
import '../widgets/pic_tile.dart';
import 'household_screen.dart';
import 'recipes_screen.dart';
import 'settings_screen.dart';

typedef MoreEntry = ({
  String label,
  String emoji,
  CuteTone tone,
  IconData icon,
  Widget Function(String) page,
});

final moreEntries = <MoreEntry>[
  (
    label: 'Finanzen',
    emoji: '💶',
    tone: CuteTone.vanilla,
    icon: Icons.euro,
    page: (id) => FinanceScreen(householdId: id),
  ),
  (
    label: 'Mein Depot',
    emoji: '📈',
    tone: CuteTone.mint,
    icon: Icons.account_balance_wallet_outlined,
    page: (_) => const DepotScreen(),
  ),
  (
    label: 'Essensplan',
    emoji: '🍽️',
    tone: CuteTone.vanilla,
    icon: Icons.restaurant_outlined,
    page: (id) => MealPlanScreen(householdId: id),
  ),
  (
    label: 'Rezepte',
    emoji: '📖',
    tone: CuteTone.pink,
    icon: Icons.menu_book_outlined,
    page: (id) => RecipesScreen(householdId: id),
  ),
  (
    label: 'Gesundheit',
    emoji: '🩺',
    tone: CuteTone.pink,
    icon: Icons.health_and_safety_outlined,
    page: (id) => HealthScreen(householdId: id),
  ),
  (
    label: 'Notizen',
    emoji: '📌',
    tone: CuteTone.vanilla,
    icon: Icons.sticky_note_2_outlined,
    page: (id) => NotesScreen(householdId: id),
  ),
  (
    label: 'Vorräte',
    emoji: '🥫',
    tone: CuteTone.mint,
    icon: Icons.kitchen_outlined,
    page: (id) => PantryScreen(householdId: id),
  ),
  (
    label: 'Verträge',
    emoji: '📄',
    tone: CuteTone.vanilla,
    icon: Icons.description_outlined,
    page: (id) => ContractsScreen(householdId: id),
  ),
  (
    label: 'Reisen',
    emoji: '🧳',
    tone: CuteTone.pink,
    icon: Icons.luggage_outlined,
    page: (id) => TripsScreen(householdId: id),
  ),
  (
    label: 'Tiere & Pflanzen',
    emoji: '🪴',
    tone: CuteTone.mint,
    icon: Icons.local_florist_outlined,
    page: (id) => CareScreen(householdId: id),
  ),
  (
    label: 'Wir',
    emoji: '💞',
    tone: CuteTone.pink,
    icon: Icons.favorite_outline,
    page: (id) => HouseholdScreen(householdId: id),
  ),
  (
    label: 'Einstellungen',
    emoji: '⚙️',
    tone: CuteTone.mint,
    icon: Icons.settings_outlined,
    page: (id) => SettingsScreen(householdId: id),
  ),
];

/// Tab "Mehr": alle weiteren Bereiche als Kacheln.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: GridView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: picGridDelegate(
          context,
          tileHeight: 148,
          maxTileWidth: 140,
        ),
        children: [
          for (final e in moreEntries)
            PicTile(
              title: e.label,
              emoji: e.emoji,
              tone: e.tone,
              titleLines: 1,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => e.page(householdId))),
            ),
        ],
      ),
    );
  }
}
