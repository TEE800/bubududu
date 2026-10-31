import 'package:bubududu/util/aktionstage.dart';
import 'package:bubududu/util/dates.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> namen(DateTime d) => aktionstageAm(d).map((t) => t.name).toList();

void main() {
  group('Aktionstage', () {
    test('feste Tage, ernste vor witzigen', () {
      expect(namen(DateTime(2026, 10, 31)), [
        'Reformationstag',
        'Weltspartag',
        'Halloween',
      ]);
      expect(
        namen(DateTime(2026, 1, 21, 15, 30)),
        contains('Tag der Jogginghose'),
      );
      expect(
        namen(DateTime(2027, 2, 28)),
        contains('Tag der seltenen Erkrankungen'),
      );
    });

    test('Schalttag und letzter Februartag', () {
      expect(namen(DateTime(2028, 2, 29)), contains('Schalttag'));
      expect(
        namen(DateTime(2028, 2, 29)),
        contains('Tag der seltenen Erkrankungen'),
      );
      expect(
        namen(DateTime(2028, 2, 28)),
        isNot(contains('Tag der seltenen Erkrankungen')),
      );
    });

    test('Ostern und Himmelfahrt', () {
      expect(ostersonntag(2026), DateTime(2026, 4, 5));
      expect(ostersonntag(2027), DateTime(2027, 3, 28));
      expect(ostersonntag(2025), DateTime(2025, 4, 20));
      expect(
        namen(DateTime(2026, 5, 14)),
        contains('Christi Himmelfahrt und Vatertag'),
      );
    });

    test('bewegliche Tage 2026', () {
      expect(namen(DateTime(2026, 5, 10)), contains('Muttertag'));
      expect(namen(DateTime(2026, 5, 3)), contains('Weltlachtag'));
      expect(namen(DateTime(2026, 9, 13)), contains('Tag des Programmierers'));
      expect(
        namen(DateTime(2026, 9, 25)),
        contains('Tag des Deutschen Butterbrotes'),
      );
      expect(namen(DateTime(2026, 10, 4)), contains('Erntedankfest'));
      expect(namen(DateTime(2026, 11, 15)), contains('Volkstrauertag'));
      expect(namen(DateTime(2026, 11, 18)), contains('Buß- und Bettag'));
      expect(namen(DateTime(2026, 11, 22)), contains('Totensonntag'));
      expect(namen(DateTime(2026, 11, 27)), contains('Black Friday'));
      expect(namen(DateTime(2026, 11, 29)), contains('Erster Advent'));
      // 2028 ist ein Schaltjahr, der 256. Tag ist der 12. September.
      expect(namen(DateTime(2028, 9, 12)), contains('Tag des Programmierers'));
    });

    test('jeder Tag hat Infos, und es ist nie lange leer', () {
      var day = DateTime(2026, 1, 1);
      var leer = 0;
      while (day.year == 2026) {
        final list = aktionstageAm(day);
        for (final t in list) {
          expect(t.name, isNotEmpty);
          expect(t.info.length, greaterThan(20), reason: t.name);
        }
        if (list.isEmpty) {
          leer++;
          final next = naechsteAktionstage(day);
          expect(next, isNotNull);
          expect(
            daysBetween(day, next!.$1),
            lessThanOrEqualTo(4),
            reason: '$day',
          );
        }
        day = addDays(day, 1);
      }
      expect(leer, lessThan(120));
    });
  });
}
