import 'dart:io';

import 'package:bubududu/widgets/mascots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stimmung je nach Tageszeit', () {
    expect(moodForTime(DateTime(2026, 1, 1, 6)), MascotMood.sleepy);
    expect(moodForTime(DateTime(2026, 1, 1, 9)), MascotMood.happy);
    expect(moodForTime(DateTime(2026, 1, 1, 12, 30)), MascotMood.hungry);
    expect(moodForTime(DateTime(2026, 1, 1, 23)), MascotMood.sleepy);
  });

  test('Für jede Stimmung gibt es ein Bild', () {
    for (final mood in MascotMood.values) {
      expect(
        File(Mascots.assetFor(mood)).existsSync(),
        isTrue,
        reason: mood.name,
      );
    }
    for (final one in ['dudu', 'bubu']) {
      expect(
        File(Mascots.assetFor(MascotMood.happy, only: one)).existsSync(),
        isTrue,
      );
    }
  });

  for (final mood in MascotMood.values) {
    testWidgets('Bubu und Dudu: ${mood.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: Mascots(mood: mood)),
        ),
      );
      // Wippen klingt aus, danach steht alles still.
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Bubu und Dudu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Einzeln: nur Dudu', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Mascots(only: 'dudu')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
