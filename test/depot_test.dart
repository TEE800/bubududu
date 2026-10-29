import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/depot.dart';
import 'package:bubududu/util/trade_republic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' as h;

const header =
    '"datetime","date","account_type","category","type","asset_class","name",'
    '"symbol","shares","price","amount","fee","tax","currency",'
    '"original_amount","original_currency","fx_rate","description",'
    '"transaction_id","counterparty_name","counterparty_iban",'
    '"payment_reference","mcc_code"';

String row(
  String datetime,
  String category,
  String type,
  String name,
  String isin,
  String shares,
  String price,
  String amount, {
  String fee = '',
}) =>
    '"$datetime","${datetime.substring(0, 10)}","DEFAULT","$category","$type",'
    '"STOCK","$name","$isin","$shares","$price","$amount","$fee","","EUR",'
    '"","","","","id","","","",""';

void main() {
  group('Trade-Republic-Export', () {
    test('rechnet Käufe, Verkäufe und Stornos zu Positionen zusammen', () {
      final csv = [
        header,
        // neueste zuerst, wie im Export
        row(
          '2025-03-01T10:00:00Z',
          'TRADING',
          'SELL',
          'Core MSCI World USD (Acc)',
          'IE00B4L5Y983',
          '1.0000000000',
          '100.00',
          '100.00',
          fee: '-1.00',
        ),
        // Dividende: "shares" ist hier nur der Bestand und zählt nicht
        row(
          '2025-02-01T10:00:00Z',
          'CASH',
          'DIVIDEND',
          'SAP SE',
          'DE0007164600',
          '5.0000000000',
          '',
          '3.20',
        ),
        row(
          '2025-01-20T10:00:00Z',
          'TRADING',
          'BUY_CANCELLED',
          'SAP SE',
          'DE0007164600',
          '1.0000000000',
          '200.00',
          '200.00',
        ),
        row(
          '2025-01-15T10:00:00Z',
          'TRADING',
          'BUY',
          'SAP SE',
          'DE0007164600',
          '1.0000000000',
          '200.00',
          '-200.00',
        ),
        row(
          '2025-01-10T10:00:00Z',
          'TRADING',
          'BUY',
          'SAP SE',
          'DE0007164600',
          '5.0000000000',
          '180.00',
          '-900.00',
          fee: '-1.00',
        ),
        row(
          '2024-04-16T21:35:23.415Z',
          'TRADING',
          'BUY',
          'Core MSCI World USD (Acc)',
          'IE00B4L5Y983',
          '2.0000000000',
          '90.00',
          '-180.00',
        ),
        row(
          '2024-05-01T10:00:00Z',
          'TRADING',
          'BUY',
          'Apple Inc.',
          'US0378331005',
          '1.0000000000',
          '150.00',
          '-150.00',
        ),
        row(
          '2024-06-01T10:00:00Z',
          'TRADING',
          'SELL',
          'Apple Inc.',
          'US0378331005',
          '-1.0000000000',
          '160.00',
          '160.00',
        ),
        '"2024-04-09T04:38:47.509023Z","2024-04-08","DEFAULT","CASH",'
            '"CUSTOMER_INBOUND","","Max Mustermann","","","","200.000000","",'
            '"","EUR","","","","Einzahlung","id","","","",""',
      ].join('\n');

      final positions = parseTradeRepublicCsv(csv);
      expect(positions.map((p) => p.isin), ['IE00B4L5Y983', 'DE0007164600']);

      final world = positions.first;
      expect(world.name, 'Core MSCI World USD (Acc)');
      expect(world.shares, closeTo(1, 1e-9));
      expect(world.invested, closeTo(90, 1e-9));
      expect(world.lastPrice, 100);

      final sap = positions.last;
      expect(sap.shares, closeTo(5, 1e-9));
      expect(sap.invested, closeTo(901, 1e-9));
    });

    test('versteht auch mit Excel gespeicherte Dateien (Semikolon)', () {
      final csv =
          'datetime;category;type;name;symbol;shares;price;amount;fee\r\n'
          '2025-01-10T10:00:00Z;TRADING;BUY;SAP SE;DE0007164600;'
          '2,5;1.200,00;-3.000,00;-1,00\r\n';
      final p = parseTradeRepublicCsv(csv).single;
      expect(p.shares, 2.5);
      expect(p.invested, 3001);
      expect(p.lastPrice, 1200);
    });

    test('lehnt fremde Dateien ab', () {
      expect(
        () => parseTradeRepublicCsv('Datum,Betrag\n2025-01-01,3'),
        throwsFormatException,
      );
    });

    test('Felder mit Kommas in Anführungszeichen', () {
      expect(parseCsv('"a,b","c""d"\n1,2'), [
        ['a,b', 'c"d'],
        ['1', '2'],
      ]);
    });
  });

  group('Mein Depot', () {
    setUp(() async {
      await h.seedHousehold();
      await h.db.doc('users/kevin').set({
        'depot': {
          'positions': [
            const DepotPosition(
              isin: 'DE0007164600',
              name: 'SAP SE',
              shares: 2,
              invested: 300,
              symbol: 'SAP.DE',
            ).toMap(),
            const DepotPosition(
              isin: 'XX0000000000',
              name: 'Ohne Kurs AG',
              shares: 3,
              invested: 30,
              lastPrice: 10,
            ).toMap(),
          ],
        },
      });
    });

    testWidgets('zeigt Positionen und Gesamtwert mit Live-Kursen', (
      tester,
    ) async {
      await h.pumpPage(tester, const DepotScreen());
      expect(find.text('SAP SE'), findsOneWidget);
      expect(find.text('Ohne Kurs AG'), findsOneWidget);
      // 2 × 220 € live + 3 × 10 € letzter Kaufkurs
      expect(find.text('470,00 €'), findsOneWidget);
      expect(find.text('Heute +40,00 €'), findsOneWidget);
      expect(find.textContaining('Nur du siehst dein Depot'), findsOneWidget);
    });

    testWidgets('zeigt Gewinn je Position in Euro und Prozent', (tester) async {
      await h.pumpPage(tester, const DepotScreen());
      // SAP: 440 € Wert, 300 € bezahlt
      expect(find.text('+140,00 € · +46,67 %'), findsOneWidget);
      expect(find.text('+0,00 € · +0,00 %'), findsOneWidget);
      expect(find.textContaining('heute +10,00 %'), findsOneWidget);
    });

    testWidgets('sucht fehlende Kürzel automatisch über die ISIN', (
      tester,
    ) async {
      await h.db.doc('users/kevin').set({
        'depot': {
          'positions': [
            const DepotPosition(
              isin: 'DE0007164600',
              name: 'SAP SE',
              shares: 1,
              invested: 100,
              lastPrice: 100,
            ).toMap(),
          ],
        },
      });
      await h.pumpPage(tester, const DepotScreen());
      await tester.pumpAndSettle();
      final saved = (await h.db.doc('users/kevin').get()).data()!['depot'];
      expect((saved['positions'] as List).single['symbol'], 'SAP.DE');
      expect(find.text('220,00 €'), findsWidgets);
    });

    testWidgets('Kürzel-Knopf trägt den besten Treffer ein', (tester) async {
      await h.pumpPage(tester, const DepotScreen());
      await tester.tap(find.text('Ohne Kurs AG'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'ISIN (freiwillig)'),
        'DE0007164600',
      );
      await tester.tap(find.text('Kürzel automatisch suchen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'SAP.DE'), findsOneWidget);
    });

    testWidgets('Kachel auf der Startseite', (tester) async {
      await h.pumpPage(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
      );
      await tester.scrollUntilVisible(find.text('Mein Depot'), 200);
      expect(find.text('470,00 €'), findsOneWidget);
    });

    testWidgets('Bubu sieht Dudus Depot nicht', (tester) async {
      await h.pumpPage(
        tester,
        DashboardScreen(
          householdId: 'h1',
          onOpenTab: (_) {},
          onOpenPage: (_) {},
        ),
        uid: 'fritzi',
      );
      await tester.scrollUntilVisible(find.text('Aktien'), 200);
      expect(find.text('Mein Depot'), findsNothing);
    });

    testWidgets('Position von Hand hinzufügen', (tester) async {
      await h.pumpPage(tester, const DepotScreen());
      await tester.tap(find.byTooltip('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Allianz');
      await tester.enterText(
        find.widgetWithText(TextField, 'Stückzahl'),
        '1,5',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final saved = (await h.db.doc('users/kevin').get()).data()!['depot'];
      final names = [for (final p in saved['positions'] as List) p['name']];
      expect(names, ['Allianz', 'Ohne Kurs AG', 'SAP SE']);
      expect((saved['positions'] as List).first['shares'], 1.5);
    });
  });
}
