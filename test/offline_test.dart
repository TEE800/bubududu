import 'dart:async';

import 'package:bubududu/data/offline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Schreiben wartet nicht auf den Server', () async {
    // Ohne Netz endet der Firestore-Future nie.
    final neverConfirmed = Completer<void>().future;
    await writeInBackground(neverConfirmed)
        .timeout(const Duration(milliseconds: 100));
  });

  Widget app(Stream<bool> online) => ProviderScope(
    overrides: [onlineProvider.overrideWith((ref) => online)],
    child: MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      builder: (context, child) => OfflineBanner(child: child!),
      home: const Scaffold(body: Text('Einkaufsliste')),
    ),
  );

  testWidgets('Hinweis erscheint nur ohne Netz', (tester) async {
    final online = StreamController<bool>();
    addTearDown(online.close);
    await tester.pumpWidget(app(online.stream));
    online.add(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsNothing);
    expect(find.text('Einkaufsliste'), findsOneWidget);

    online.add(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.text('Einkaufsliste'), findsOneWidget);
  });

  testWidgets('Scheitert der Abgleich, gibt es einen Hinweis', (tester) async {
    await tester.pumpWidget(app(Stream.value(true)));
    await writeInBackground(Future.error(StateError('permission-denied')));
    await tester.pumpAndSettle();
    expect(
      find.text('Eine Änderung konnte nicht gespeichert werden.'),
      findsOneWidget,
    );
  });
}
