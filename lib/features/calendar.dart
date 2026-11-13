import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../gcal/calendar_sync.dart';
import '../gcal/calendar_sync_widgets.dart';
import '../util/dates.dart';
import '../util/symbols.dart';
import '../widgets/common.dart';
import '../widgets/cute.dart';
import '../widgets/pic_tile.dart';

/// households/{id}/events: Termine, Geburtstage, Jahrestage.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.who,
    required this.yearly,
    required this.note,
    this.createdBy = '',
    this.googleId,
    this.reminders,
  });

  final String id;
  final String title;
  final DateTime date;

  /// "18:30" oder null für ganztägig.
  final String? time;

  /// uid oder '' für beide.
  final String who;

  /// Jedes Jahr wiederholen (Geburtstage, Jahrestage).
  final bool yearly;
  final String note;
  final String createdBy;

  /// Aus dem Google-Kalender von [createdBy] übernommen (Termin-ID dort).
  final String? googleId;

  /// Gewählte Erinnerungen (Codes aus [timedReminderOptions] bzw.
  /// [allDayReminderOptions]). null = Standard, leer = keine Erinnerung.
  final List<String>? reminders;

  /// Die Erinnerungen, die tatsächlich gelten.
  List<String> get activeReminders =>
      reminders ?? defaultReminders(timed: time != null, yearly: yearly);

  factory CalendarEvent.fromDoc(Doc d) => CalendarEvent(
    id: d.id,
    title: d.data['title'] as String? ?? '',
    date: readDate(d.data['date']) ?? today(),
    time: d.data['time'] as String?,
    who: d.data['who'] as String? ?? '',
    yearly: d.data['yearly'] as bool? ?? false,
    note: d.data['note'] as String? ?? '',
    createdBy: d.data['createdBy'] as String? ?? '',
    googleId: d.data['googleId'] as String?,
    reminders: (d.data['reminders'] as List?)?.whereType<String>().toList(),
  );
}

/// Eine Auswahl, wann vor einem Termin erinnert wird.
class ReminderOption {
  const ReminderOption(
    this.code,
    this.label,
    this.prefix, {
    this.days = 0,
    this.minutes = 0,
  });

  /// Wird so in Firestore gespeichert.
  final String code;

  /// Text auf dem Auswahl-Chip.
  final String label;

  /// Anfang der Benachrichtigung, z. B. "In einer Stunde".
  final String prefix;
  final int days;
  final int minutes;
}

/// Für Termine mit Uhrzeit: so lange vor dem Beginn.
const timedReminderOptions = [
  ReminderOption('0m', 'Zum Beginn', 'Jetzt'),
  ReminderOption('10m', '10 Min. vorher', 'In 10 Minuten', minutes: 10),
  ReminderOption('30m', '30 Min. vorher', 'In 30 Minuten', minutes: 30),
  ReminderOption('1h', '1 Std. vorher', 'In einer Stunde', minutes: 60),
  ReminderOption('2h', '2 Std. vorher', 'In zwei Stunden', minutes: 120),
  ReminderOption('1d', '1 Tag vorher', 'Morgen', days: 1),
  ReminderOption('2d', '2 Tage vorher', 'Übermorgen', days: 2),
  ReminderOption('1w', '1 Woche vorher', 'In einer Woche', days: 7),
];

/// Für ganztägige Termine: am Tag um 8 Uhr, sonst am Abend davor um 18 Uhr.
const allDayReminderOptions = [
  ReminderOption('0d', 'Am Tag, 8 Uhr', 'Heute'),
  ReminderOption('1d', 'Vortag, 18 Uhr', 'Morgen', days: 1),
  ReminderOption('2d', '2 Tage vorher', 'Übermorgen', days: 2),
  ReminderOption('1w', '1 Woche vorher', 'In einer Woche', days: 7),
];

List<ReminderOption> reminderOptions({required bool timed}) =>
    timed ? timedReminderOptions : allDayReminderOptions;

/// Was gilt, wenn man nichts auswählt (so wie es die App schon immer machte).
List<String> defaultReminders({required bool timed, required bool yearly}) => [
  timed ? '1h' : '0d',
  if (yearly) '1d',
];

