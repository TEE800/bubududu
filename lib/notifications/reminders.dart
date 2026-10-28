import '../features/calendar.dart';
import '../features/care.dart';
import '../features/contracts.dart';
import '../features/health.dart';
import '../features/tasks.dart';
import '../util/dates.dart';

/// Eine Erinnerung, die das Handy zu einer festen Zeit zeigt – auch wenn die
/// App geschlossen ist. Wird aus den gemeinsamen Daten berechnet.
class Reminder {
  const Reminder({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Eindeutig und stabil, damit dieselbe Erinnerung dieselbe ID behält.
  final String key;
  final DateTime at;
  final String title;
  final String body;

  /// Ganzzahlige ID für das Benachrichtigungs-Plugin.
  int get id => _stableHash(key);

  @override
  String toString() => '$at $title – $body';
}

// FNV-1a: in jeder App-Version gleich, anders als String.hashCode.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Höchstens so viele Erinnerungen planen (Android begrenzt Wecker pro App).
const maxReminders = 60;

/// Wie weit im Voraus geplant wird. Öffnet man die App, wird neu geplant.
const reminderHorizon = Duration(days: 30);

DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

/// Berechnet alle Erinnerungen für die Person [uid] ab [now].
List<Reminder> computeReminders({
  required String uid,
  required DateTime now,
  List<CalendarEvent> events = const [],
  List<HouseTask> tasks = const [],
  List<Contract> contracts = const [],
  List<CareItem> care = const [],
  List<HealthEntry> health = const [],
}) {
  final end = now.add(reminderHorizon);
  final result = <Reminder>[];
  void add(String key, DateTime at, String title, String body) {
    if (at.isAfter(now) && at.isBefore(end)) {
      result.add(Reminder(key: key, at: at, title: title, body: body));
    }
  }

  bool forMe(String who) => who.isEmpty || who == uid;

  for (final o in occurrences(events, now, end)) {
    final e = o.event;
    if (!forMe(e.who)) continue;
    final key = 'event:${e.id}:${o.day.toIso8601String()}';
    final time = _parseTime(e.time);
    if (time != null) {
      final start = _at(o.day, time.$1, time.$2);
      add(
        '$key:1h',
        start.subtract(const Duration(hours: 1)),
        'In einer Stunde: ${e.title}',
        'Um ${e.time} Uhr',
      );
    } else {
      add('$key:day', _at(o.day, 8), 'Heute: ${e.title}', 'Ganztägig');
    }
    if (e.yearly) {
      add(
        '$key:eve',
        _at(o.day.subtract(const Duration(days: 1)), 18),
        'Morgen: ${e.title}',
        'Schon an ein Geschenk gedacht?',
      );
    }
  }

  for (final t in tasks) {
    if (t.done || t.due == null || !forMe(t.assignee)) continue;
    add(
      'task:${t.id}:${t.due!.toIso8601String()}',
      _at(t.due!, 9),
      'Heute dran: ${t.title}',
      t.points == 1 ? '1 Punkt' : '${t.points} Punkte',
    );
  }

  for (final c in contracts) {
    final by = c.cancelBy;
    if (by == null) continue;
    final key = 'contract:${c.id}:${by.toIso8601String()}';
    add(
      '$key:7',
      _at(by.subtract(const Duration(days: 7)), 9),
      '${c.name}: noch 7 Tage',
      'Bis ${formatShortDate(by)} kündigen oder verlängern lassen.',
    );
    add(
      '$key:0',
      _at(by, 9),
      '${c.name}: heute letzter Tag',
      'Heute ist die Kündigungsfrist.',
    );
  }

  for (final c in care) {
    final due = dateOnly(c.nextDue);
    add(
      'care:${c.id}:${due.toIso8601String()}',
      _at(due.isBefore(dateOnly(now)) ? dateOnly(now) : due, 9),
      '${c.name}: ${c.action}',
      'Ist wieder fällig.',
    );
  }

  for (final h in upcomingAppointments(health, now)) {
    if (h.person != uid) continue;
    final key = 'health:${h.id}:${h.date.toIso8601String()}';
    add(
      '$key:eve',
      _at(h.date.subtract(const Duration(days: 1)), 19),
      'Morgen: ${h.title}',
      h.doctor.isEmpty ? 'Arzttermin' : h.doctor,
    );
    add(
      '$key:day',
      _at(h.date, 8),
      'Heute: ${h.title}',
      h.doctor.isEmpty ? 'Arzttermin' : h.doctor,
    );
  }

  result.sort((a, b) => a.at.compareTo(b.at));
  return result.take(maxReminders).toList();
}

(int, int)? _parseTime(String? time) {
  final parts = time?.split(':');
  if (parts == null || parts.length != 2) return null;
  final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  return h == null || m == null ? null : (h, m);
}
