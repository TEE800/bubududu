import 'dart:convert';

import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/location.dart';
import 'package:bubududu/features/weather_screen.dart';
import 'package:bubududu/services/weather.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart' as h;

Map<String, dynamic> sample(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) => t.toIso8601String().substring(0, 16);
  final hours = [for (var i = 0; i < 48; i++) start.add(Duration(hours: i))];
  final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
  return {
    'current': {
      'temperature_2m': 11.4,
      'apparent_temperature': 8.6,
      'relative_humidity_2m': 81,
      'weather_code': 61,
      'cloud_cover': 90,
      'pressure_msl': 1012.3,
      'wind_speed_10m': 18.2,
      'wind_direction_10m': 225,
      'wind_gusts_10m': 41.0,
      'uv_index': 1.2,
    },
    'hourly': {
      'time': [for (final t in hours) iso(t)],
      'temperature_2m': [for (var i = 0; i < 48; i++) 5.0 + i % 10],
      'precipitation_probability': [for (var i = 0; i < 48; i++) i % 100],
      'precipitation': [for (var i = 0; i < 48; i++) 0.1],
      'weather_code': [for (var i = 0; i < 48; i++) 3],
    },
    'daily': {
      'time': [for (final d in days) iso(d).substring(0, 10)],
      'temperature_2m_max': [for (var i = 0; i < 7; i++) 12.0 + i],
      'temperature_2m_min': [for (var i = 0; i < 7; i++) 4.0 + i],
      'weather_code': [for (var i = 0; i < 7; i++) 61],
      'precipitation_probability_max': [for (var i = 0; i < 7; i++) 70],
      'precipitation_sum': [for (var i = 0; i < 7; i++) 3.4],
      'sunrise': [for (final d in days) iso(d.add(const Duration(hours: 7)))],
      'sunset': [for (final d in days) iso(d.add(const Duration(hours: 17)))],
      'uv_index_max': [for (var i = 0; i < 7; i++) 2.0],
      'wind_speed_10m_max': [for (var i = 0; i < 7; i++) 30.0],
    },
  };
}

final richHttp = MockClient((request) async {
  if (request.url.host == 'api.open-meteo.com') {
    return http.Response(jsonEncode(sample(DateTime.now())), 200);
  }
  return http.Response('', 404);
});

Future<void> pump(
  WidgetTester tester,
  Widget page, {
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(h.db),
        uidProvider.overrideWithValue('kevin'),
        httpClientProvider.overrideWithValue(richHttp),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('Detaildaten werden gelesen', () {
    final now = DateTime(2026, 10, 28, 14, 30);
    final w = parseWeather(sample(now), now: now);
    expect(w.feelsLike, 8.6);
    expect(w.humidity, 81);
    expect(compass(w.windDirection!), 'SW');
    expect(w.days, hasLength(7));
    expect(w.days.first.sunrise, DateTime(2026, 10, 28, 7));
    expect(w.days.first.rainSum, 3.4);
    // Ab der laufenden Stunde, höchstens 24 Stunden.
    expect(w.hours.first.time, DateTime(2026, 10, 28, 14));
    expect(w.hours, hasLength(24));
  });

  test('Alte Antworten ohne Detailfelder gehen weiter', () {
    final w = parseWeather({
      'current': {'temperature_2m': 1.0, 'weather_code': 0},
      'daily': {
        'time': ['2026-10-28'],
        'temperature_2m_max': [2.0],
        'temperature_2m_min': [0.0],
        'weather_code': [0],
      },
    });
    expect(w.hours, isEmpty);
    expect(w.days.single.rainChance, 0);
  });

  group('mit Haushalt', () {
    setUp(h.seedHousehold);

    testWidgets('Tipp aufs Wetter öffnet die Details', (tester) async {
      await pump(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
      );
      await tester.tap(find.text('Wetter in Leipzig'));
      await tester.pumpAndSettle();
      expect(find.byType(WeatherScreen), findsOneWidget);
      expect(find.text('Gefühlt'), findsOneWidget);
      expect(find.text('9°'), findsWidgets);
      expect(find.text('18 km/h SW'), findsOneWidget);
      expect(find.text('Nächste Stunden'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Daten: Open-Meteo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Automatischer Standort fürs Wetter', (tester) async {
      await h.db.doc('households/h1').update({'weatherAuto': true});
      await pump(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
        overrides: [
          devicePlaceProvider.overrideWith(
            (ref) async => const Place(name: 'Berlin', lat: 52.5, lng: 13.4),
          ),
        ],
      );
      expect(find.text('Wetter in Berlin'), findsOneWidget);
    });

    testWidgets('Einstellung zeigt die Automatik', (tester) async {
      await h.db.doc('households/h1').update({'weatherAuto': true});
      await pump(tester, const DashboardSettingsScreen(householdId: 'h1'));
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
    });

    testWidgets('Karte lässt sich auf Satellit umschalten', (tester) async {
      await h.db.doc('households/h1/locations/fritzi').set({
        'lat': 51.3,
        'lng': 12.4,
        'updatedAt': Timestamp.now(),
      });
      await pump(tester, const LocationScreen(householdId: 'h1'));
      String url() => tester
          .widgetList<TileLayer>(find.byType(TileLayer))
          .first
          .urlTemplate!;
      expect(url(), contains('openstreetmap'));
      await tester.tap(find.text('Satellit'));
      await tester.pump();
      expect(url(), contains('World_Imagery'));
      expect(find.byType(TileLayer), findsNWidgets(2));
    });

    testWidgets('Kein Standort-Banner mehr, Hinweis auf der Startseite', (
      tester,
    ) async {
      await h.db.doc('users/kevin').set({'shareLocation': true});
      await pump(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
      );
      final f = find.text('Du teilst gerade deinen Standort.');
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(f, findsOneWidget);
    });
  });
}
