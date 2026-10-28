import 'package:bubududu/data/household_repository.dart';
import 'package:bubududu/data/store.dart';
import 'package:bubududu/main.dart';
import 'package:bubududu/screens/home_screen.dart';
import 'package:bubududu/screens/household_setup_screen.dart';
import 'package:bubududu/screens/login_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(() => db = FakeFirebaseFirestore());

  group('Anmelden', () {
    testWidgets('Konto erstellen legt das Profil mit Namen an', (tester) async {
      final auth = MockFirebaseAuth();
      await pumpPage(tester, const LoginScreen(), auth: auth);

      await tester.tap(find.text('Neu hier? Konto erstellen'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Dein Name'),
        'Dudu',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'E-Mail'),
        'dudu@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Passwort'),
        'geheim123',
      );
      await tester.tap(find.text('Konto erstellen'));
      await tester.pump(const Duration(milliseconds: 100));

      final uid = auth.currentUser!.uid;
      final profile = await db.doc('users/$uid').get();
      expect(profile.data()!['displayName'], 'Dudu');
    });

    testWidgets('Ohne Namen gibt es einen Hinweis', (tester) async {
      await pumpPage(tester, const LoginScreen(), auth: MockFirebaseAuth());
      await tester.tap(find.text('Neu hier? Konto erstellen'));
      await tester.pump();
      await tester.tap(find.text('Konto erstellen'));
      await tester.pump();
      expect(find.text('Bitte gib deinen Namen ein.'), findsOneWidget);
    });

    testWidgets('Falsches Passwort wird verständlich gemeldet', (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await pumpPage(tester, const LoginScreen(), auth: auth);
      await tester.enterText(
        find.widgetWithText(TextField, 'E-Mail'),
        'dudu@example.com',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'x');
      await tester.tap(find.text('Anmelden'));
      await tester.pump();
      expect(find.text('E-Mail oder Passwort stimmen nicht.'), findsOneWidget);
    });
  });

  group('Haushalt verbinden', () {
    testWidgets('Haushalt anlegen', (tester) async {
      await pumpPage(
        tester,
        const HouseholdSetupScreen(),
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'kevin', displayName: 'Dudu'),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name des Haushalts'),
        'Unsere Bude',
      );
      await tester.tap(find.text('Haushalt anlegen'));
      await tester.pump(const Duration(milliseconds: 100));

      final id = (await db.doc('users/kevin').get()).data()!['householdId'];
      final household = await db.doc('households/$id').get();
      expect(household.data()!['name'], 'Unsere Bude');
      expect(household.data()!['memberNames'], {'kevin': 'Dudu'});
    });

    testWidgets('Mit falschem Code beitreten zeigt einen Fehler', (
      tester,
    ) async {
      await pumpPage(tester, const HouseholdSetupScreen());
      await tester.enterText(
        find.widgetWithText(TextField, 'Einladungscode'),
        'XXXXXX',
      );
      await tester.tap(find.text('Beitreten'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Diesen Einladungscode gibt es nicht.'), findsOneWidget);
    });

    test('Bubu tritt per Code bei und erscheint mit Namen', () async {
      final repo = HouseholdRepository(db);
      await repo.createHousehold(uid: 'kevin', displayName: 'Dudu', name: 'H');
      final code = (await db.collection('invites').get()).docs.single.id;
      await repo.joinHousehold(uid: 'fritzi', displayName: 'Bubu', code: code);
      final id = (await db.doc('users/kevin').get()).data()!['householdId'];
      final household = await repo.watchHousehold(id as String).first;
      expect(household.memberNames.values, ['Dudu', 'Bubu']);
    });
  });

  group('Startweiche', () {
    Future<void> pumpGate(WidgetTester tester, MockFirebaseAuth auth) async {
      await pumpPage(tester, const AuthGate(), auth: auth);
    }

    testWidgets('Abgemeldet: Login', (tester) async {
      await pumpGate(tester, MockFirebaseAuth());
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Angemeldet ohne Haushalt: Einrichtung', (tester) async {
      await db.doc('users/kevin').set({'displayName': 'Dudu'});
      await pumpGate(
        tester,
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'kevin')),
      );
      expect(find.byType(HouseholdSetupScreen), findsOneWidget);
    });

    testWidgets('Angemeldet mit Haushalt: Start', (tester) async {
      await seedHousehold();
      await db.doc('users/kevin').set({
        'displayName': 'Dudu',
        'householdId': 'h1',
      });
      await pumpGate(
        tester,
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'kevin')),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  test('Store schreibt Ersteller und Zeitpunkt dazu', () async {
    final store = HouseholdStore(db, 'h1', 'fritzi');
    await store.add('notes', {'title': 'Test'});
    await pumpEventQueue();
    final note = (await db.collection('households/h1/notes').get()).docs.single;
    expect(note.data()['createdBy'], 'fritzi');
    expect(note.data()['createdAt'], isNotNull);
  });
}
