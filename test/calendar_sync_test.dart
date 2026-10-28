import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/gcal/calendar_sync.dart';
import 'package:bubududu/gcal/phone_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Handy-Kalender zum Zuschauen.
class FakePhone implements PhoneCalendar {
  final events = <String, PhoneEvent>{};
  final recurring = <String>{};
  var _next = 0;

  @override
  bool get available => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<PhoneCalendarInfo>> writableCalendars() async => [
    (id: 'g', name: 'kevin@gmail.com', isGoogle: true),
  ];

  @override
  Future<String> create(
    String calendarId, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required bool yearly,
    required String description,
  }) async {
    final id = 'p${_next++}';
    events[id] = (
      id: id,
      title: title,
      start: start,
      allDay: allDay,
      description: description,
    );
    if (yearly) recurring.add(id);
    return id;
  }

  @override
  Future<void> delete(String eventId, {required bool recurring}) async {
    expect(recurring, this.recurring.contains(eventId));
    events.remove(eventId);
  }

  @override
  Future<List<PhoneEvent>> list(
    String calendarId,
    DateTime from,
    DateTime to,
  ) async => events.values.toList();
}

void main() {
  final now = DateTime(2026, 10, 28, 10);
  late FakePhone phone;
  late CalendarSyncStore store;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    phone = FakePhone();
    store = CalendarSyncStore(SharedPreferencesAsync());
  });

  CalendarEvent event(
    String id,
    DateTime date, {
    String? time,
    String who = '',
    bool yearly = false,
    String? googleId,
    String createdBy = 'kevin',
  }) => CalendarEvent(
    id: id,
    title: id,
    date: date,
    time: time,
    who: who,
    yearly: yearly,
    note: '',
    googleId: googleId,
    createdBy: createdBy,
  );

  Future<int> sync(List<CalendarEvent> events) => exportToPhone(
    phone: phone,
    store: store,
    calendarId: 'g',
    events: events,
    uid: 'kevin',
    now: now,
  );

  test('Termine landen im Handy-Kalender, mit Uhrzeit und ganztägig', () async {
    await sync([
      event('Kino', DateTime(2026, 10, 30), time: '20:15'),
      event('Urlaub', DateTime(2026, 11, 2)),
      event('Geburtstag', DateTime(1990, 3, 4), yearly: true),
    ]);
    final byTitle = {for (final e in phone.events.values) e.title: e};
    expect(byTitle['Kino']!.start, DateTime(2026, 10, 30, 20, 15));
    expect(byTitle['Kino']!.allDay, isFalse);
    expect(byTitle['Urlaub']!.allDay, isTrue);
    expect(phone.recurring, hasLength(1));
    expect(byTitle['Kino']!.description, contains('Bubu & Dudu'));
  });

  test(
    'Nur einmal anlegen, Änderungen ersetzen, Gelöschtes entfernen',
    () async {
      final kino = event('Kino', DateTime(2026, 10, 30), time: '20:15');
      final zoo = event('Zoo', DateTime(2026, 11, 1));
      expect(await sync([kino, zoo]), 2);
      expect(await sync([kino, zoo]), 0);
      expect(phone.events, hasLength(2));

      final later = event('Kino', DateTime(2026, 10, 30), time: '21:00');
      expect(await sync([later]), 3); // Kino ersetzt, Zoo weg
      expect(phone.events.values.single.start, DateTime(2026, 10, 30, 21));
    },
  );

  test(
    'Nur meine und gemeinsame, nichts Altes, nichts Zurückgeholtes',
    () async {
      await sync([
        event('Bubus Yoga', DateTime(2026, 10, 30), who: 'fritzi'),
        event('Meins', DateTime(2026, 10, 30), who: 'kevin'),
        event('Letzten Monat', DateTime(2026, 9, 1)),
        event('Aus Google', DateTime(2026, 11, 3), googleId: 'x'),
        event(
          'Von Bubus Google',
          DateTime(2026, 11, 4),
          googleId: 'y',
          createdBy: 'fritzi',
        ),
      ]);
      expect(
        phone.events.values.map((e) => e.title),
        unorderedEquals(['Meins', 'Von Bubus Google']),
      );
    },
  );

  test('Abschalten räumt den Handy-Kalender auf', () async {
    await sync([event('Geburtstag', DateTime(1990, 3, 4), yearly: true)]);
    await removeAllFromPhone(phone: phone, store: store);
    expect(phone.events, isEmpty);
    expect(await store.exported(), isEmpty);
  });

  test('Holen: nur fremde, noch nicht übernommene Termine', () async {
    await sync([event('Kino', DateTime(2026, 10, 30), time: '20:15')]);
    final zahnarzt = await phone.create(
      'g',
      title: 'Zahnarzt',
      start: DateTime(2026, 11, 5, 9),
      end: DateTime(2026, 11, 5, 10),
      allDay: false,
      yearly: false,
      description: '',
    );
    await phone.create(
      'g',
      title: 'Schon da',
      start: DateTime(2026, 11, 6),
      end: DateTime(2026, 11, 7),
      allDay: true,
      yearly: false,
      description: '',
    );
    final candidates = await importCandidates(
      phone: phone,
      store: store,
      calendarId: 'g',
      events: [event('Schon da', DateTime(2026, 11, 6), googleId: 'p2')],
      now: now,
    );
    expect(candidates.map((e) => e.title), ['Zahnarzt']);

    final data = eventDataFromPhone(candidates.single, 'kevin');
    expect(data['time'], '09:00');
    expect(data['who'], 'kevin');
    expect(data['googleId'], zahnarzt);
  });

  test('Gewählter Kalender wird gemerkt', () async {
    expect(await store.calendar(), isNull);
    await store.setCalendar('g', 'kevin@gmail.com');
    expect((await store.calendar())!.name, 'kevin@gmail.com');
    await store.setCalendar(null);
    expect(await store.calendar(), isNull);
  });
}
