import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../gcal/calendar_sync_widgets.dart';
import '../notifications/local.dart';
import '../widgets/common.dart';

/// Persönliche Einstellungen, gelten nur für die eigene Person.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final profile = ref.watch(userProfileProvider).value;
    final household = ref.watch(householdProvider(householdId)).value;
    final partner =
        household?.memberNames.entries
            .where((e) => e.key != uid)
            .map((e) => e.value)
            .firstOrNull ??
        'Dein Partner';
    final repo = ref.read(householdRepositoryProvider);

    Widget toggle(NotifyKind kind, String title, String subtitle) =>
        SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: profile?.wants(kind) ?? true,
          onChanged: (on) async {
            if (on) await ref.read(notificationsProvider).requestPermission();
            await repo.setNotify(uid, kind, on);
          },
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const SectionHeader('Benachrichtigungen'),
          toggle(
            NotifyKind.reminders,
            'Erinnerungen',
            'Termine, Aufgaben, Kündigungsfristen, Gießen & Co. '
                'Kommen auch ohne Netz.',
          ),
          toggle(
            NotifyKind.partner,
            'Wenn $partner etwas einträgt',
            'Z. B. „$partner hat Milch auf die Einkaufsliste gesetzt“.',
          ),
          const SectionHeader('Kalender'),
          CalendarSyncSettings(householdId: householdId),
          const SectionHeader('Testen'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Test-Benachrichtigung'),
            subtitle: const Text('Zeigt sofort eine Benachrichtigung.'),
            onTap: () async {
              final notifications = ref.read(notificationsProvider);
              await notifications.requestPermission();
              await notifications.show(
                'Bubu & Dudu',
                'So sehen Benachrichtigungen aus.',
              );
            },
          ),
        ],
      ),
    );
  }
}
