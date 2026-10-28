import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/contracts.dart';
import 'package:bubududu/features/health.dart';
import 'package:bubududu/features/tasks.dart';
import 'package:bubududu/notifications/reminders.dart';
import 'package:bubududu/util/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mittwoch, 28. Oktober 2026, 10 Uhr
  final now = DateTime(2026, 10, 28, 10);

  CalendarEvent event(
    String title,
    DateTime date, {
    String? time,
    String who = '',
    bool yearly = false,
  }) => CalendarEvent(
    id: title,
    title: title,
    date: date,
    time: time,
    who: who,
    yearly: yearly,
    note: '',
  );

  List<String> titles(List<Reminder> r) => [
    for (final x in r)
      '${x.at.day}.${x.at.month}. ${x.at.hour}:${x.at.minute.toString().padLeft(2, '0')} ${x.title}',
  ];

  test('Termin mit Uhrzeit: eine Stunde vorher', () {
    final r = computeReminders(
      uid: 'kevin',
      now: now,
      events: [event('Kino', DateTime(2026, 10, 29), time: '20:00')],
    );
    expect(titles(r), ['29.10. 19:00 In einer Stunde: Kino']);
  });

  test('Ganztägig um 8 Uhr, Geburtstag auch am Vorabend', () {
    final r = computeReminders(
      uid: 'kevin',
      now: now,
      events: [
        event('Ausflug', DateTime(2026, 11, 2)),
        event('Geburtstag Oma', DateTime(1950, 11, 5), yearly: true),
      ],
    );
    expect(titles(r), [
      '2.11. 8:00 Heute: Ausflug',
      '4.11. 18:00 Morgen: Geburtstag Oma',
      '5.11. 8:00 Heute: Geburtstag Oma',
    ]);
  });

  test('Nur eigene oder gemeinsame Termine', () {
    final r = computeReminders(
      uid: 'kevin',
      now: now,
      events: [
        event(
          'Bubus Yoga',
          DateTime(2026, 10, 30),
          time: '18:00',
          who: 'fritzi',
        ),
        event(
          'Dudus Sport',
          DateTime(2026, 10, 30),
          time: '19:00',
          who: 'kevin',
        ),
      ],
    );
    expect(titles(r), ['30.10. 18:00 In einer Stunde: Dudus Sport']);
  });

  test('Vergangenes und zu weit Entferntes wird nicht geplant', () {
    final r = computeReminders(
      uid: 'kevin',
      now: now,
      events: [
        event('Vorhin', DateTime(2026, 10, 28), time: '10:30'),
        event('Nächstes Jahr', DateTime(2027, 6, 1)),
      ],
    );
    expect(r, isEmpty);
  });

  test('Aufgaben, Kündigungsfristen, Pflege und Arzttermine', () {
    final r = computeReminders(
      uid: 'kevin',
      now: now,
      tasks: [
        HouseTask(
          id: 't',
          title: 'Bad putzen',
          assignee: 'kevin',
          due: DateTime(2026, 10, 31),
          repeat: Repeat.weekly,
          points: 2,
          done: false,
        ),
        HouseTask(
          id: 'u',
          title: 'Fenster',
          assignee: 'fritzi',
          due: DateTime(2026, 10, 31),
          repeat: Repeat.none,
          points: 1,
          done: false,
        ),
      ],
      contracts: [
        Contract(
          id: 'c',
          name: 'Strom',
          provider: '',
          costCents: 9000,
          interval: BillingInterval.monthly,
          cancelBy: DateTime(2026, 11, 15),
          note: '',
        ),
      ],
      care: [
        CareItem(
          id: 'p',
          name: 'Monstera',
          kind: CareKind.plant,
          action: 'Gießen',
          intervalDays: 7,
          lastDone: DateTime(2026, 10, 25),
          lastBy: 'fritzi',
        ),
      ],
      health: [
        HealthEntry(
          id: 'h',
          kind: HealthKind.appointment,
          title: 'Zahnarzt',
          date: DateTime(2026, 11, 3),
          person: 'kevin',
          recKey: null,
          doctor: 'Dr. Weiß',
          note: '',
          isPrivate: true,
        ),
      ],
    );
    expect(titles(r), [
      '31.10. 9:00 Heute dran: Bad putzen',
      '1.11. 9:00 Monstera: Gießen',
      '2.11. 19:00 Morgen: Zahnarzt',
      '3.11. 8:00 Heute: Zahnarzt',
      '8.11. 9:00 Strom: noch 7 Tage',
      '15.11. 9:00 Strom: heute letzter Tag',
    ]);
  });

  test('IDs sind stabil und begrenzt', () {
    final events = [
      for (var i = 0; i < 100; i++)
        event('T$i', today().add(Duration(days: 1 + i % 20)), time: '12:00'),
    ];
    final a = computeReminders(uid: 'k', now: DateTime.now(), events: events);
    final b = computeReminders(uid: 'k', now: DateTime.now(), events: events);
    expect(a, hasLength(maxReminders));
    expect(a.map((r) => r.id), b.map((r) => r.id));
    expect(a.map((r) => r.id).toSet(), hasLength(maxReminders));
  });
}
