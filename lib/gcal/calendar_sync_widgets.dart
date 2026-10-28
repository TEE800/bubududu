import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../features/calendar.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import 'calendar_sync.dart';
import 'phone_calendar.dart';

/// Überträgt Termine automatisch in den Handy-Kalender, sobald sich etwas ändert.
class CalendarSync extends ConsumerStatefulWidget {
  const CalendarSync({
    super.key,
    required this.householdId,
    required this.child,
  });

  final String householdId;
  final Widget child;

  @override
  ConsumerState<CalendarSync> createState() => _CalendarSyncState();
}

class _CalendarSyncState extends ConsumerState<CalendarSync> {
  Timer? _debounce;
  var _running = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      eventsProvider(widget.householdId),
      (_, _) => _schedule(),
      fireImmediately: true,
    );
    ref.listenManual(syncCalendarProvider, (_, _) => _schedule());
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _run);
  }

  Future<void> _run() async {
    final phone = ref.read(phoneCalendarProvider);
    final calendar = ref.read(syncCalendarProvider).value;
    final events = ref.read(eventsProvider(widget.householdId)).value;
    if (!phone.available || calendar == null || events == null) return;
    if (_running) return _schedule();
    _running = true;
    try {
      await exportToPhone(
        phone: phone,
        store: ref.read(calendarSyncStoreProvider),
        calendarId: calendar.id,
        events: events,
        uid: ref.read(uidProvider),
      );
    } catch (e) {
      debugPrint('Kalender-Abgleich fehlgeschlagen: $e');
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Abschnitt in den Einstellungen: Kalender wählen, ab- und anschalten.
class CalendarSyncSettings extends ConsumerWidget {
  const CalendarSyncSettings({super.key, required this.householdId});

  final String householdId;

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final phone = ref.read(phoneCalendarProvider);
    if (!await phone.requestPermission()) {
      if (context.mounted) {
        showError(context, 'Ohne Kalender-Zugriff geht es leider nicht.');
      }
      return;
    }
    final calendars = await phone.writableCalendars();
    calendars.sort((a, b) => (b.isGoogle ? 1 : 0) - (a.isGoogle ? 1 : 0));
    if (!context.mounted) return;
    if (calendars.isEmpty) {
      return showError(context, 'Auf dem Handy gibt es keinen Kalender.');
    }
    final picked = await showModalBottomSheet<PhoneCalendarInfo>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('In welchen Kalender?')),
            for (final c in calendars)
              ListTile(
                leading: Icon(
                  c.isGoogle ? Icons.event_available : Icons.event_outlined,
                ),
                title: Text(c.name),
                subtitle: c.isGoogle ? const Text('Google-Kalender') : null,
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final store = ref.read(calendarSyncStoreProvider);
    final old = await store.calendar();
    // Beim Wechsel die alten Einträge mitnehmen statt doppelt zu haben.
    if (old != null && old.id != picked.id) {
      await removeAllFromPhone(phone: phone, store: store);
    }
    await store.setCalendar(picked.id, picked.name);
    ref.invalidate(syncCalendarProvider);
    if (context.mounted) {
      showError(context, 'Eure Termine erscheinen gleich in ${picked.name}.');
    }
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final store = ref.read(calendarSyncStoreProvider);
    try {
      await removeAllFromPhone(
        phone: ref.read(phoneCalendarProvider),
        store: store,
      );
    } catch (_) {
      // Ohne Zugriff bleiben sie eben stehen.
    }
    await store.setCalendar(null);
    ref.invalidate(syncCalendarProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(phoneCalendarProvider);
    if (!phone.available) {
      return const ListTile(
        leading: Icon(Icons.event_busy_outlined),
        title: Text('Google-Kalender'),
        subtitle: Text('Geht nur in der Android-App.'),
      );
    }
    final calendar = ref.watch(syncCalendarProvider).value;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: const Text('Termine in meinen Google-Kalender'),
          subtitle: Text(
            calendar == null
                ? 'Gemeinsame und eigene Termine erscheinen automatisch '
                      'in deinem Kalender auf dem Handy.'
                : 'Läuft: ${calendar.name}',
          ),
          value: calendar != null,
          onChanged: (on) =>
              on ? _choose(context, ref) : _turnOff(context, ref),
        ),
        if (calendar != null) ...[
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Anderen Kalender wählen'),
            onTap: () => _choose(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Termine aus dem Kalender holen'),
            subtitle: const Text(
              'Z. B. Arzttermine, die schon in Google stehen.',
            ),
            onTap: () => showImportSheet(context, householdId),
          ),
        ],
      ],
    );
  }
}

/// Zeigt Termine aus dem Handy-Kalender zum Übernehmen in die App.
Future<void> showImportSheet(BuildContext context, String householdId) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ImportSheet(householdId: householdId),
    );

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet({required this.householdId});

  final String householdId;

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  List<PhoneEvent>? _candidates;
  final _selected = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final calendar = ref.read(syncCalendarProvider).value;
      final phone = ref.read(phoneCalendarProvider);
      if (calendar == null) {
        setState(
          () => _error = 'Wähle zuerst in den Einstellungen einen Kalender.',
        );
        return;
      }
      if (!await phone.requestPermission()) {
        setState(() => _error = 'Ohne Kalender-Zugriff geht es leider nicht.');
        return;
      }
      final list = await importCandidates(
        phone: phone,
        store: ref.read(calendarSyncStoreProvider),
        calendarId: calendar.id,
        events: ref.read(eventsProvider(widget.householdId)).value ?? const [],
      );
      if (mounted) setState(() => _candidates = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Das hat nicht geklappt: $e');
    }
  }

  void _take() {
    final store = ref.read(storeProvider(widget.householdId));
    for (final e in _candidates!) {
      if (_selected.contains(e.id)) {
        store.add('events', eventDataFromPhone(e, store.uid));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final list = _candidates;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Welche Termine sollen in die App?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
            else if (list == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('In den nächsten 3 Monaten gibt es nichts Neues.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in list)
                      CheckboxListTile(
                        value: _selected.contains(e.id),
                        title: Text(e.title),
                        subtitle: Text(
                          '${formatDate(e.start)}'
                          '${e.allDay ? '' : ', ${e.start.hour}:${e.start.minute.toString().padLeft(2, '0')} Uhr'}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(
                          () => v == true
                              ? _selected.add(e.id)
                              : _selected.remove(e.id),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : _take,
                child: Text('${_selected.length} übernehmen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
