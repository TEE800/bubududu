import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

const defaultPackingList = [
  'Ausweis',
  'Handy-Ladekabel',
  'Kopfhörer',
  'Zahnbürste',
  'Zahnpasta',
  'Duschzeug',
  'Deo',
  'Medikamente',
  'Unterwäsche',
  'Socken',
  'T-Shirts',
  'Hosen',
  'Pullover',
  'Schlafsachen',
  'Schuhe',
  'Sonnenbrille',
];

typedef PackItem = ({String text, bool done});

/// households/{id}/trips: Reisen und Ausflüge mit Packliste.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.packing,
    required this.notes,
  });

  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final List<PackItem> packing;
  final String notes;

  factory Trip.fromDoc(Doc d) => Trip(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    start: readDate(d.data['start']),
    end: readDate(d.data['end']),
    packing: [
      for (final p in (d.data['packing'] as List? ?? const []))
        if (p is Map)
          (text: p['text'] as String? ?? '', done: p['done'] as bool? ?? false),
    ],
    notes: d.data['notes'] as String? ?? '',
  );
}

List<Map<String, Object>> packingToData(List<PackItem> items) => [
  for (final p in items) {'text': p.text, 'done': p.done},
];

final tripsProvider = Provider.family<AsyncValue<List<Trip>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'trips')),
      )
      .whenData((docs) => sortTrips(docs.map(Trip.fromDoc).toList())),
);

/// Vorbei, wenn das Ende (oder ohne Ende der Anfang) vor [today] liegt.
bool tripIsPast(Trip t, DateTime today) =>
    (t.end ?? t.start)?.isBefore(dateOnly(today)) ?? false;

/// Kommende und laufende Reisen nach Datum, dann ohne Datum,
/// vergangene ganz unten (die letzte zuerst).
List<Trip> sortTrips(List<Trip> list, {DateTime? now}) {
  final t = dateOnly(now ?? DateTime.now());
  int group(Trip trip) => tripIsPast(trip, t)
      ? 2
      : trip.start == null
      ? 1
      : 0;
  return list..sort((a, b) {
    final g = group(a).compareTo(group(b));
    if (g != 0) return g;
    return switch (group(a)) {
      0 => a.start!.compareTo(b.start!),
      2 => (b.end ?? b.start)!.compareTo((a.end ?? a.start)!),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
  });
}

String tripDates(Trip t) {
  if (t.start == null) return 'Noch kein Datum';
  final s = formatShortDate(t.start!);
  return t.end == null ? s : '$s – ${formatShortDate(t.end!)}';
}

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider(householdId));
    return Scaffold(
      appBar: AppBar(title: const Text('Reisen & Ausflüge')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Reise'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripEditScreen(householdId: householdId),
          ),
        ),
      ),
      body: asyncBody(trips, (list) {
        if (list.isEmpty) {
          return const EmptyHint(
            icon: Icons.luggage_outlined,
            mood: MascotMood.travel,
            text: 'Plant hier Urlaube und Ausflüge, inklusive gemeinsamer Packliste.',
          );
        }
        final t = today();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final trip in list)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.luggage_outlined),
                  title: Text(trip.name),
                  subtitle: Text(
                    [
                      tripDates(trip),
                      if (tripIsPast(trip, t)) 'vorbei',
                      if (trip.start != null && trip.start!.isAfter(t))
                        dueText(trip.start!),
                      if (trip.packing.isNotEmpty)
                        '${trip.packing.where((p) => p.done).length}/${trip.packing.length} gepackt',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripDetailScreen(
                        householdId: householdId,
                        tripId: trip.id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.householdId,
    required this.tripId,
  });

  final String householdId;
  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final _newItem = TextEditingController();

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  Future<void> _setPacking(List<PackItem> items) => ref
      .read(storeProvider(widget.householdId))
      .update('trips', widget.tripId, {'packing': packingToData(items)});

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider(widget.householdId));
    final trip = trips.value?.where((t) => t.id == widget.tripId).firstOrNull;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: trips.isLoading
              ? const CircularProgressIndicator()
              : const Text('Diese Reise gibt es nicht mehr.'),
        ),
      );
    }
    final packing = trip.packing;

    void add() {
      final text = _newItem.text.trim();
      if (text.isEmpty) return;
      _setPacking([...packing, (text: text, done: false)]);
      _newItem.clear();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TripEditScreen(householdId: widget.householdId, trip: trip),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(tripDates(trip)),
          ),
          if (trip.notes.isNotEmpty)
            ListTile(leading: const Icon(Icons.notes), title: Text(trip.notes)),
          const SectionHeader('Packliste'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _newItem,
              decoration: InputDecoration(
                hintText: 'Was muss mit?',
                suffixIcon: IconButton(
                  tooltip: 'Hinzufügen',
                  icon: const Icon(Icons.add),
                  onPressed: add,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => add(),
            ),
          ),
          if (packing.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: const Text('Standard-Packliste übernehmen'),
                onPressed: () => _setPacking([
                  for (final t in defaultPackingList) (text: t, done: false),
                ]),
              ),
            ),
          for (var i = 0; i < packing.length; i++)
            CheckboxListTile(
              value: packing[i].done,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                packing[i].text,
                style: packing[i].done
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              secondary: IconButton(
                tooltip: 'Löschen',
                icon: const Icon(Icons.close),
                onPressed: () => _setPacking([...packing]..removeAt(i)),
              ),
              onChanged: (v) {
                final copy = [...packing];
                copy[i] = (text: packing[i].text, done: v ?? false);
                _setPacking(copy);
              },
            ),
        ],
      ),
    );
  }
}

class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key, required this.householdId, this.trip});

  final String householdId;
  final Trip? trip;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  late final _name = TextEditingController(text: widget.trip?.name);
  late final _notes = TextEditingController(text: widget.trip?.notes);
  late DateTime? _start = widget.trip?.start;
  late DateTime? _end = widget.trip?.end;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showError(context, 'Wohin geht es?');
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      return showError(context, 'Das Ende liegt vor dem Anfang.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'trips',
      widget.trip?.id,
      {
        'name': name,
        'start': writeDate(_start),
        'end': writeDate(_end),
        'notes': _notes.text.trim(),
        if (widget.trip == null) 'packing': <Object>[],
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    return EditScaffold(
      title: t == null ? 'Neue Reise' : 'Reise bearbeiten',
      onSave: _save,
      onDelete: t == null
          ? null
          : () async {
              if (!await confirmDelete(context, t.name) || !context.mounted) {
                return;
              }
              // Bearbeiten- und Detailseite schließen.
              Navigator.of(context)
                ..pop()
                ..pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('trips', t.id);
            },
      children: [
        TextField(
          controller: _name,
          autofocus: t == null,
          decoration: const InputDecoration(
            labelText: 'Wohin?',
            hintText: 'z. B. Wochenende Ostsee',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        DateField(
          label: 'Von',
          value: _start,
          onChanged: (v) => setState(() => _start = v),
        ),
        DateField(
          label: 'Bis',
          value: _end,
          onChanged: (v) => setState(() => _end = v),
        ),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notizen (optional)',
            hintText: 'Unterkunft, Zugzeiten, Ideen …',
          ),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
