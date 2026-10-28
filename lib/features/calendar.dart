import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../gcal/calendar_sync.dart';
import '../gcal/calendar_sync_widgets.dart';
import '../util/dates.dart';
import '../widgets/common.dart';

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
  );
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
        day = nextAnniversary(e.date, now: day.add(const Duration(days: 1)));
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
            : occurrences(list, today(), today().add(const Duration(days: 60)));

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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Termine.'),
              ),
            for (final o in shown)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    o.event.yearly ? Icons.cake_outlined : Icons.event,
                  ),
                ),
                title: Text(o.event.title),
                subtitle: Text(
                  [
                    if (_selected == null) relativeDay(o.day),
                    o.event.time ?? 'ganztägig',
                    o.event.who.isEmpty ? 'Beide' : names[o.event.who] ?? '?',
                    if (o.event.yearly && o.day.year != o.event.date.year)
                      '${o.day.year - o.event.date.year}. Mal',
                  ].join(' · '),
                ),
                onTap: () => _openEdit(context, o.event, null),
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
                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => onTap(day),
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? scheme.primary : null,
                              border: isToday && !isSelected
                                  ? Border.all(color: scheme.primary, width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    color: isSelected ? scheme.onPrimary : null,
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

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked != null) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
                onPressed: () => setState(() => _time = null),
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
