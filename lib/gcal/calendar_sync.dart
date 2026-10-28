import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar.dart';
import '../util/dates.dart';
import 'phone_calendar.dart';

/// Abgleich der gemeinsamen Termine mit dem Kalender auf dem Handy.
///
/// Richtung App → Handy läuft automatisch: Jeder Termin, der mich betrifft,
/// landet im gewählten Kalender (z. B. Google). Richtung Handy → App holt man
/// sich Termine gezielt über "Termine aus dem Kalender holen".
///
/// Gespeichert wird nur auf diesem Gerät (SharedPreferences): welcher
/// Kalender gewählt ist und welche Handy-Termine wir angelegt haben.

const _calendarKey = 'gcal.calendarId';
const _calendarNameKey = 'gcal.calendarName';
const _mapKey = 'gcal.map';

/// Ab wann Termine übertragen werden (ältere bleiben im Handy-Kalender).
const exportFrom = Duration(days: 7);

/// Was wir für einen übertragenen Termin auf dem Handy wissen.
typedef Exported = ({String deviceId, String hash, bool yearly});

/// Ein Termin, wie er auf dem Handy angelegt werden soll.
class ExportItem {
  const ExportItem({
    required this.key,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.yearly,
    required this.description,
  });

  final String key;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool yearly;
  final String description;

  /// Ändert sich, sobald sich am Termin etwas ändert.
  String get hash =>
      '$title|${start.toIso8601String()}|${end.toIso8601String()}|$allDay|$yearly|$description';
}

typedef ExportPlan = ({List<ExportItem> create, List<String> remove});

/// Welche Termine anzulegen und welche (nach [key]) zu entfernen sind.
ExportPlan planExport({
  required List<CalendarEvent> events,
  required String uid,
  required Map<String, Exported> exported,
  required DateTime now,
}) {
  final wanted = <String, ExportItem>{};
  final from = dateOnly(now).subtract(exportFrom);
  for (final e in events) {
    if (e.who.isNotEmpty && e.who != uid) continue;
    // Was ich selbst aus meinem Kalender geholt habe, steht dort schon.
    if (e.googleId != null && e.createdBy == uid) continue;
    if (!e.yearly && dateOnly(e.date).isBefore(from)) continue;
    final item = exportItem(e);
    wanted[item.key] = item;
  }
  return (
    create: [
      for (final item in wanted.values)
        if (exported[item.key]?.hash != item.hash) item,
    ],
    remove: [
      for (final entry in exported.entries)
        if (wanted[entry.key]?.hash != entry.value.hash) entry.key,
    ],
  );
}

ExportItem exportItem(CalendarEvent e) {
  final time = e.time?.split(':');
  final hour = int.tryParse(time?.first ?? '');
  final minute = int.tryParse(time?.last ?? '');
  final allDay = hour == null || minute == null;
  final start = allDay
      ? dateOnly(e.date)
      : DateTime(e.date.year, e.date.month, e.date.day, hour, minute);
  return ExportItem(
    key: e.id,
    title: e.title,
    start: start,
    end: allDay
        ? start.add(const Duration(days: 1))
        : start.add(const Duration(hours: 1)),
    allDay: allDay,
    yearly: e.yearly,
    description: [
      if (e.note.isNotEmpty) e.note,
      'Aus der Bubu & Dudu App',
    ].join('\n\n'),
  );
}

/// Liest und schreibt die gespeicherten Einstellungen dieses Geräts.
class CalendarSyncStore {
  CalendarSyncStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  Future<({String id, String name})?> calendar() async {
    final id = await _prefs.getString(_calendarKey);
    if (id == null) return null;
    return (id: id, name: await _prefs.getString(_calendarNameKey) ?? id);
  }

  Future<void> setCalendar(String? id, [String? name]) async {
    if (id == null) {
      await _prefs.remove(_calendarKey);
      await _prefs.remove(_calendarNameKey);
    } else {
      await _prefs.setString(_calendarKey, id);
      await _prefs.setString(_calendarNameKey, name ?? id);
    }
  }

