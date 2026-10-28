import 'package:flutter/material.dart';

import '../features/calendar.dart';
import '../features/dashboard.dart';
import '../features/location.dart';
import '../features/tasks.dart';
import '../notifications/sync.dart';
import 'more_screen.dart';
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
    final id = widget.householdId;
    final pages = [
      DashboardScreen(
        householdId: id,
        onOpenTab: (i) => setState(() => _index = i),
        onOpenPage: (page) =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      ),
      ShoppingScreen(householdId: id),
      TasksScreen(householdId: id),
      CalendarScreen(householdId: id),
      MoreScreen(householdId: id),
    ];

    return NotificationSync(
      householdId: id,
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LocationSharer(householdId: id),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Start',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  label: 'Einkauf',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cleaning_services_outlined),
                  label: 'Haushalt',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Kalender',
                ),
                NavigationDestination(icon: Icon(Icons.apps), label: 'Mehr'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