/// Passt die Auswahl an, wenn ein Termin Uhrzeit bekommt oder ganztägig wird.
List<String> convertReminders(List<String> codes, {required bool timed}) {
  final valid = {for (final o in reminderOptions(timed: timed)) o.code};
  return {
    for (final c in codes)
      if (valid.contains(c))
        c
      else if (c == '0m' && !timed)
        '0d'
      else if (c == '0d' && timed)
        '0m',
  }.toList();
}

/// Ein Vorkommen eines Termins an einem bestimmten Tag.
typedef Occurrence = ({DateTime day, CalendarEvent event});

/// Alle Vorkommen zwischen [from] und [to] (beide inklusive), nach Tag und Uhrzeit sortiert.
List<Occurrence> occurrences(
  List<CalendarEvent> events,
  DateTime from,
  DateTime to,
) {
  final start = dateOnly(from), end = dateOnly(to);
  final result = <Occurrence>[];
  for (final e in events) {
    if (e.yearly) {
      var day = nextAnniversary(e.date, now: start);
      while (!day.isAfter(end)) {
        if (!day.isBefore(dateOnly(e.date))) result.add((day: day, event: e));
        day = nextAnniversary(e.date, now: addDays(day, 1));
      }
    } else {
      final day = dateOnly(e.date);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        result.add((day: day, event: e));
      }
    }
  }
  result.sort((a, b) {
    final c = a.day.compareTo(b.day);
    if (c != 0) return c;
    return (a.event.time ?? '').compareTo(b.event.time ?? '');
  });
  return result;
}

final eventsProvider = Provider.family<AsyncValue<List<CalendarEvent>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'events')),
      )
      .whenData((docs) => docs.map(CalendarEvent.fromDoc).toList()),
);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected;

  void _shiftMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider(widget.householdId));
    final names = memberNames(ref, widget.householdId);
    final uid = ref.watch(uidProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          if (ref.watch(syncCalendarProvider).value != null)
            IconButton(
              tooltip: 'Aus Google-Kalender holen',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => showImportSheet(context, widget.householdId),
            ),
          IconButton(
            tooltip: 'Heute',
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              _month = DateTime(DateTime.now().year, DateTime.now().month);
              _selected = today();
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Termin'),
        onPressed: () => _openEdit(context, null, _selected),
      ),
      body: asyncBody(events, (list) {
        final monthEnd = DateTime(_month.year, _month.month + 1, 0);
        final inMonth = occurrences(list, _month, monthEnd);
        final daysWithEvents = {for (final o in inMonth) o.day};
        final shown = _selected != null
            ? inMonth.where((o) => o.day == _selected).toList()
            : occurrences(list, today(), addDays(today(), 60));

        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Voriger Monat',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Nächster Monat',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            MonthGrid(
              month: _month,
              selected: _selected,
              marked: daysWithEvents,
              onTap: (d) =>
                  setState(() => _selected = _selected == d ? null : d),
            ),
            SectionHeader(
              _selected == null
                  ? 'Die nächsten 60 Tage'
                  : relativeDay(_selected!),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _selected == null
                      ? 'In den nächsten 60 Tagen steht nichts an. '
                            'Tippe auf „Termin“, um etwas einzutragen.'
                      : 'An diesem Tag steht nichts an.',
                ),
              ),
            if (shown.isNotEmpty)
              PicGrid(
                tileHeight: 196,
                children: [
                  for (final o in shown)
                    PicTile(
                      title: o.event.title,
                      emoji: symbolFor(
                        o.event.title,
                        eventSymbols,
                        o.event.yearly ? '🎉' : '📅',
                      ),
                      tone: toneForAssignee(o.event.who, uid),
                      badge: _selected == null
                          ? relativeDay(o.day)
                          : (o.event.time ?? 'ganztägig'),
                      subtitle: [
                        if (_selected == null) o.event.time ?? 'ganztägig',
                        o.event.who.isEmpty
                            ? 'Beide'
                            : names[o.event.who] ?? '?',
                        if (o.event.yearly && o.day.year != o.event.date.year)
                          '${o.day.year - o.event.date.year}. Mal',
                      ].join(' · '),
                      onTap: () => _openEdit(context, o.event, null),
                    ),
                ],
              ),
          ],
        );
      }),
    );
  }

  void _openEdit(BuildContext context, CalendarEvent? e, DateTime? day) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventEditScreen(
            householdId: widget.householdId,
            event: e,
            initialDate: day,
          ),
        ),
      );
}

