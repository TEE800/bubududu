import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../notifications/local.dart';
import '../notifications/push.dart';
import '../features/location.dart';
import '../features/us.dart';

/// "Wir": Beziehung, Bucket-Liste, Standort, Mitglieder, Einladungscode und Abmelden.
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
            TogetherCard(householdId: householdId),
            const SizedBox(height: 8),
            for (final kind in IdeaKind.values)
              ListTile(
                leading: Icon(kind.icon),
                title: Text(kind.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        IdeasScreen(householdId: householdId, kind: kind),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Wo seid ihr?'),
              subtitle: const Text('Standort teilen, freiwillig'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LocationScreen(householdId: householdId),
                ),
              ),
            ),
            const Divider(height: 32),
            Text(h.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final uid in h.members)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(h.memberNames[uid] ?? 'Unbekannt'),
              ),
            if (h.members.length < 2) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Einladungscode für Bubu'),
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
              onPressed: () async {
                final navigator = Navigator.of(context);
                final auth = ref.read(firebaseAuthProvider);
                final uid = auth.currentUser?.uid;
                if (uid != null) {
                  await Push.unregister(
                    uid: uid,
                    repo: ref.read(householdRepositoryProvider),
                  );
                }
                await ref.read(notificationsProvider).replaceReminders([]);
                // Sonst bliebe diese Seite über dem Login offen.
                navigator.popUntil((route) => route.isFirst);
                await auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
