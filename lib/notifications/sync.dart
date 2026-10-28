import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../features/calendar.dart';
import '../features/care.dart';
import '../features/contracts.dart';
import '../features/health.dart';
import '../features/tasks.dart';
import 'local.dart';
import 'push.dart';
import 'reminders.dart';

/// Die Erinnerungen, die gerade geplant sein sollten, oder null solange
/// noch Daten laden. Leer, wenn Erinnerungen abgeschaltet sind.
final plannedRemindersProvider = Provider.family<List<Reminder>?, String>((
  ref,
  householdId,
) {
  final profile = ref.watch(userProfileProvider);
  final events = ref.watch(eventsProvider(householdId));
  final tasks = ref.watch(tasksProvider(householdId));
  final contracts = ref.watch(contractsProvider(householdId));
  final care = ref.watch(careProvider(householdId));
  final health = ref.watch(healthEntriesProvider(householdId));
  final all = [profile, events, tasks, contracts, care, health];
  if (all.any((v) => !v.hasValue)) return null;
  if (!(profile.value?.wants(NotifyKind.reminders) ?? true)) return const [];
  return computeReminders(
    uid: ref.watch(uidProvider),
    now: DateTime.now(),
    events: events.value!,
    tasks: tasks.value!,
    contracts: contracts.value!,
    care: care.value!,
    health: health.value!,
  );
});

/// Hält Erinnerungen und Push-Anmeldung aktuell, solange die App offen ist.
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({
    super.key,
    required this.householdId,
    required this.child,
  });

  final String householdId;
  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  Timer? _debounce;
  String _planned = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      plannedRemindersProvider(widget.householdId),
      (_, next) => _plan(next),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerPush());
  }

  Future<void> _registerPush() async {
    final uid = ref.read(uidProvider);
    if (uid.isEmpty || !mounted) return;
    final local = ref.read(notificationsProvider);
    await local.requestPermission();
    await Push.register(
      uid: uid,
      repo: ref.read(householdRepositoryProvider),
      local: local,
    );
  }

  void _plan(List<Reminder>? reminders) {
    if (reminders == null) return;
    // Nur neu planen, wenn sich wirklich etwas geändert hat.
    final signature = reminders.map((r) => '${r.id}@${r.at}').join(',');
    if (signature == _planned) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _planned = signature;
      ref.read(notificationsProvider).replaceReminders(reminders);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
