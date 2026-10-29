import 'dart:convert';
import 'dart:typed_data';

import 'package:bubududu/data/store.dart';
import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/plants.dart';
import 'package:bubududu/util/dates.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';

/// Ein 1×1-Pixel-PNG als Testfoto.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  late String monstera;

  setUp(() async {
    await seedHousehold();
    final care = await db.collection('households/h1/care').get();
    monstera = care.docs.single.id;
    await db.doc('households/h1/care/$monstera').update({
      'species': 'Monstera deliciosa',
      'location': 'Wohnzimmer am Fenster',
      'light': 'Hell',
      'waterNote': 'Erde antrocknen lassen',
      'fertilizeDays': 14,
      'fertilizeNote': 'Grünpflanzendünger',
    });
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> addPhoto(DateTime takenAt) async {
    await db.collection('households/h1/plantPhotos').add({
      'plantId': monstera,
      'takenAt': Timestamp.fromDate(takenAt),
      'image': Blob(_png),
    });
  }

  Future<List<Map<String, dynamic>>> photos() async => [
    for (final d
        in (await db.collection('households/h1/plantPhotos').get()).docs)
      d.data(),
  ];

  testWidgets('Profil zeigt Standort, Gießen und Düngen', (tester) async {
    await pumpPage(
      tester,
      PlantProfileScreen(householdId: 'h1', plantId: monstera),
    );
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    expect(find.text('Wohnzimmer am Fenster'), findsOneWidget);
    expect(find.text('Gießen alle 7 Tage'), findsOneWidget);
    expect(find.text('Düngen alle 14 Tage'), findsOneWidget);
    expect(find.text('Noch kein Foto'), findsOneWidget);

    await tester.tap(find.text('Gedüngt'));
    await settle(tester);
    final m = (await db.doc('households/h1/care/$monstera').get()).data()!;
    expect(readDate(m['lastFertilized']), today());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Foto aufnehmen wird gespeichert und Vorschaubild', (
    tester,
  ) async {
    await pumpPage(
      tester,
      PlantProfileScreen(householdId: 'h1', plantId: monstera),
      overrides: [
        plantPhotoPickerProvider.overrideWithValue(
          (ImageSource s) async => Uint8List.fromList(_png),
        ),
      ],
    );
    await tester.tap(find.text('Foto'));
    await settle(tester);
    await tester.tap(find.text('Foto aufnehmen'));
    await settle(tester);

    final all = await photos();
    expect(all, hasLength(1));
    expect(all.single['plantId'], monstera);
    expect((all.single['image'] as Blob).bytes, _png);
    final m = (await db.doc('households/h1/care/$monstera').get()).data()!;
    expect(m['photoId'], isNotEmpty);
    expect(find.text('Noch kein Foto'), findsNothing);
  });

  testWidgets('Zeitraffer spielt die Fotos der Reihe nach', (tester) async {
    final t = today();
    await addPhoto(addDays(t, -60));
    await addPhoto(addDays(t, -30));
    await addPhoto(t);
    await pumpPage(
      tester,
      PlantTimelapseScreen(householdId: 'h1', plantId: monstera),
    );
    expect(find.text('Erstes Foto · Foto 1 von 3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('nach 4 Wochen · Foto 2 von 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('nach 4 Wochen · Foto 2 von 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Vorher / Nachher'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Vorher'), findsOneWidget);
    expect(find.textContaining('Nachher'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pflanze löschen löscht auch ihre Fotos', (tester) async {
    await addPhoto(today());
    final item = CareItem.fromDoc(
      Doc(
        monstera,
        (await db.doc('households/h1/care/$monstera').get()).data()!,
      ),
    );
    await pumpPage(tester, CareEditScreen(householdId: 'h1', item: item));
    await tester.tap(find.byTooltip('Löschen'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await settle(tester);
    expect(await photos(), isEmpty);
    expect((await db.collection('households/h1/care').get()).docs, isEmpty);
  });

  testWidgets('Neue Pflanze mit Profil anlegen', (tester) async {
    await pumpPage(tester, const CareEditScreen(householdId: 'h1'));
    Future<void> fill(String label, String text) async {
      final field = find.widgetWithText(TextField, label);
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(field, text);
    }

    await fill('Name', 'Ficus');
    await fill('Standort', 'Schlafzimmer');
    await fill('Düngen alle wie viele Tage?', '30');
    await tester.scrollUntilVisible(
      find.text('Halbschatten'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Halbschatten'));
    await tester.tap(find.text('Speichern'));
    await settle(tester);
    final ficus = (await db.collection('households/h1/care').get()).docs
        .map((d) => d.data())
        .firstWhere((d) => d['name'] == 'Ficus');
    expect(ficus['location'], 'Schlafzimmer');
    expect(ficus['fertilizeDays'], 30);
    expect(ficus['light'], 'Halbschatten');
  });

  test('Wachstumstext', () {
    final d = DateTime(2026, 1, 1);
    expect(growthText(d, d), 'Erstes Foto');
    expect(growthText(d, DateTime(2026, 1, 4)), 'nach 3 Tagen');
    expect(growthText(d, DateTime(2026, 2, 1)), 'nach 4 Wochen');
    expect(growthText(d, DateTime(2026, 7, 1)), 'nach 6 Monaten');
  });
}
