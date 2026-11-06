import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/common.dart';
import 'finance.dart';
import 'trip_widgets.dart';
import 'trips.dart';

enum TripTab {
  packing('Packliste'),
  plan('Plan'),
  costs('Kosten'),
  memory('Erinnerung');

  const TripTab(this.label);
  final String label;
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
  TripTab? _tab;

  /// Packliste nur für eine Person ('' = alle).
  String _filter = '';

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  HouseholdStore get _store => ref.read(storeProvider(widget.householdId));

  Future<void> _setPacking(List<PackItem> items) =>
      _store.update('trips', widget.tripId, {'packing': packingToData(items)});

  Future<void> _editText(
    String title,
    String field,
    String value, {
    String? hint,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          decoration: InputDecoration(hintText: hint),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _store.update('trips', widget.tripId, {field: result});
  }

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
    final t = today();
    final past = tripIsPast(trip, t);
    final tabs = trip.wish
        ? const [TripTab.plan]
        : [
            if (past) TripTab.memory,
            TripTab.packing,
            TripTab.plan,
            TripTab.costs,
            if (!past && tripIsRunning(trip, t)) TripTab.memory,
          ];
    final tab = tabs.contains(_tab) ? _tab! : tabs.first;
    final countdown = tripCountdown(trip, t);
    final names = memberNames(ref, widget.householdId);
    final theme = Theme.of(context);

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
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TripImage(
                  householdId: widget.householdId,
                  trip: trip,
                  editable: true,
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1],
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (countdown != null)
                          Text(
                            countdown,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                          ),
                        Text(
                          trip.wish
                              ? (names[trip.createdBy] == null
                                    ? 'Wunschziel'
                                    : 'Wunschziel · Idee von '
                                          '${names[trip.createdBy]}')
                              : tripDates(trip),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            shadows: const [Shadow(blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          TripWeatherRow(trip: trip),
          if (trip.wish)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton.icon(
                icon: const Icon(Icons.flight_takeoff),
                label: const Text('Jetzt planen'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripEditScreen(
                      householdId: widget.householdId,
                      trip: trip,
                      wish: false,
                    ),
                  ),
                ),
              ),
            ),
          if (tabs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: SegmentedButton<TripTab>(
                showSelectedIcon: false,
                segments: [
                  for (final s in tabs)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ...switch (tab) {
            TripTab.packing => _packing(trip, names),
            TripTab.plan => _plan(trip),
            TripTab.costs => [
              TripCosts(householdId: widget.householdId, trip: trip),
            ],
            TripTab.memory => _memory(trip),
          },
        ],
      ),
    );
  }

  List<Widget> _packing(Trip trip, Map<String, String> names) {
    final packing = trip.packing;
    final members = memberIds(ref, widget.householdId);
    final scheme = Theme.of(context).colorScheme;

    void add() {
      final text = _newItem.text.trim();
      if (text.isEmpty) return;
      _setPacking([...packing, (text: text, done: false, who: _filter)]);
      _newItem.clear();
    }

    String whoLabel(String who) => who.isEmpty ? 'beide' : (names[who] ?? '?');

    String progress(String who) {
      final mine = [
        for (final p in packing)
          if (who.isEmpty || p.who == who || p.who.isEmpty) p,
      ];
      return '${mine.where((p) => p.done).length}/${mine.length}';
    }

    return [
      if (packing.isNotEmpty && members.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            children: [
              for (final who in ['', ...members])
                ChoiceChip(
                  label: Text(
                    '${who.isEmpty ? 'Alle' : names[who] ?? '?'} '
                    '${progress(who)}',
                  ),
                  selected: _filter == who,
                  onSelected: (_) => setState(() => _filter = who),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _newItem,
          decoration: InputDecoration(
            hintText: 'Was muss mit?',
            helperText: _filter.isEmpty
                ? null
                : 'Packt ${names[_filter] ?? '?'}',
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
      for (var i = 0; i < packing.length; i++)
        if (_filter.isEmpty ||
            packing[i].who == _filter ||
            packing[i].who.isEmpty)
          CheckboxListTile(
            value: packing[i].done,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 8, right: 4),
            title: Text(
              packing[i].text,
              style: packing[i].done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (members.length > 1)
                  ActionChip(
                    tooltip: 'Wer packt das ein?',
                    label: Text(whoLabel(packing[i].who)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: packing[i].who.isEmpty
                        ? null
                        : scheme.primary,
                    labelStyle: packing[i].who.isEmpty
                        ? null
                        : TextStyle(color: scheme.onPrimary),
                    onPressed: () {
                      final copy = [...packing];
                      final p = packing[i];
                      copy[i] = (
                        text: p.text,
                        done: p.done,
                        who: nextPacker(p.who, members),
                      );
                      _setPacking(copy);
                    },
                  ),
                IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.close),
                  onPressed: () => _setPacking([...packing]..removeAt(i)),
                ),
              ],
            ),
            onChanged: (v) {
              final copy = [...packing];
              final p = packing[i];
              copy[i] = (text: p.text, done: v ?? false, who: p.who);
              _setPacking(copy);
            },
          ),
      if (packing.isNotEmpty && members.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Tippe auf „beide“, um festzulegen, wer etwas einpackt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SectionHeader('Vorlage dazunehmen'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in packingTemplates.entries)
              ActionChip(
                avatar: Text(e.value.$1),
                label: Text(e.key),
                onPressed: () {
                  final next = addTemplate(packing, e.value.$2);
                  final added = next.length - packing.length;
                  _setPacking(next);
                  showError(
                    context,
                    added == 0
                        ? 'Alles aus „${e.key}“ steht schon drauf.'
                        : '$added Sachen aus „${e.key}“ dazugenommen.',
                  );
                },
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _plan(Trip trip) {
    Widget card({
      required IconData icon,
      required String title,
      required String text,
      required String empty,
      required VoidCallback onEdit,
      Widget? extra,
    }) => Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '$title bearbeiten',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                text.isEmpty ? empty : text,
                style: text.isEmpty
                    ? Theme.of(context).textTheme.bodySmall
                    : null,
              ),
            ),
            ?extra,
          ],
        ),
      ),
    );

    final place = trip.place;
    return [
      if (!trip.wish) ...[
        card(
          icon: Icons.train_outlined,
          title: 'Anreise',
          text: trip.travel,
          empty: 'Zug, Flug oder Auto, Abfahrt, Plätze …',
          onEdit: () => _editText(
            'Anreise',
            'travel',
            trip.travel,
            hint: 'z. B. ICE 2214 um 9:12, Platz 54 + 55',
          ),
        ),
        card(
          icon: Icons.hotel_outlined,
          title: 'Unterkunft',
          text: trip.stay,
          empty: 'Name, Adresse, Check-in …',
          onEdit: () => _editText(
            'Unterkunft',
            'stay',
            trip.stay,
            hint: 'Name, Adresse, Check-in …',
          ),
          extra: trip.stay.isEmpty
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Auf der Karte'),
                    onPressed: () => openMap(
                      [
                        trip.stay.split('\n').first,
                        if (place != null) place.name,
                      ].join(', '),
                    ),
                  ),
                ),
        ),
      ],
      card(
        icon: Icons.lightbulb_outline,
        title: 'Ideen & Notizen',
        text: trip.notes,
        empty: 'Was wollt ihr dort machen, essen, sehen?',
        onEdit: () => _editText(
          'Ideen & Notizen',
          'notes',
          trip.notes,
          hint: 'z. B. Fischbrötchen in List, Sonnenuntergang …',
        ),
        extra: place == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.place_outlined),
                  label: Text(place.name.split(',').first),
                  onPressed: () => openMap('${place.lat},${place.lng}'),
                ),
              ),
      ),
      if (!trip.wish) ...[
        const SectionHeader('Unterlagen'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TripDocumentsSection(
            householdId: widget.householdId,
            tripId: trip.id,
          ),
        ),
      ],
    ];
  }

  List<Widget> _memory(Trip trip) => [
    const SectionHeader('Wie war’s?'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stars(
        rating: trip.rating,
        onChanged: (r) => _store.update('trips', widget.tripId, {'rating': r}),
      ),
    ),
    Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        leading: const Icon(Icons.favorite_outline),
        title: Text(trip.memory.isEmpty ? 'Euer Lieblingsmoment' : trip.memory),
        subtitle: trip.memory.isEmpty
            ? const Text(
                'Was soll euch von dieser Reise in Erinnerung bleiben?',
              )
            : null,
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _editText(
          'Lieblingsmoment',
          'memory',
          trip.memory,
          hint: 'z. B. Der Sonnenuntergang am Ellenbogen',
        ),
      ),
    ),
    const SectionHeader('Fotos'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TripMemoryPhotos(householdId: widget.householdId, tripId: trip.id),
    ),
  ];
}

