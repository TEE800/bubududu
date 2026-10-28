import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/providers.dart';
import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/health.dart';
import 'package:bubududu/features/health_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

late FakeFirebaseFirestore db;

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(db)),
        uidProvider.overrideWithValue('kevin'),
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

Set<String> keys(List<RecState> states) => {for (final s in states) s.rec.key};

void main() {
  group('Vorsorge-Regeln', () {
    test('Alter zählt erst ab dem Geburtstag hoch', () {
      expect(ageOn(DateTime(1990, 11, 3), DateTime(2026, 11, 2)), 35);
      expect(ageOn(DateTime(1990, 11, 3), DateTime(2026, 11, 3)), 36);
    });

    test('Empfehlungen passen zu Alter und Geschlecht', () {
      final now = DateTime(2026, 10, 28);
      final man30 = keys(
        evaluate(
          birthday: DateTime(1996, 1, 1),
          sex: Sex.male,
          lastDone: const {},
          now: now,
        ),
      );
      expect(man30, containsAll(['zahn', 'checkup_jung', 'tetanus', 'masern']));
      expect(man30, isNot(contains('gyn_jung')));
      expect(man30, isNot(contains('prostata')));

      final woman52 = keys(
        evaluate(
          birthday: DateTime(1974, 1, 1),
          sex: Sex.female,
          lastDone: const {},
          now: now,
        ),
      );
      expect(woman52, containsAll(['mammographie', 'darm', 'gyn', 'checkup']));
      expect(woman52, isNot(contains('prostata')));
      expect(woman52, isNot(contains('grippe')));
    });

    test('Status aus dem letzten Eintrag', () {
      final states = evaluate(
        birthday: DateTime(1990, 1, 1),
        sex: Sex.unknown,
        lastDone: {
          'tetanus': DateTime(2020, 5, 1),
          'zahn': DateTime(2024, 1, 1),
          'masern': DateTime(2010, 1, 1),
        },
        now: DateTime(2026, 10, 28),
      );
      RecState of(String k) => states.firstWhere((s) => s.rec.key == k);
      expect(of('tetanus').status, RecStatus.ok);
      expect(of('tetanus').next, DateTime(2030, 5, 1));
      expect(of('zahn').status, RecStatus.due);
      expect(of('masern').status, RecStatus.done);
      expect(of('checkup').status, RecStatus.due);
      // Fällige stehen oben.
      expect(states.first.status, RecStatus.due);
    });
  });

  group('Gesundheit im Haushalt', () {
    setUp(() async {
      db = FakeFirebaseFirestore();
      final now = DateTime.now();
      await db.doc('households/h1').set({
        'name': 'Zuhause',
        'members': ['kevin', 'fritzi'],
        'memberNames': {'kevin': 'Dudu', 'fritzi': 'Bubu'},
        'healthProfiles': {
          'kevin': {
            'birthday': Timestamp.fromDate(DateTime(1994, 3, 1)),
            'sex': 'male',
          },
        },
      });
      await db.collection('households/h1/health').add({
        'kind': 'appointment',
        'title': 'Hausarzt',
        'person': 'kevin',
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day + 2)),
      });
      await db.collection('users/kevin/health').add({
        'kind': 'vaccination',
        'title': 'Tetanus',
        'person': 'kevin',
        'recKey': 'tetanus',
        'date': Timestamp.fromDate(DateTime(now.year - 1, 1, 1)),
      });
    });

    testWidgets('Seite zeigt Termine, Empfehlungen und private Einträge', (
      tester,
    ) async {
      await pumpPage(tester, const HealthScreen(householdId: 'h1'));
      expect(find.text('Hausarzt'), findsOneWidget);
      expect(find.text('Zahnvorsorge'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('privat'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('privat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Neu-Formular öffnet', (tester) async {
      await pumpPage(tester, const HealthEditScreen(householdId: 'h1'));
      expect(find.text('Speichern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Startseite zeigt den nächsten Arzttermin', (tester) async {
      await pumpPage(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
      );
      final f = find.textContaining('Hausarzt');
      await tester.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(f, findsOneWidget);
    });

    test('Privat umschalten zieht den Eintrag um', () async {
      final store = HealthStore(HouseholdStore(db, 'h1', 'kevin'));
      final shared = (await db.collection('households/h1/health').get()).docs;
      final entry = HealthEntry.fromDoc(
        Doc(shared.first.id, shared.first.data()),
        isPrivate: false,
      );
      await store.save(entry, {...shared.first.data()}, true);
      expect((await db.collection('households/h1/health').get()).docs, isEmpty);
      final private = (await db.collection('users/kevin/health').get()).docs;
      expect(private.map((d) => d.data()['title']), contains('Hausarzt'));
    });
  });
}
