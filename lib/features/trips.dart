import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../services/place_image.dart';
import '../services/weather.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';
import 'trip_detail.dart';
import 'trip_widgets.dart';

export 'trip_detail.dart' show TripDetailScreen;

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

/// Vorlagen für die Packliste: Name → (Symbol, Sachen).
const packingTemplates = <String, (String, List<String>)>{
  'Basis': ('🧳', defaultPackingList),
  'Strand': (
    '🏖️',
    [
      'Badesachen',
      'Sonnencreme',
      'Strandtuch',
      'Sonnenhut',
      'Flip-Flops',
      'After-Sun',
      'Buch',
    ],
  ),
  'Städtetrip': (
    '🏙️',
    [
      'Bequeme Schuhe',
      'Powerbank',
      'Tickets & Reservierungen',
      'Regenschirm',
      'Tagesrucksack',
      'Kamera',
    ],
  ),
  'Wandern': (
    '🥾',
    [
      'Wanderschuhe',
      'Regenjacke',
      'Trinkflasche',
      'Snacks',
      'Blasenpflaster',
      'Rucksack',
      'Taschenmesser',
    ],
  ),
  'Winter': (
    '❄️',
    [
      'Winterjacke',
      'Mütze',
      'Schal',
      'Handschuhe',
      'Thermounterwäsche',
      'Lippenpflege',
      'Warme Socken',
    ],
  ),
  'Flug': (
    '✈️',
    [
      'Reisepass',
      'Bordkarten',
      'Nackenkissen',
      'Beutel für Flüssigkeiten',
      'Reiseadapter',
    ],
  ),
};

/// Ein Teil der Packliste. [who] ist die uid der Person, die es einpackt,
/// leer heißt: für beide bzw. gemeinsam.
typedef PackItem = ({String text, bool done, String who});

/// households/{id}/trips: Reisen, Ausflüge und Wunschziele.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.packing,
    required this.notes,
    this.place,
    this.imageUrl,
    this.imagePage,
    this.wish = false,
    this.travel = '',
    this.stay = '',
    this.rating = 0,
    this.memory = '',
    this.createdBy = '',
  });

  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final List<PackItem> packing;

  /// Ideen vor Ort und sonstige Notizen.
  final String notes;

  /// Der Ort für Wetter und Karte, aus der Ortssuche.
  final Place? place;

  /// Automatisch gefundenes Foto des Reiseziels. null: noch nicht gesucht,
  /// leer: nichts gefunden.
  final String? imageUrl;
  final String? imagePage;

  /// Nur ein Wunschziel, noch nicht geplant.
  final bool wish;

  /// Anreise (Zug, Flug, Zeiten, Plätze …).
  final String travel;

  /// Unterkunft (Name, Adresse, Check-in …).
  final String stay;

  /// Sterne nach der Reise (0 = noch keine).
  final int rating;

  /// Lieblingsmoment, nach der Reise.
  final String memory;
  final String createdBy;

  factory Trip.fromDoc(Doc d) => Trip(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    start: readDate(d.data['start']),
    end: readDate(d.data['end']),
    packing: [
      for (final p in (d.data['packing'] as List? ?? const []))
        if (p is Map)
          (
            text: p['text'] as String? ?? '',
            done: p['done'] as bool? ?? false,
            who: p['who'] as String? ?? '',
          ),
    ],
    notes: d.data['notes'] as String? ?? '',
    place: Place.fromMap(d.data['place']),
    imageUrl: d.data['imageUrl'] as String?,
    imagePage: d.data['imagePage'] as String?,
    wish: d.data['wish'] as bool? ?? false,
    travel: d.data['travel'] as String? ?? '',
    stay: d.data['stay'] as String? ?? '',
    rating: (d.data['rating'] as num?)?.toInt() ?? 0,
    memory: d.data['memory'] as String? ?? '',
    createdBy: d.data['createdBy'] as String? ?? '',
  );
}

List<Map<String, Object>> packingToData(List<PackItem> items) => [
  for (final p in items) {'text': p.text, 'done': p.done, 'who': p.who},
];

/// Hängt die Sachen einer Vorlage an, ohne doppelte (Groß/klein egal).
List<PackItem> addTemplate(List<PackItem> items, List<String> template) {
  final have = {for (final p in items) p.text.trim().toLowerCase()};
  return [
    ...items,
    for (final t in template)
      if (have.add(t.toLowerCase())) (text: t, done: false, who: ''),
  ];
}

/// Nächste Person für ein Teil der Packliste: beide → erste → zweite → beide.
String nextPacker(String who, List<String> members) {
  if (members.isEmpty) return '';
  final i = members.indexOf(who);
  if (who.isEmpty) return members.first;
  return i >= 0 && i + 1 < members.length ? members[i + 1] : '';
}

