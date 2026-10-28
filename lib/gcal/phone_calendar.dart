import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ein Kalender auf dem Handy, z. B. "kevin@gmail.com" (Google).
typedef PhoneCalendarInfo = ({String id, String name, bool isGoogle});

/// Ein Termin aus dem Handy-Kalender.
typedef PhoneEvent = ({
  String id,
  String title,
  DateTime start,
  bool allDay,
  String? description,
});

/// Zugriff auf den Kalender des Handys. Ist dort ein Google-Konto
/// eingerichtet, gleicht Android die Termine mit dem Google-Kalender ab.
abstract class PhoneCalendar {
  bool get available;
  Future<bool> requestPermission();
  Future<List<PhoneCalendarInfo>> writableCalendars();
  Future<String> create(
    String calendarId, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required bool yearly,
    required String description,
  });
  Future<void> delete(String eventId, {required bool recurring});
  Future<List<PhoneEvent>> list(String calendarId, DateTime from, DateTime to);
}

final phoneCalendarProvider = Provider<PhoneCalendar>(
  (ref) => PluginPhoneCalendar(),
);

class PluginPhoneCalendar implements PhoneCalendar {
  DeviceCalendar get _plugin => DeviceCalendar.instance;

  @override
  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> requestPermission() async =>
      await _plugin.requestPermissions() == CalendarPermissionStatus.granted;

  @override
  Future<List<PhoneCalendarInfo>> writableCalendars() async => [
    for (final c in await _plugin.listCalendars())
      if (!c.readOnly && !c.hidden)
        (
          id: c.id,
          name: c.accountName == null || c.accountName == c.name
              ? c.name
              : '${c.name} (${c.accountName})',
          isGoogle: c.accountType == 'com.google',
        ),
  ];

  @override
  Future<String> create(
    String calendarId, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required bool yearly,
    required String description,
  }) => _plugin.createEvent(
    calendarId: calendarId,
    title: title,
    startDate: start,
    endDate: end,
    isAllDay: allDay,
    description: description,
    recurrenceRule: yearly ? YearlyRecurrence() : null,
  );

  @override
  Future<void> delete(String eventId, {required bool recurring}) async {
    try {
      recurring
          ? await _plugin.deleteRecurring(eventId, EventSpan.allEvents)
          : await _plugin.deleteEvent(instanceId: eventId);
    } on DeviceCalendarException catch (e) {
      // Schon von Hand gelöscht: nichts zu tun.
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
    }
  }

  @override
  Future<List<PhoneEvent>> list(
    String calendarId,
    DateTime from,
    DateTime to,
  ) async => [
    for (final e in await _plugin.listEvents(
      from,
      to,
      calendarIds: [calendarId],
    ))
      (
        id: e.eventId,
        title: e.title,
        start: e.startDate,
        allDay: e.isAllDay,
        description: e.description,
      ),
  ];
}