/// Die Ausgaben einer Reise: Summe, wer wie viel bezahlt hat und der
/// Ausgleich nur für diese Reise.
class TripCosts extends ConsumerWidget {
  const TripCosts({super.key, required this.householdId, required this.trip});

  final String householdId;
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(expensesProvider(householdId)).value ?? const [];
    final list = [
      for (final e in all)
        if (e.tripId == trip.id) e,
    ];
    final names = memberNames(ref, householdId);
    final members = memberIds(ref, householdId);
    final theme = Theme.of(context);
    final total = list.fold<int>(0, (s, e) => s + e.amountCents);
    final paid = <String, int>{};
    for (final e in list) {
      paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.amountCents;
    }
    final balance = balanceText(list, members, names);

    void open(Expense? e) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEditScreen(
          householdId: householdId,
          expense: e,
          tripId: trip.id,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reise gesamt',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Text(formatCents(total), style: theme.textTheme.titleLarge),
                  ],
                ),
                for (final id in members)
                  if ((paid[id] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${names[id] ?? '?'} hat ${formatCents(paid[id]!)} '
                        'bezahlt',
                      ),
                    ),
                if (list.isNotEmpty && balance != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    balance == 'Ihr seid quitt.'
                        ? 'Für diese Reise seid ihr quitt.'
                        : 'Für diese Reise: $balance',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Ist im Kontostand unter Finanzen schon mit drin.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Tragt hier ein, was die Reise kostet: Zug, '
                      'Unterkunft, Essen … Es landet auch unter Finanzen.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final e in list)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
            title: Text(e.title),
            subtitle: Text(
              [
                formatShortDate(e.date),
                '${names[e.paidBy] ?? '?'} hat bezahlt',
                if (e.split == Split.other) 'nur für die andere Person',
              ].join(' · '),
            ),
            trailing: Text(formatCents(e.amountCents)),
            onTap: () => open(e),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ausgabe für die Reise'),
            onPressed: () => open(null),
          ),
        ),
      ],
    );
  }
}
