import 'dart:convert';

import 'package:bubududu/features/aktionstag_sheet.dart';
import 'package:bubududu/services/weather.dart';
import 'package:bubududu/services/wikipedia.dart';
import 'package:bubududu/util/aktionstage.dart';
import 'package:bubududu/util/aktionstage_extras.dart';
import 'package:bubududu/util/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('Zusätze', () {
    test('Ideen und Wikipedia-Titel gehören zu echten Tagen', () {
      final names = <String>{};
      var day = DateTime(2028, 1, 1);
      while (day.year == 2028) {
        names.addAll(aktionstageAm(day).map((t) => t.name));
        day = addDays(day, 1);
      }
      for (final n in [...aktionstagIdeen.keys, ...aktionstagWiki.keys]) {
        expect(names, contains(n));
      }
      // Fast jeder Tag hat eine Idee.
      final ohne = names.where((n) => !aktionstagIdeen.containsKey(n));
      expect(ohne, isEmpty);
    });
  });

  group('Wikipedia', () {
    Map<String, Object> page(String title, String extract) => {
      'query': {
        'pages': [
          {
            'title': title,
            'extract': extract,
            'fullurl': 'https://de.wikipedia.org/wiki/$title',
          },
        ],
      },
    };
    final missing = {
      'query': {
        'pages': [
          {'title': 'x', 'missing': true},
        ],
      },
    };
    const lang = 'Ein ausreichend langer Einleitungstext über das Thema.';

    test('genauer Titel', () async {
      final client = MockClient((r) async {
        expect(r.url.host, 'de.wikipedia.org');
        expect(r.url.queryParameters['titles'], 'Trinkhalm');
        return http.Response(jsonEncode(page('Trinkhalm', lang)), 200);
      });
      final a = await fetchWikiArticle(
        client,
        'Trinkhalm',
        name: 'Tag des Strohhalms',
      );
      expect(a?.title, 'Trinkhalm');
      expect(a?.url, contains('wikipedia.org'));
    });

    test('Suche nur mit passendem Treffer', () async {
      Future<WikiArticle?> run(String hitTitle) => fetchWikiArticle(
        MockClient((r) async {
          if (r.url.queryParameters.containsKey('titles')) {
            return http.Response(jsonEncode(missing), 200);
          }
          return http.Response(jsonEncode(page(hitTitle, lang)), 200);
        }),
        'Tag des Croissants',
      );
      expect((await run('Croissant'))?.title, 'Croissant');
      expect(await run('Frankreich'), isNull);
    });

    test('Begriffsklärung wird übersprungen', () async {
      final client = MockClient(
        (r) async => http.Response(
          jsonEncode({
            'query': {
              'pages': [
                {
                  'title': 'Hut',
                  'extract': lang,
                  'pageprops': {'disambiguation': ''},
                },
              ],
            },
          }),
          200,
        ),
      );
      expect(await fetchWikiArticle(client, 'Hut'), isNull);
    });

    test('Text wird auf ganze Absätze gekürzt', () {
      final text = List.filled(10, 'a' * 400).join('\n');
      final short = shortenExtract(text);
      expect(short.length, lessThanOrEqualTo(1500));
      expect(short.split('\n\n').every((p) => p.length == 400), isTrue);
    });

    testWidgets('Infoblatt zeigt Idee und Hintergrund', (tester) async {
      final client = MockClient(
        (r) async => http.Response(jsonEncode(page('Halloween', lang)), 200),
      );
      final halloween = aktionstageAm(DateTime(2026, 10, 31))
          .firstWhere((t) => t.name == 'Halloween');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [httpClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            home: Scaffold(
              body: AktionstagDetails(
                tag: halloween,
                day: DateTime(2026, 10, 31),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Idee für euch zwei'), findsOneWidget);
      expect(find.textContaining('Kürbis schnitzen'), findsOneWidget);
      expect(find.text(lang), findsOneWidget);
      expect(find.text('Bei Wikipedia weiterlesen'), findsOneWidget);
    });
  });
}
