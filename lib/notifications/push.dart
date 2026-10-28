import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/household_repository.dart';
import 'local.dart';

/// Push-Nachrichten vom Server ("Bubu hat Milch auf die Einkaufsliste gesetzt").
/// Der Server-Teil liegt in functions/index.js.
///
/// Wir nutzen bewusst noch die FCM-Tokens (getToken), weil der Server sie mit
/// firebase-admin direkt ansprechen kann.
// ignore_for_file: deprecated_member_use
class Push {
  Push._();

  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _foreground;

  /// Meldet dieses Gerät für [uid] an. Fehler (z. B. ohne Google-Dienste)
  /// werden nur geloggt.
  static Future<void> register({
    required String uid,
    required HouseholdRepository repo,
    required Notifications local,
  }) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await repo.addPushToken(uid, token);
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen(
        (t) => repo.addPushToken(uid, t),
      );
      // Ist die App offen, zeigt Android Push nicht von selbst an.
      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) local.show(n.title ?? '', n.body ?? '');
      });
    } catch (e) {
      debugPrint('Push nicht verfügbar: $e');
    }
  }

  /// Beim Abmelden: dieses Gerät bekommt keine Nachrichten mehr für [uid].
  static Future<void> unregister({
    required String uid,
    required HouseholdRepository repo,
  }) async {
    if (kIsWeb) return;
    try {
      await _refresh?.cancel();
      await _foreground?.cancel();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await repo.removePushToken(uid, token);
    } catch (e) {
      debugPrint('Push abmelden fehlgeschlagen: $e');
    }
  }
}
