import 'package:flutter/material.dart';

import 'coming_soon_screen.dart';
import 'household_screen.dart';
import 'recipes_screen.dart';
import 'shopping_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.householdId});

  final String householdId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ShoppingScreen(householdId: widget.householdId),
      RecipesScreen(householdId: widget.householdId),
      const ComingSoonScreen(title: 'Haushalt', icon: Icons.cleaning_services),
      const ComingSoonScreen(title: 'Kalender', icon: Icons.calendar_month),
      const ComingSoonScreen(title: 'Finanzen', icon: Icons.euro),
      HouseholdScreen(householdId: widget.householdId),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Einkauf',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            label: 'Haushalt',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            label: 'Finanzen',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Wir',
          ),
        ],
      ),
    );
  }
}
