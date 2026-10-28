import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Tab "Wir": Mitglieder, Einladungscode und Abmelden.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider(householdId));

    return Scaffold(
      appBar: AppBar(title: const Text('Wir')),
      body: household.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (h) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(h.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final uid in h.members)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(h.memberNames[uid] ?? 'Unbekannt'),
              ),
            if (h.members.length < 2) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Einladungscode für deinen Schatz'),
                  subtitle: Text(
                    h.inviteCode,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  trailing: IconButton(
                    tooltip: 'Kopieren',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: h.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code kopiert')),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
