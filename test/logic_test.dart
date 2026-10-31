import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/calendar.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/contracts.dart';
import 'package:bubududu/features/finance.dart';
import 'package:bubududu/features/tasks.dart';
import 'package:bubududu/services/stocks.dart';
import 'package:bubududu/services/weather.dart';
import 'package:bubududu/util/dates.dart';
import 'package:bubududu/util/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Expense expense(
  String paidBy,
  int cents, {
  Split split = Split.half,
  String category = 'Lebensmittel',
  DateTime? date,
}) => Expense(
  id: 'x',
  title: 't',
  amountCents: cents,
  paidBy: paidBy,
  split: split,
  category: category,
  date: date ?? DateTime(2026, 10, 5),
);

void main() {
  group('Geld', () {
    test('Beträge lesen', () {
      expect(parseCents('12,50'), 1250);
      expect(parseCents('12.5'), 1250);
      expect(parseCents('1.234,56 €'), 123456);
      expect(parseCents('7'), 700);
      expect(parseCents(''), isNull);
      expect(parseCents('abc'), isNull);
      expect(parseCents('-3'), isNull);
    });

    test('Beträge anzeigen', () {
      expect(formatCents(1250), '12,50 €');
      expect(formatCents(123456789), '1.234.567,89 €');
      expect(formatCents(-5), '-0,05 €');
    });
  });

  group('Datum', () {
    test('Monatlich bleibt beim Tag oder kürzt auf Monatsende', () {
      expect(
        nextOccurrence(DateTime(2026, 1, 31), Repeat.monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        nextOccurrence(DateTime(2026, 3, 15), Repeat.monthly),
        DateTime(2026, 4, 15),
      );
      expect(
        nextOccurrence(DateTime(2026, 12, 10), Repeat.monthly),
        DateTime(2027, 1, 10),
      );
      expect(
        nextOccurrence(DateTime(2026, 3, 1), Repeat.weekly),
        DateTime(2026, 3, 8),
      );
    });

    test('Nächster Jahrestag', () {
      final now = DateTime(2026, 10, 28);
      expect(
        nextAnniversary(DateTime(2020, 12, 24), now: now),
        DateTime(2026, 12, 24),
      );
      expect(
        nextAnniversary(DateTime(2020, 3, 1), now: now),
        DateTime(2027, 3, 1),
      );
      expect(
        nextAnniversary(DateTime(2020, 10, 28), now: now),
        DateTime(2026, 10, 28),
      );
      expect(
        nextAnniversary(DateTime(2020, 2, 29), now: now),
        DateTime(2027, 2, 28),
      );
    });

    test('Relative Tage', () {
      final now = DateTime(2026, 10, 28, 15);
      expect(relativeDay(DateTime(2026, 10, 28), now: now), 'Heute');
      expect(relativeDay(DateTime(2026, 10, 29), now: now), 'Morgen');
      expect(relativeDay(DateTime(2026, 11, 3), now: now), 'Di, 3. November');
      expect(dueText(DateTime(2026, 10, 25), now: now), 'seit 3 Tagen fällig');
    });
  });

  group('Finanzen', () {
    test('Wer schuldet wem', () {
      final list = [
        expense('a', 4000), // b schuldet a 20 €
        expense('b', 1000), // a schuldet b 5 €
        expense('b', 600, split: Split.other), // a schuldet b 6 €
      ];
      expect(balance(list, 'a', 'b'), 2000 - 500 - 600);
      final text = balanceText(list, ['a', 'b'], {'a': 'Dudu', 'b': 'Bubu'});
      expect(text, 'Bubu schuldet Dudu 9,00 €');
    });

    test('Ausgleich macht quitt', () {
      final list = [
        expense('a', 3000),
        expense('b', 1500, split: Split.other, category: settlementCategory),
      ];
      expect(balance(list, 'a', 'b'), 0);
      expect(balanceText(list, ['a', 'b'], {}), 'Ihr seid quitt.');
    });

    test('Kategorien pro Monat ohne Ausgleich', () {
      final list = [
        expense('a', 1000),
        expense('a', 500, category: 'Restaurant'),
        expense('a', 9999, date: DateTime(2026, 9, 1)),
        expense('b', 700, category: settlementCategory),
      ];
      expect(categoryTotals(list, DateTime(2026, 10)), {
        'Lebensmittel': 1000,
        'Restaurant': 500,
      });
    });
  });

  group('Kalender', () {
    test('Geburtstage wiederholen sich jährlich', () {
      final events = [
        CalendarEvent(
          id: '1',
          title: 'Geburtstag Bubu',
          date: DateTime(1995, 11, 2),
          time: null,
          who: '',
          yearly: true,
          note: '',
        ),
        CalendarEvent(
          id: '2',
          title: 'Zahnarzt',
          date: DateTime(2026, 11, 1),
          time: '09:00',
          who: '',
          yearly: false,
          note: '',
        ),
        CalendarEvent(
          id: '3',
          title: 'Vorbei',
          date: DateTime(2026, 1, 1),
          time: null,
          who: '',
          yearly: false,
          note: '',
        ),
      ];
      final result = occurrences(
        events,
        DateTime(2026, 10, 28),
        DateTime(2027, 11, 5),
      );
      expect(result.map((o) => (o.day, o.event.id)).toList(), [
        (DateTime(2026, 11, 1), '2'),
        (DateTime(2026, 11, 2), '1'),
        (DateTime(2027, 11, 2), '1'),
      ]);
    });
  });

  group('Pflege und Verträge', () {
    test('Fixkosten je Person: geteilt zählt halb', () {
      Contract c(
        int cents,
        String paidBy, [
        BillingInterval i = BillingInterval.monthly,
      ]) => Contract(
        id: '$cents',
        name: 'x',
        provider: '',
        costCents: cents,
        interval: i,
        cancelBy: null,
        note: '',
        paidBy: paidBy,
      );
      final shares = monthlyShares(
        [
          c(1000, ''),
          c(500, 'kevin'),
          c(12000, 'fritzi', BillingInterval.yearly),
        ],
        ['kevin', 'fritzi'],
      );
      expect(shares, {'kevin': 1000, 'fritzi': 1500});
      expect(payerText(c(1, ''), const {}), 'geteilt');
      expect(payerText(c(1, 'fritzi'), const {'fritzi': 'Bubu'}), 'zahlt Bubu');
    });

    test('Fälligkeit', () {
      final item = CareItem(
        id: '1',
        name: 'Monstera',
        kind: CareKind.plant,
        action: 'Gießen',
        intervalDays: 7,
        lastDone: DateTime(2026, 10, 20),
        lastBy: '',
      );
      expect(item.nextDue, DateTime(2026, 10, 27));
      expect(item.isDue(DateTime(2026, 10, 28)), isTrue);
      expect(item.isDue(DateTime(2026, 10, 26)), isFalse);
    });

    test('Kündigungsfristen in den nächsten 30 Tagen', () {
      Contract c(String id, DateTime? d) => Contract(
        id: id,
        name: id,
        provider: '',
        costCents: 1200,
        interval: BillingInterval.yearly,
        cancelBy: d,
        note: '',
      );
      final list = [
        c('bald', DateTime(2026, 11, 15)),
        c('spät', DateTime(2027, 3, 1)),
        c('vorbei', DateTime(2026, 10, 1)),
        c('ohne', null),
      ];
      expect(
        upcomingDeadlines(list, now: DateTime(2026, 10, 28)).map((x) => x.id),
        ['bald'],
      );
      expect(list.first.monthlyCents, 100);
    });
  });

  group('Aufgaben', () {
    test('Wiederkehrende Aufgabe rückt weiter', () async {
      final db = FakeFirebaseFirestore();
      final store = HouseholdStore(db, 'h1', 'kevin');
      await store.col('tasks').doc('t1').set({
        'title': 'Bad putzen',
        'repeat': 'weekly',
        'due': Timestamp.fromDate(today().subtract(const Duration(days: 10))),
        'done': false,
      });
      final doc = await store.col('tasks').doc('t1').get();
      await completeTask(store, HouseTask.fromDoc(Doc(doc.id, doc.data()!)));

      final after = HouseTask.fromDoc(
        Doc('t1', (await store.col('tasks').doc('t1').get()).data()!),
      );
      expect(after.done, isFalse);
      expect(after.due!.isAfter(today()), isTrue);
      expect(daysBetween(today(), after.due!) <= 7, isTrue);
    });

    test('Einmalige Aufgabe wird abgehakt', () async {
      final store = HouseholdStore(FakeFirebaseFirestore(), 'h1', 'fritzi');
      await store.col('tasks').doc('t2').set({'title': 'Müll', 'done': false});
      final doc = await store.col('tasks').doc('t2').get();
      await completeTask(store, HouseTask.fromDoc(Doc(doc.id, doc.data()!)));
      expect(
        (await store.col('tasks').doc('t2').get()).data()!['done'],
        isTrue,
      );
    });
  });

  group('Online-Dienste', () {
    test('Wetter lesen', () {
      final w = parseWeather({
        'current': {'temperature_2m': 11.4, 'weather_code': 3},
        'daily': {
          'time': ['2026-10-28', '2026-10-29'],
          'temperature_2m_max': [12.1, 14.0],
          'temperature_2m_min': [5.2, 6.8],
          'weather_code': [3, 61],
          'precipitation_probability_max': [10, 80],
        },
      });
      expect(w.temperature, 11.4);
      expect(w.days, hasLength(2));
      expect(w.days[1].rainChance, 80);
      expect(describeWeather(61).$1, 'Regen');
    });

    test('Aktienkurs lesen', () {
      final q = parseQuote('SAP.DE', {
        'chart': {
          'result': [
            {
              'meta': {
                'regularMarketPrice': 220.0,
                'chartPreviousClose': 200.0,
                'currency': 'EUR',
                'shortName': 'SAP SE',
              },
            },
          ],
        },
      });
      expect(q.name, 'SAP SE');
      expect(q.changePercent, closeTo(10, 0.001));
    });
  });
}
