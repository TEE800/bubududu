import 'dart:convert';
import 'dart:typed_data';

import 'package:bubududu/screens/recipes_screen.dart';
import 'package:bubududu/services/dish_image.dart';
import 'package:bubududu/widgets/recipe_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';

/// Ein Pixel als PNG, damit Image.memory etwas anzeigen kann.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  setUp(seedHousehold);

  Future<String> recipeId() async =>
      (await db.collection('households/h1/recipes').get()).docs.single.id;

  testWidgets('Inhalt antippen schlägt die Rezeptseite auf', (tester) async {
    final searched = <String>[];
    await pumpPage(
      tester,
      const RecipesScreen(householdId: 'h1'),
      overrides: [
        dishImageFinderProvider.overrideWithValue((title) async {
          searched.add(title);
          return null;
        }),
      ],
    );
    expect(find.text('Unser Kochbuch'), findsOneWidget);
    expect(find.text('Neues Rezept'), findsOneWidget);

    await tester.tap(find.text('Pfannkuchen'));
    await tester.pumpAndSettle();
    expect(find.text('ZUTATEN'), findsOneWidget);
    expect(find.text('Mehl'), findsOneWidget);
    expect(find.text('– 2 –'), findsOneWidget);
    // Auf der Rezeptseite gibt es Bearbeiten statt "Neues Rezept".
    expect(find.byTooltip('Bearbeiten'), findsOneWidget);
    expect(find.text('Neues Rezept'), findsNothing);

    // Kein passendes Bild gefunden: wird gemerkt, damit nicht jedes Mal
    // neu gesucht wird.
    expect(searched, ['Pfannkuchen']);
    final doc = await db.doc('households/h1/recipes/${await recipeId()}').get();
    expect(doc.data()?['imageUrl'], '');

    await tester.tap(find.byTooltip('Inhalt'));
    await tester.pumpAndSettle();
    expect(find.text('Unser Kochbuch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gefundenes Bild wird gespeichert, eigenes Foto ersetzt es', (
    tester,
  ) async {
    final id = await recipeId();
    await pumpPage(
      tester,
      RecipeDetailScreen(householdId: 'h1', recipeId: id),
      overrides: [
        dishImageFinderProvider.overrideWithValue(
          (title) async => const DishImage(
            url: 'https://upload.wikimedia.org/pfannkuchen.jpg',
            page: 'https://de.wikipedia.org/wiki/Pfannkuchen',
          ),
        ),
        recipePhotoPickerProvider.overrideWithValue(
          (source) async =>
              source == ImageSource.gallery ? Uint8List.fromList(_png) : null,
        ),
      ],
    );
    await tester.pumpAndSettle();
    var doc = await db.doc('households/h1/recipes/$id').get();
    expect(
      doc.data()?['imageUrl'],
      'https://upload.wikimedia.org/pfannkuchen.jpg',
    );
    expect(
      doc.data()?['imagePage'],
      'https://de.wikipedia.org/wiki/Pfannkuchen',
    );
    expect(find.text('Bild: Wikipedia'), findsOneWidget);

    await tester.tap(find.text('Eigenes Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus der Galerie'));
    await tester.pumpAndSettle();
    final photo = await db.doc('households/h1/recipePhotos/$id').get();
    expect(photo.data()?['image'], isA<Blob>());
    expect(find.text('Foto ändern'), findsOneWidget);
    expect(find.text('Bild: Wikipedia'), findsNothing);

    // Rezept löschen nimmt das eigene Foto mit.
    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen').last);
    await tester.pumpAndSettle();
    expect(
      (await db.doc('households/h1/recipePhotos/$id').get()).exists,
      isFalse,
    );
    doc = await db.doc('households/h1/recipes/$id').get();
    expect(doc.exists, isFalse);
  });
}
