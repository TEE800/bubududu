import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// Zeigt und plant Benachrichtigungen auf dem Handy.
/// Im Browser und in Tests passiert nichts ([NoNotifications]).
abstract class Notifications {
  /// Ersetzt alle geplanten Erinnerungen durch [reminders].
  Future<void> replaceReminders(List<Reminder> reminders);

  /// Zeigt sofort eine Benachrichtigung (z. B. Push, während die App offen ist).
  Future<void> show(String title, String body);

  /// Fragt (ab Android 13) nach der Erlaubnis. true = erlaubt.
  Future<bool> requestPermission();
}

class NoNotifications implements Notifications {
  @override
  Future<void> replaceReminders(List<Reminder> reminders) async {}

  @override
  Future<void> show(String title, String body) async {}

  @override
  Future<bool> requestPermission() async => false;
}

final notificationsProvider = Provider<Notifications>(
  (ref) => kIsWeb ? NoNotifications() : LocalNotifications.instance,
);

class LocalNotifications implements Notifications {
  LocalNotifications._();

  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static const _reminders = AndroidNotificationDetails(
    'erinnerungen',
    'Erinnerungen',
    channelDescription: 'Termine, Aufgaben, Fristen und Pflege',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF1B5E20),
  );

  static const _partner = AndroidNotificationDetails(
    'partner',
    'Neues vom Partner',
    channelDescription: 'Wenn Bubu oder Dudu etwas einträgt',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF1B5E20),
  );

  /// Einmal beim Start aufrufen. Fehler stören den Start nicht.
  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tz.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      // Kanäle vorab anlegen, damit Push-Nachrichten vom Server sie finden.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final c in [_reminders, _partner]) {
        await android?.createNotificationChannel(
          AndroidNotificationChannel(
            c.channelId,
            c.channelName,
            description: c.channelDescription,
            importance: c.importance,
          ),
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Benachrichtigungen nicht verfügbar: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replaceReminders(List<Reminder> reminders) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        title: r.title,
        body: r.body,
        notificationDetails: const NotificationDetails(
          android: _reminders,
          iOS: DarwinNotificationDetails(),
        ),
        // Ungefähr pünktlich reicht und braucht keine Sonder-Erlaubnis.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> show(String title, String body) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _partner,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
