import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('DashLayout', () {
    test('ohne Einstellung: alle Kacheln in Standardreihenfolge', () {
      final l = DashLayout.fromMap(null);
      expect(l.visible, DashTile.values);
    });

    test('liest Reihenfolge, ignoriert Unbekanntes, ergänzt Neues', () {
      final l = DashLayout.fromMap({
        'order': ['stocks', 'gibtsnicht', 'weather'],
        'hidden': ['weather', 'quatsch'],
      });
      expect(l.order.length, DashTile.values.length);
      expect(
        l.order.indexOf(DashTile.stocks),
        lessThan(l.order.indexOf(DashTile.weather)),
      );
      expect(l.hidden, {DashTile.weather});
      expect(l.visible.contains(DashTile.weather), isFalse);
      // Rundreise über Firestore-Format.
      final again = DashLayout.fromMap(l.toMap());
      expect(again.order, l.order);
      expect(again.hidden, l.hidden);
    });

    test('verschieben und umschalten', () {
      final l = DashLayout.standard.moved(0, 2).toggled(DashTile.today);
      expect(l.order[2], DashTile.aktionstage);
      expect(l.hidden, {DashTile.today});
      expect(l.toggled(DashTile.today).hidden, isEmpty);
    });
  });

  group('Startseite', () {
    setUp(() async {
      await seedHousehold();
    });

    testWidgets('Einrichten führt zu den Kacheln', (tester) async {
      await pumpPage(tester, const DashboardSettingsScreen(householdId: 'h1'));
      await tester.tap(find.text('Kacheln auswählen & sortieren'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsWidgets);
      expect(find.text('Einkaufsliste'), findsOneWidget);
    });

    testWidgets('ausgeblendete Kachel fehlt auf der Startseite', (
      tester,
    ) async {
      await db.doc('users/kevin').set({
        'dashboard': {
          'order': ['shopping'],
          'hidden': ['weather'],
        },
      });
      await pumpPage(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
      );
      expect(find.text('Einkaufsliste'), findsOneWidget);
      expect(find.textContaining('Wetter'), findsNothing);
    });

    testWidgets('Haken weg speichert ausgeblendet', (tester) async {
      await pumpPage(tester, const DashLayoutScreen());
      await tester.tap(find.text('Aktionstage'));
      await tester.pumpAndSettle();
      final doc = await db.doc('users/kevin').get();
      expect(doc.data()?['dashboard']['hidden'], ['aktionstage']);
    });
  });
}