/// Einfache Monatsansicht: Montag bis Sonntag, Punkte unter Tagen mit Terminen.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  final DateTime month;
  final DateTime? selected;
  final Set<DateTime> marked;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final t = today();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = r * 7 + c - leading + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 44);
                        }
                        final day = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        final isSelected = day == selected;
                        final isToday = day == t;
                        // Für Screenreader: "Mittwoch, 28. Oktober, Termine".
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label:
                              '${weekdayLong(day)}, $dayNumber. ${monthNames[day.month - 1]}'
                              '${isToday ? ', heute' : ''}'
                              '${marked.contains(day) ? ', Termine' : ''}',
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => onTap(day),
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? scheme.primary : null,
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: scheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: marked.contains(day)
                                          ? (isSelected
                                                ? scheme.onPrimary
                                                : scheme.primary)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({
    super.key,
    required this.householdId,
    this.event,
    this.initialDate,
  });

  final String householdId;
  final CalendarEvent? event;
  final DateTime? initialDate;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _note = TextEditingController(text: widget.event?.note);
  late DateTime _date = widget.event?.date ?? widget.initialDate ?? today();
  late String? _time = widget.event?.time;
  late String _who = widget.event?.who ?? '';
  late bool _yearly = widget.event?.yearly ?? false;

  /// null = Standard, der sich nach Uhrzeit und "Jedes Jahr" richtet.
  late List<String>? _reminders = widget.event?.reminders;

  List<String> get _activeReminders =>
      _reminders ?? defaultReminders(timed: _time != null, yearly: _yearly);

  void _setTime(String? time) {
    final wasTimed = _time != null;
    _time = time;
    if (_reminders != null && wasTimed != (time != null)) {
      _reminders = convertReminders(_reminders!, timed: time != null);
    }
  }

  void _toggleReminder(String code, bool on) {
    final next = [..._activeReminders]..remove(code);
    if (on) next.add(code);
    setState(() => _reminders = next);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time?.split(':');
    final hour = int.tryParse(parts?.first ?? '');
    final minute = int.tryParse(parts?.last ?? '');
    final picked = await showTimePicker(
      context: context,
      initialTime: hour == null || minute == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) {
      setState(() {
        _setTime(
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        );
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return showError(context, 'Bitte gib dem Termin einen Namen.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'events',
      widget.event?.id,
      {
        'title': title,
        'date': writeDate(_date),
        'time': _time,
        'who': _who,
        'yearly': _yearly,
        'reminders': _activeReminders,
        'note': _note.text.trim(),
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return EditScaffold(
      title: event == null ? 'Neuer Termin' : 'Termin bearbeiten',
      onSave: _save,
      onDelete: event == null
          ? null
          : () async {
              if (!await confirmDelete(context, event.title) ||
                  !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('events', event.id);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: event == null,
          decoration: const InputDecoration(
            labelText: 'Was?',
            hintText: 'z. B. Essen bei Oma',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        DateField(
          label: 'Datum',
          value: _date,
          allowClear: false,
          onChanged: (v) => setState(() => _date = v ?? _date),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(_time == null ? 'Ganztägig' : '$_time Uhr'),
                onPressed: _pickTime,
              ),
            ),
            if (_time != null)
              IconButton(
                tooltip: 'Ganztägig',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _setTime(null)),
              ),
          ],
        ),
        MemberPicker(
          householdId: widget.householdId,
          value: _who,
          onChanged: (v) => setState(() => _who = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Jedes Jahr'),
          subtitle: const Text('Für Geburtstage und Jahrestage'),
          value: _yearly,
          onChanged: (v) => setState(() => _yearly = v),
        ),
        _ReminderPicker(
          timed: _time != null,
          selected: _activeReminders,
          onToggle: _toggleReminder,
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Notiz (optional)'),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

/// Auswahl, wann die App vor dem Termin erinnert (mehrere möglich).
class _ReminderPicker extends StatelessWidget {
  const _ReminderPicker({
    required this.timed,
    required this.selected,
    required this.onToggle,
  });

  final bool timed;
  final List<String> selected;
  final void Function(String code, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              selected.isEmpty
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('Erinnern', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in reminderOptions(timed: timed))
              FilterChip(
                label: Text(o.label),
                selected: selected.contains(o.code),
                onSelected: (on) => onToggle(o.code, on),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          selected.isEmpty ? 'Keine Erinnerung für diesen Termin.' : 'Kommt als Benachrichtigung aufs Handy, bei allen, für die der Termin ist.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
