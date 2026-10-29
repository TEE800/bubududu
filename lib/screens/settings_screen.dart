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
          const SectionHeader('Alexa'),
          AlexaSettings(householdId: householdId),
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

/// Verbindet den Alexa-Skill "Bubu Dudu" mit der Einkaufsliste.
class AlexaSettings extends ConsumerWidget {
  const AlexaSettings({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final linked = (ref.watch(alexaLinksProvider).value ?? 0) > 0;
    final repo = ref.read(householdRepositoryProvider);

    if (linked) {
      return ListTile(
        leading: const Icon(Icons.record_voice_over_outlined),
        title: const Text('Mit Alexa verbunden'),
        subtitle: const Text(
          '„Alexa, sag Bubu Dudu, setz Milch auf die Liste“',
        ),
        trailing: TextButton(
          onPressed: () => repo.unlinkAlexa(uid),
          child: const Text('Trennen'),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.record_voice_over_outlined),
      title: const Text('Alexa verbinden'),
      subtitle: const Text(
        'Einkaufsliste per Sprache füllen. Braucht den Skill „Bubu Dudu“.',
      ),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final code = await repo.createAlexaCode(householdId, uid);
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Alexa verbinden'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sag zu deinem Echo:'),
                  const SizedBox(height: 12),
                  Text(
                    '„Alexa, sag Bubu Dudu, Code ${code.split('').join(' ')}“',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text('Der Code gilt 15 Minuten.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                e is StateError
                    ? e.message
                    : 'Kein Code möglich. Bist du online?',
              ),
            ),
          );
        }
      },
    );
  }
}