  Future<Map<String, Exported>> exported() async {
    final raw = await _prefs.getString(_mapKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        e.key: (
          deviceId: e.value['id'] as String,
          hash: e.value['hash'] as String,
          yearly: e.value['yearly'] as bool? ?? false,
        ),
    };
  }

  Future<void> setExported(Map<String, Exported> map) => _prefs.setString(
    _mapKey,
    jsonEncode({
      for (final e in map.entries)
        e.key: {
          'id': e.value.deviceId,
          'hash': e.value.hash,
          'yearly': e.value.yearly,
        },
    }),
  );
}

final calendarSyncStoreProvider = Provider<CalendarSyncStore>(
  (ref) => CalendarSyncStore(SharedPreferencesAsync()),
);

/// Gewählter Kalender auf diesem Gerät, oder null = Abgleich aus.
final syncCalendarProvider = FutureProvider<({String id, String name})?>(
  (ref) => ref.watch(calendarSyncStoreProvider).calendar(),
);

/// Führt den Abgleich App → Handy aus. Gibt die Zahl der Änderungen zurück.
Future<int> exportToPhone({
  required PhoneCalendar phone,
  required CalendarSyncStore store,
  required String calendarId,
  required List<CalendarEvent> events,
  required String uid,
  DateTime? now,
}) async {
  final exported = await store.exported();
  final plan = planExport(
    events: events,
    uid: uid,
    exported: exported,
    now: now ?? DateTime.now(),
  );
  for (final key in plan.remove) {
    final old = exported.remove(key)!;
    await phone.delete(old.deviceId, recurring: old.yearly);
  }
  for (final item in plan.create) {
    final id = await phone.create(
      calendarId,
      title: item.title,
      start: item.start,
      end: item.end,
      allDay: item.allDay,
      yearly: item.yearly,
      description: item.description,
    );
    exported[item.key] = (deviceId: id, hash: item.hash, yearly: item.yearly);
    // Nach jedem Termin speichern, damit ein Abbruch keine Doppelten erzeugt.
    await store.setExported(exported);
  }
  if (plan.remove.isNotEmpty) await store.setExported(exported);
  return plan.create.length + plan.remove.length;
}

/// Entfernt alle von uns angelegten Termine vom Handy (beim Abschalten).
Future<void> removeAllFromPhone({
  required PhoneCalendar phone,
  required CalendarSyncStore store,
}) async {
  final exported = await store.exported();
  for (final e in exported.values) {
    await phone.delete(e.deviceId, recurring: e.yearly);
  }
  await store.setExported({});
}

/// Termine aus dem Handy-Kalender, die man in die App holen kann:
/// nicht von uns angelegt und noch nicht übernommen.
Future<List<PhoneEvent>> importCandidates({
  required PhoneCalendar phone,
  required CalendarSyncStore store,
  required String calendarId,
  required List<CalendarEvent> events,
  DateTime? now,
}) async {
  final start = dateOnly(now ?? DateTime.now());
  final ours = {for (final e in (await store.exported()).values) e.deviceId};
  final taken = {for (final e in events) ?e.googleId};
  final list = await phone.list(
    calendarId,
    start,
    start.add(const Duration(days: 90)),
  );
  final seen = <String>{};
  return [
    for (final e in list)
      if (!ours.contains(e.id) &&
          !taken.contains(e.id) &&
          !(e.description?.contains('Aus der Bubu & Dudu App') ?? false) &&
          seen.add(e.id))
        e,
  ];
}

/// Daten für einen neuen App-Termin aus einem Handy-Termin.
Map<String, dynamic> eventDataFromPhone(PhoneEvent e, String uid) => {
  'title': e.title,
  'date': writeDate(dateOnly(e.start)),
  'time': e.allDay
      ? null
      : '${e.start.hour.toString().padLeft(2, '0')}:${e.start.minute.toString().padLeft(2, '0')}',
  'who': uid,
  'yearly': false,
  'note': '',
  'googleId': e.id,
};
