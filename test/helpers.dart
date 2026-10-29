import 'dart:convert';

import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/providers.dart';
import 'package:bubududu/data/store.dart';
import 'package:bubududu/notifications/local.dart';
import 'package:bubududu/services/weather.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Gemeinsame Bausteine für die Widget-Tests.

late FakeFirebaseFirestore db;

final mockHttp = MockClient((request) async {
  if (request.url.host == 'api.open-meteo.com') {
    return http.Response(
      jsonEncode({
        'current': {'temperature_2m': 11.4, 'weather_code': 3},
        'daily': {
          'time': ['2026-10-28', '2026-10-29', '2026-10-30'],
          'temperature_2m_max': [12.1, 14.0, 9.0],
          'temperature_2m_min': [5.2, 6.8, 2.0],
          'weather_code': [3, 61, 0],
          'precipitation_probability_max': [10, 80, 0],
        },
      }),
      200,
    );
  }
  if (request.url.host == 'query1.finance.yahoo.com') {
    return http.Response(
      jsonEncode({
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
      }),
      200,
    );
  }
  return http.Response('', 404);
});

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  MockFirebaseAuth? auth,
  ThemeData? theme,
  String uid = 'kevin',
}) async {
  // Typische Handygröße, damit Überläufe auffallen.
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(db)),
        uidProvider.overrideWithValue(uid),
        firebaseAuthProvider.overrideWithValue(
          auth ??
              MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
        ),
        httpClientProvider.overrideWithValue(mockHttp),
        notificationsProvider.overrideWithValue(NoNotifications()),
      ],
      child: MaterialApp(
        theme: theme,
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

/// Beispieldaten für Haushalt h1 mit Dudu (kevin) und Bubu (fritzi).
Future<void> seedHousehold() async {
  db = FakeFirebaseFirestore();
  await db.doc('households/h1').set({
    'name': 'Zuhause',
    'inviteCode': 'ABC123',
    'members': ['kevin', 'fritzi'],
    'memberNames': {'kevin': 'Dudu', 'fritzi': 'Bubu'},
    'togetherSince': Timestamp.fromDate(DateTime(2022, 5, 1)),
    'weatherPlace': {'name': 'Leipzig, Sachsen', 'lat': 51.3, 'lng': 12.4},
    'stocks': ['SAP.DE'],
  });
  final now = DateTime.now();
  final store = HouseholdStore(db, 'h1', 'kevin');
  await store.add('tasks', {
    'title': 'Bad putzen',
    'assignee': 'fritzi',
    'due': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
    'repeat': 'weekly',
    'points': 2,
    'done': false,
  });
  await store.add('events', {
    'title': 'Kino',
    'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1)),
    'time': '20:00',
    'who': '',
    'yearly': false,
  });
  await store.add('expenses', {
    'title': 'Wocheneinkauf',
    'amountCents': 4000,
    'paidBy': 'kevin',
    'split': 'half',
    'category': 'Lebensmittel',
    'date': Timestamp.fromDate(now),
  });
  await store.add('contracts', {
    'name': 'Strom',
    'costCents': 9000,
    'interval': 'monthly',
    'cancelBy': Timestamp.fromDate(now.add(const Duration(days: 10))),
  });
  await store.add('care', {
    'name': 'Monstera',
    'kind': 'plant',
    'action': 'Gießen',
    'intervalDays': 7,
  });
  await store.add('pantry', {'name': 'Nudeln', 'level': 'low'});
  await store.add('notes', {'title': 'WLAN', 'body': 'geheim', 'pinned': true});
  await store.add('trips', {
    'name': 'Ostsee',
    'packing': [
      {'text': 'Badehose', 'done': false},
    ],
  });
  await store.add('ideas', {'text': 'Picknick', 'kind': 'date', 'done': false});
  await store.addToShoppingList('Milch');
  await store.add('recipes', {
    'title': 'Pfannkuchen',
    'ingredients': ['Mehl', 'Milch'],
    'instructions': '',
  });
}
