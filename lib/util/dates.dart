import 'package:cloud_firestore/cloud_firestore.dart';

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _weekdaysLong = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const monthNames = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

String weekdayLong(DateTime d) => _weekdaysLong[d.weekday - 1];

/// "Mo, 3. November 2026" (Jahr nur, wenn es nicht das aktuelle ist).
String formatDate(DateTime d, {DateTime? now}) {
  final year = d.year == (now ?? DateTime.now()).year ? '' : ' ${d.year}';
  return '${weekdayShort(d)}, ${d.day}. ${monthNames[d.month - 1]}$year';
}

String formatShortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// "Heute", "Morgen", "Gestern" oder das Datum.
String relativeDay(DateTime d, {DateTime? now}) {
  final diff = daysBetween(now ?? DateTime.now(), d);
  return switch (diff) {
    0 => 'Heute',
    1 => 'Morgen',
    -1 => 'Gestern',
    _ => formatDate(d, now: now),
  };
}

/// "in 3 Tagen", "seit 2 Tagen überfällig" usw.
String dueText(DateTime due, {DateTime? now}) {
  final diff = daysBetween(now ?? DateTime.now(), due);
  if (diff == 0) return 'heute';
  if (diff == 1) return 'morgen';
  if (diff > 1) return 'in $diff Tagen';
  if (diff == -1) return 'seit gestern fällig';
  return 'seit ${-diff} Tagen fällig';
}

enum Repeat {
  none('Einmalig'),
  daily('Täglich'),
  weekly('Wöchentlich'),
  biweekly('Alle 2 Wochen'),
  monthly('Monatlich');

  const Repeat(this.label);
  final String label;

  static Repeat parse(String? name) =>
      Repeat.values.where((r) => r.name == name).firstOrNull ?? Repeat.none;
}

/// Nächster Termin nach [from] für eine Wiederholung. Monatlich bleibt beim
/// selben Tag, bei kürzeren Monaten wird auf den letzten Tag gekürzt.
DateTime nextOccurrence(DateTime from, Repeat repeat) {
  switch (repeat) {
    case Repeat.none:
      return from;
    case Repeat.daily:
      return DateTime(from.year, from.month, from.day + 1);
    case Repeat.weekly:
      return DateTime(from.year, from.month, from.day + 7);
    case Repeat.biweekly:
      return DateTime(from.year, from.month, from.day + 14);
    case Repeat.monthly:
      final lastDay = DateTime(from.year, from.month + 2, 0).day;
      return DateTime(
        from.year,
        from.month + 1,
        from.day > lastDay ? lastDay : from.day,
      );
  }
}

/// Nächster Jahrestag (heute zählt mit). 29. Februar fällt in
/// Nicht-Schaltjahren auf den 28.
DateTime nextAnniversary(DateTime date, {DateTime? now}) {
  final t = dateOnly(now ?? DateTime.now());
  DateTime inYear(int year) {
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day > lastDay ? lastDay : date.day);
  }

  final thisYear = inYear(t.year);
  return thisYear.isBefore(t) ? inYear(t.year + 1) : thisYear;
}

DateTime? readDate(Object? value) => switch (value) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

Timestamp? writeDate(DateTime? d) =>
    d == null ? null : Timestamp.fromDate(dateOnly(d));
