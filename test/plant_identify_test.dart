import 'dart:convert';
import 'dart:typed_data';

import 'package:bubududu/features/care.dart';
import 'package:bubududu/features/plant_identify.dart';
import 'package:bubududu/features/plants.dart';
import 'package:bubududu/util/plant_care_hints.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

const _monstera = PlantSuggestion(
  scientificName: 'Monstera deliciosa',
  genus: 'Monstera',
  commonNames: ['köstliches Fensterblatt', 'Monstera'],
  score: 0.91,
);

void main() {
  setUp(seedHousehold);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test('Antwort der Funktion lesen', () {
    final list = parseIdentifyResponse(
      200,
      jsonEncode({
        'suggestions': [
          {
            'scientificName': 'Monstera deliciosa',
            'genus': 'Monstera',
            'commonNames': ['köstliches Fensterblatt'],
            'score': 0.9,
          },
        ],
      }),
    );
    expect(list.single.displayName, 'Köstliches Fensterblatt');
    expect(list.single.percent, 90);
    expect(list.single.careHint, isNotNull);
    expect(
      () => parseIdentifyResponse(503, '{"error":"not-configured"}'),
      throwsA(
        isA<PlantIdentifyException>().having(
          (e) => e.message,
          'message',
          contains('noch nicht eingerichtet'),
        ),
      ),
    );
    expect(
      () => parseIdentifyResponse(500, 'kaputt'),
      throwsA(isA<PlantIdentifyException>()),
    );
  });

  test('Pflegetipps nach Gattung', () {
    expect(careHintFor('Sansevieria trifasciata')!.intervalDays, 21);
    expect(careHintFor('ficus')!.light, 'Hell');
    expect(careHintFor('Unbekanntia'), isNull);
    // Lichtwerte passen zu den Auswahlknöpfen.
    for (final g in ['Monstera', 'Aloe', 'Nephrolepis', 'Ocimum']) {
      expect(plantLights, contains(careHintFor(g)!.light));
    }
  });

  testWidgets('Neue Pflanze per Foto erkennen und anlegen', (tester) async {
    Uint8List? sent;
    await pumpPage(
      tester,
      const CareEditScreen(householdId: 'h1'),
      overrides: [
        plantPhotoPickerProvider.overrideWithValue(
          (ImageSource s) async => Uint8List.fromList(_png),
        ),
        plantIdentifierProvider.overrideWithValue((h, jpeg) async {
          sent = jpeg;
          return [_monstera];
        }),
      ],
    );
    await tester.tap(find.text('Pflanze per Foto erkennen'));
    await settle(tester);
    await tester.tap(find.text('Foto aufnehmen'));
    await settle(tester);
    expect(sent, _png);
    expect(find.text('91%'), findsOneWidget);
    await tester.tap(find.text('Köstliches Fensterblatt'));
    await settle(tester);

    await tester.tap(find.text('Speichern'));
    await settle(tester);
    final care = await db.collection('households/h1/care').get();
    final doc = care.docs.firstWhere(
      (d) => d.data()['name'] == 'Köstliches Fensterblatt',
    );
    final m = doc.data();
    expect(m['species'], 'Monstera deliciosa');
    expect(m['light'], 'Hell');
    expect(m['waterNote'], contains('Staunässe'));
    expect(m['fertilizeDays'], 14);
    expect(m['createdBy'], isNotEmpty);
    final photos = await db.collection('households/h1/plantPhotos').get();
    expect(photos.docs.single.data()['plantId'], doc.id);
    expect((photos.docs.single.data()['image'] as Blob).bytes, _png);
    expect(m['photoId'], photos.docs.single.id);
  });

  testWidgets('Fehler der Erkennung wird angezeigt', (tester) async {
    await pumpPage(
      tester,
      const CareEditScreen(householdId: 'h1'),
      overrides: [
        plantPhotoPickerProvider.overrideWithValue(
          (ImageSource s) async => Uint8List.fromList(_png),
        ),
        plantIdentifierProvider.overrideWithValue(
          (h, jpeg) async =>
              throw const PlantIdentifyException('Keine Verbindung.'),
        ),
      ],
    );
    await tester.tap(find.text('Pflanze per Foto erkennen'));
    await settle(tester);
    await tester.tap(find.text('Foto aufnehmen'));
    await settle(tester);
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Pflanze per Foto erkennen'), findsOneWidget);
  });
}
