import 'package:bubududu/features/dashboard.dart';
import 'package:bubududu/features/depot.dart';
import 'package:bubududu/features/depot_charts.dart';
import 'package:bubududu/services/stocks.dart';
import 'package:bubududu/util/trade_republic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

    test('Minus in shares gilt, auch bei Stornos und Kapitalmaßnahmen', () {
      String r(
        String t,
        String cat,
        String type,
        String isin,
        String n,
        String amount,
      ) => row(t, cat, type, 'Papier $isin', isin, n, '10.00', amount);
      final csv = [
        header,
        r('2025-01-01T10:00:00Z', 'TRADING', 'BUY', 'A', '10', '-100.00'),
        // Gratisaktien/Split als Aus- und Einbuchung ohne Geld
        r(
          '2025-02-01T10:00:00Z',
          'CORPORATE_ACTION',
          'STOCK_SPLIT',
          'A',
          '-10',
          '',
        ),
        r(
          '2025-02-01T10:00:01Z',
          'CORPORATE_ACTION',
          'STOCK_SPLIT',
          'A',
          '22',
          '',
        ),
        r('2025-01-01T10:00:00Z', 'TRADING', 'BUY', 'B', '2', '-20.00'),
        r(
          '2025-01-02T10:00:00Z',
          'TRADING',
          'BUY_CANCELLED',
          'B',
          '-2',
          '20.00',
        ),
        r('2025-01-01T10:00:00Z', 'TRADING', 'BUY', 'C', '100', '-99.00'),
        r(
          '2025-03-01T10:00:00Z',
          'CORPORATE_ACTION',
          'FINAL_MATURITY',
          'C',
          '-100',
          '',
        ),
        r(
          '2025-03-02T10:00:00Z',
          'CORPORATE_ACTION',
          'FINAL_MATURITY_CANCELLED',
          'C',
          '100',
          '',
        ),
      ].join('\n');
      final byIsin = {for (final p in parseTradeRepublicCsv(csv)) p.isin: p};
      expect(byIsin.keys, unorderedEquals(['A', 'C']));
      expect(byIsin['A']!.shares, 22);
      expect(byIsin['A']!.invested, 100);
      expect(byIsin['C']!.shares, 100);
      expect(byIsin['C']!.invested, 99);
    });

    test('Gratisaktien mit Storno und Umtausch in neue ISIN', () {
      String r(
        String t,
        String cat,
        String type,
        String name,
        String isin,
        String n,
        String price,
        String amount, {
        String fee = '',
      }) => row(t, cat, type, name, isin, n, price, amount, fee: fee);
      final csv = [
        header,
        // Wie im echten Export: neueste zuerst, neue ISIN vor der alten.
        r(
          '2026-08-19T07:46:02.978Z',
          'TRADING',
          'SELL',
          'Auto AG',
          'CN01',
          '-282.3529200000',
          '0.9858',
          '278.34',
          fee: '-1.00',
        ),
        r(
          '2026-07-02T11:21:37.697Z',
          'CORPORATE_ACTION',
          'EXCHANGE',
          'Öl Holdings',
          'US02',
          '21.0504100000',
          '',
          '',
        ),
        r(
          '2026-07-02T11:21:37.697Z',
          'CORPORATE_ACTION',
          'EXCHANGE',
          'Öl',
          'US01',
          '-21.0504100000',
          '',
          '',
        ),
        r(
          '2025-08-13T05:22:45.443Z',
          'CORPORATE_ACTION',
          'BONUS_ISSUE',
          'Auto AG',
          'CN01',
          '75.2941100000',
          '',
          '',
        ),
        r(
          '2025-08-13T05:09:14.774Z',
          'CORPORATE_ACTION',
          'BONUS_ISSUE_CANCELLED',
          'Auto AG',
          'CN01',
          '-75.2941100000',
          '',
          '',
        ),
        r(
          '2025-07-30T06:25:35.095Z',
          'CORPORATE_ACTION',
          'BONUS_ISSUE',
          'Auto AG',
          'CN01',
          '112.9411700000',
          '',
          '',
        ),
        r(
          '2025-07-30T06:25:21.431Z',
          'CORPORATE_ACTION',
          'BONUS_ISSUE',
          'Auto AG',
          'CN01',
          '75.2941100000',
          '',
          '',
        ),
        r(
          '2025-04-29T14:22:51.744Z',
          'TRADING',
          'BUY',
          'Auto AG',
          'CN01',
          '90.0000000000',
          '4.25',
          '-382.50',
          fee: '-1.00',
        ),
        r(
          '2025-04-29T14:22:51.744Z',
          'TRADING',
          'BUY',
          'Auto AG',
          'CN01',
          '4.1176400000',
          '4.25',
          '-17.50',
        ),
        r(
          '2025-04-24T16:09:32.670Z',
          'TRADING',
          'BUY',
          'Öl',
          'US01',
          '20.0000000000',
          '95.02',
          '-190.04',
          fee: '-1.00',
        ),
        r(
          '2025-04-24T16:09:32.667Z',
          'TRADING',
          'BUY',
          'Öl',
          'US01',
          '1.0504100000',
          '95.02',
          '-9.98',
        ),
      ].join('\n');
      final p = parseTradeRepublicCsv(csv);
      // Auto AG ist komplett verkauft, die alte Öl-ISIN ist umgetauscht.
      expect(p.map((x) => x.isin), ['US02']);
      expect(p.single.shares, closeTo(21.05041, 1e-9));
      expect(p.single.invested, closeTo(201.02, 1e-9));
      expect(p.single.lastPrice, closeTo(95.02, 1e-9));
    });

    test('Kurssuche weicht auf query2 aus, wenn query1 drosselt', () async {
      final hosts = <String>[];
      final client = MockClient((req) async {
        hosts.add(req.url.host);
        if (req.url.host == 'query1.finance.yahoo.com') {
          return http.Response('Too Many Requests', 429);
        }
        return http.Response(
          '{"quotes":[{"symbol":"ASME.DE","shortname":"ASML","exchDisp":"XETRA"}]}',
          200,
        );
      });
      final r = await searchStocks(client, 'NL0010273215');
      expect(r.single.symbol, 'ASME.DE');
      expect(hosts, ['query1.finance.yahoo.com', 'query2.finance.yahoo.com']);
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
      await tester.scrollUntilVisible(
        find.textContaining('Nur du siehst dein Depot'),
        200,
      );
    });

    testWidgets('zeigt Gewinn je Position in Euro und Prozent', (tester) async {
      await h.pumpPage(tester, const DepotScreen());
      // SAP: 440 € Wert, 300 € bezahlt
      expect(find.text('+140,00 € · +46,67 %'), findsOneWidget);
      expect(find.text('+0,00 € · +0,00 %'), findsOneWidget);
      expect(find.textContaining('heute +10,00 %'), findsOneWidget);
      expect(find.textContaining('kein Kürzel gefunden'), findsOneWidget);
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

    testWidgets('Grafiken: Verlauf, Aufteilung, Gewinn', (tester) async {
      await h.pumpPage(tester, const DepotScreen());
      await tester.tap(find.text('Grafiken'));
      await tester.pumpAndSettle();
      expect(find.text('Verlauf'), findsOneWidget);
      // Verlauf: 2 SAP × 200 € + 30 € fest bis 2 × 220 € + 30 €
      expect(find.textContaining('+40,00 € (+9,30 %)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Gewinn und Verlust'), 200);
      expect(find.text('93,6 %'), findsOneWidget);
      expect(find.text('6,4 %'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('+140,00 € · +46,67 %'), 200);
    });

    test('Verlauf füllt Lücken mit dem letzten Kurs', () {
      PriceHistory hist(List<int> days, List<double> closes) => (
        days: [for (final d in days) DateTime(2026, 1, d)],
        closes: closes,
        currency: 'EUR',
      );
      final points = combineHistory([
        (shares: 2, factor: 1, history: hist([1, 2, 3], [10, 11, 12])),
        (shares: 1, factor: 0.5, history: hist([2, 4], [100, 120])),
      ], 5);
      expect(
        [for (final p in points) p.value],
        [
          5 + 20 + 50, // Tag 1: zweites Papier noch ohne Kurs -> erster Kurs
          5 + 22 + 50,
          5 + 24 + 50,
          5 + 24 + 60,
        ],
      );
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
