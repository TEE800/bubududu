import 'dart:convert';
import 'dart:typed_data';

import 'package:bubududu/screens/shopping_screen.dart';
import 'package:bubududu/widgets/item_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers.dart';

/// Ein Pixel als PNG, damit Image.memory etwas anzeigen kann.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  group('Symbole', () {
    test('passende Symbole aus dem Namen', () {
      expect(itemSymbol('Milch'), '🥛');
      expect(itemSymbol('2 Liter Hafermilch'), '🥛');
      expect(itemSymbol('Bananen'), '🍌');
      expect(itemSymbol('Klopapier'), '🧻');
      expect(itemSymbol('Eier'), '🥚');
      expect(itemSymbol('Spaghetti'), '🍝');
      expect(itemSymbol('Erdnussbutter'), '🥜');
    });

    test('kurze Stichworte nur als ganzes Wort', () {
      expect(itemSymbol('Reis'), '🍚');
      expect(itemSymbol('Eis'), '🍦');
      expect(itemSymbol('Eimer'), '🛒');
      expect(itemSymbol('Pfeffer'), '🧂');
    });

    test('Unbekanntes bekommt den Einkaufswagen', () {
      expect(itemSymbol('Geschenk für Oma'), '🛒');
      expect(itemSymbol(''), '🛒');
    });

    test('Foto-Schlüssel ist unabhängig von Groß-/Kleinschreibung', () {
      expect(itemPhotoKey(' Milch '), itemPhotoKey('milch'));
      expect(itemPhotoKey('Saft 1/2 Liter'), 'saft 1-2 liter');
      expect(itemPhotoKey('..'), '_');
    });
  });

  group('Produktfoto', () {
    setUp(seedHousehold);

    testWidgets('Foto aus der Galerie ersetzt das Symbol', (tester) async {
      await pumpPage(
        tester,
        const ShoppingScreen(householdId: 'h1'),
        overrides: [
          itemPhotoPickerProvider.overrideWithValue(
            (source) async => source == ImageSource.gallery
                ? Uint8List.fromList(_png)
                : null,
          ),
        ],
      );
      expect(find.text('🥛'), findsOneWidget);

      await tester.tap(find.byTooltip('Produktfoto').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus der Galerie'));
      await tester.pumpAndSettle();

      final doc = await db.doc('households/h1/itemPhotos/milch').get();
      expect(doc.data()?['image'], isA<Blob>());
      expect(find.text('🥛'), findsNothing);

      // Wieder entfernen: das Symbol ist zurück.
      await tester.tap(find.byTooltip('Produktfoto').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto entfernen, Symbol zeigen'));
      await tester.pumpAndSettle();
      expect(find.text('🥛'), findsOneWidget);
    });
  });
}