final tripsProvider = Provider.family<AsyncValue<List<Trip>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'trips')),
      )
      .whenData((docs) => sortTrips(docs.map(Trip.fromDoc).toList())),
);

/// Vorbei, wenn das Ende (oder ohne Ende der Anfang) vor [today] liegt.
bool tripIsPast(Trip t, DateTime today) =>
    !t.wish && ((t.end ?? t.start)?.isBefore(dateOnly(today)) ?? false);

/// Läuft gerade (heute zwischen Anfang und Ende).
bool tripIsRunning(Trip t, DateTime today) {
  if (t.wish || t.start == null) return false;
  final d = dateOnly(today);
  return !d.isBefore(dateOnly(t.start!)) &&
      !d.isAfter(dateOnly(t.end ?? t.start!));
}

/// "noch 12 Tage", "morgen geht's los", "Tag 2 von 4" – oder null, wenn die
/// Reise kein Datum hat, vorbei oder nur ein Wunschziel ist.
String? tripCountdown(Trip t, DateTime today) {
  if (t.wish || t.start == null || tripIsPast(t, today)) return null;
  final start = dateOnly(t.start!);
  final end = dateOnly(t.end ?? t.start!);
  if (tripIsRunning(t, today)) {
    final total = daysBetween(start, end) + 1;
    if (total == 1) return 'heute';
    return 'Tag ${daysBetween(start, today) + 1} von $total';
  }
  final days = daysBetween(today, start);
  if (days == 1) return 'morgen geht’s los';
  if (days < 60) return 'noch ${daysText(days)}';
  final months = (days / 30.4).round();
  return 'noch $months Monate';
}

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

/// Die Reisen, wie die Übersicht sie zeigt.
typedef TripGroups = ({
  Trip? next,
  List<Trip> planned,
  List<Trip> wishes,
  List<Trip> past,
});

/// Die nächste Reise mit Datum groß oben, dann die übrigen geplanten,
/// die Wunschziele und die vergangenen Reisen als Erinnerungen.
TripGroups groupTrips(List<Trip> sorted, DateTime today) {
  final wishes = [
    for (final t in sorted)
      if (t.wish) t,
  ];
  final past = [
    for (final t in sorted)
      if (tripIsPast(t, today)) t,
  ];
  final planned = [
    for (final t in sorted)
      if (!t.wish && !tripIsPast(t, today)) t,
  ];
  final next = planned.where((t) => t.start != null).firstOrNull;
  return (
    next: next,
    planned: [
      for (final t in planned)
        if (t != next) t,
    ],
    wishes: wishes,
    past: past,
  );
}

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider(householdId));
    final names = memberNames(ref, householdId);
    void open(Trip trip) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TripDetailScreen(householdId: householdId, tripId: trip.id),
      ),
    );
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
            text:
                'Plant hier Urlaube und Ausflüge mit gemeinsamer Packliste, '
                'oder sammelt Orte, an die ihr mal wollt.',
          );
        }
        final t = today();
        final g = groupTrips(list, t);
        Widget grid(List<Trip> trips) => _TileGrid(
          children: [
            for (final trip in trips)
              TripTile(
                householdId: householdId,
                trip: trip,
                today: t,
                names: names,
                onTap: () => open(trip),
              ),
          ],
        );
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (g.next != null) ...[
              const SectionHeader('Als Nächstes'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TripTile(
                  householdId: householdId,
                  trip: g.next!,
                  today: t,
                  names: names,
                  big: true,
                  onTap: () => open(g.next!),
                ),
              ),
            ],
            if (g.planned.isNotEmpty) ...[
              SectionHeader(g.next == null ? 'Geplant' : 'Danach'),
              grid(g.planned),
            ],
            if (g.wishes.isNotEmpty) ...[
              const SectionHeader('Wunschziele'),
              grid(g.wishes),
            ],
            if (g.past.isNotEmpty) ...[
              const SectionHeader('Erinnerungen'),
              grid(g.past),
            ],
          ],
        );
      }),
    );
  }
}

/// Zwei Kacheln pro Zeile, gleich hoch.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// Wählt einen Ort per Suche (für Wetter, Karte und Foto).
class PlaceField extends ConsumerStatefulWidget {
  const PlaceField({super.key, required this.value, required this.onChanged});

  final Place? value;
  final ValueChanged<Place?> onChanged;

  @override
  ConsumerState<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends ConsumerState<PlaceField> {
  final _query = TextEditingController();
  List<Place> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final result = await searchPlaces(
      ref.read(httpClientProvider),
      q,
    ).catchError((_) => <Place>[]);
    if (!mounted) return;
    setState(() {
      _results = result;
      _searching = false;
    });
    if (result.isEmpty) showError(context, 'Keinen Ort gefunden.');
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (place != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(place.name),
            subtitle: const Text('Für Wetter, Karte und Foto'),
            trailing: IconButton(
              tooltip: 'Ort entfernen',
              icon: const Icon(Icons.close),
              onPressed: () => widget.onChanged(null),
            ),
          ),
        TextField(
          controller: _query,
          decoration: InputDecoration(
            labelText: place == null ? 'Ort (optional)' : 'Anderer Ort',
            hintText: 'z. B. Sylt',
            helperText: place == null
                ? 'Dann gibt es Wetter und Karte zur Reise'
                : null,
            suffixIcon: IconButton(
              tooltip: 'Ort suchen',
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
        if (_searching) const LinearProgressIndicator(),
        for (final p in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(p.name),
            onTap: () {
              widget.onChanged(p);
              setState(() {
                _results = const [];
                _query.clear();
              });
            },
          ),
      ],
    );
  }
}

class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({
    super.key,
    required this.householdId,
    this.trip,
    this.wish,
  });

  final String householdId;
  final Trip? trip;

  /// Vorgabe für „Nur ein Wunschziel“ (sonst wie bei [trip]).
  final bool? wish;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  late final _name = TextEditingController(text: widget.trip?.name);
  late final _notes = TextEditingController(text: widget.trip?.notes);
  late final _travel = TextEditingController(text: widget.trip?.travel);
  late final _stay = TextEditingController(text: widget.trip?.stay);
  late DateTime? _start = widget.trip?.start;
  late DateTime? _end = widget.trip?.end;
  late Place? _place = widget.trip?.place;
  late bool _wish = widget.wish ?? widget.trip?.wish ?? false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _travel.dispose();
    _stay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showError(context, 'Wohin geht es?');
    if (!_wish && _start != null && _end != null && _end!.isBefore(_start!)) {
      return showError(context, 'Das Ende liegt vor dem Anfang.');
    }
    final old = widget.trip;
    final store = ref.read(storeProvider(widget.householdId));
    final placeChanged =
        jsonEncode(old?.place?.toMap()) != jsonEncode(_place?.toMap());
    final data = <String, dynamic>{
      'name': name,
      'wish': _wish,
      'start': _wish ? null : writeDate(_start),
      'end': _wish ? null : writeDate(_end),
      'notes': _notes.text.trim(),
      'travel': _travel.text.trim(),
      'stay': _stay.text.trim(),
    };
    if (old == null) {
      final id = store.newId('trips');
      await store.add('trips', {
        ...data,
        if (_place != null) 'place': _place!.toMap(),
        'packing': <Object>[],
      }, id: id);
      if (_place == null) _guessPlace(store, id, name);
    } else {
      await store.update('trips', old.id, {
        ...data,
        'place': _place?.toMap() ?? FieldValue.delete(),
        // Anderes Ziel: das Foto neu suchen.
        if (name != old.name || placeChanged) ...{
          'imageUrl': FieldValue.delete(),
          'imagePage': FieldValue.delete(),
        },
      });
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Ohne gewählten Ort: den Ort aus dem Namen erraten (für Wetter und
  /// Karte), im Hintergrund. Klappt es nicht, bleibt die Reise ohne Ort.
  void _guessPlace(HouseholdStore store, String id, String name) {
    final client = ref.read(httpClientProvider);
    final query = placeQueries(name).firstOrNull;
    if (query == null) return;
    searchPlaces(client, query)
        .then((places) async {
          final p = places.firstOrNull;
          if (p == null) return;
          await store.update('trips', id, {'place': p.toMap()});
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    return EditScaffold(
      title: t == null
          ? (_wish ? 'Neues Wunschziel' : 'Neue Reise')
          : (_wish ? 'Wunschziel bearbeiten' : 'Reise bearbeiten'),
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
              final store = ref.read(storeProvider(widget.householdId));
              await store.delete('trips', t.id);
              await store.delete('tripPhotos', t.id);
              await deleteTripFiles(store, t.id);
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Nur ein Wunschziel'),
          subtitle: const Text('Da wollt ihr mal hin, geplant ist noch nichts'),
          value: _wish,
          onChanged: (v) => setState(() => _wish = v),
        ),
        PlaceField(value: _place, onChanged: (p) => setState(() => _place = p)),
        if (!_wish) ...[
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
            controller: _travel,
            decoration: const InputDecoration(
              labelText: 'Anreise (optional)',
              hintText: 'z. B. ICE 2214 um 9:12, Platz 54 + 55',
              prefixIcon: Icon(Icons.train_outlined),
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
          TextField(
            controller: _stay,
            decoration: const InputDecoration(
              labelText: 'Unterkunft (optional)',
              hintText: 'Name, Adresse, Check-in …',
              prefixIcon: Icon(Icons.hotel_outlined),
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Ideen & Notizen (optional)',
            hintText: 'Was wollt ihr dort machen, essen, sehen?',
          ),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}
