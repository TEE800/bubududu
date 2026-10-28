import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

enum StockLevel {
  full('Genug da'),
  low('Wird knapp'),
  empty('Leer');

  const StockLevel(this.label);
  final String label;

  static StockLevel parse(String? name) =>
      StockLevel.values.where((l) => l.name == name).firstOrNull ??
      StockLevel.full;
}

/// households/{id}/pantry: was zu Hause ist.
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.level,
    required this.bestBefore,
    required this.place,
  });

  final String id;
  final String name;
  final StockLevel level;
  final DateTime? bestBefore;
  final String place;

  /// Läuft in den nächsten 3 Tagen ab oder ist schon abgelaufen.
  bool expiresSoon(DateTime now) =>
      bestBefore != null && daysBetween(now, bestBefore!) <= 3;

  factory PantryItem.fromDoc(Doc d) => PantryItem(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    level: StockLevel.parse(d.data['level'] as String?),
    bestBefore: readDate(d.data['bestBefore']),
    place: d.data['place'] as String? ?? '',
  );
}

final pantryProvider = Provider.family<AsyncValue<List<PantryItem>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'pantry')),
      )
      .whenData(
        (docs) => docs.map(PantryItem.fromDoc).toList()
          ..sort((a, b) {
            final c = b.level.index.compareTo(a.level.index);
            return c != 0
                ? c
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }),
      ),
);

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pantryProvider(householdId));
    final store = ref.read(storeProvider(householdId));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Vorräte')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Vorrat'),
        onPressed: () => _open(context, null),
      ),
      body: asyncBody(items, (list) {
        if (list.isEmpty) {
          return const EmptyHint(
            icon: Icons.kitchen_outlined,
            mood: MascotMood.hungry,
            text:
                'Tragt ein, was ihr zu Hause habt. Was knapp wird, kommt mit '
                'einem Tipp auf die Einkaufsliste.',
          );
        }
        final missing = list.where((i) => i.level != StockLevel.full).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    missing.length == 1
                        ? '1 fehlenden Vorrat auf die Einkaufsliste'
                        : '${missing.length} fehlende Vorräte auf die Einkaufsliste',
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    for (final i in missing) {
                      await store.addToShoppingList(i.name);
                    }
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Steht auf der Einkaufsliste.'),
                      ),
                    );
                  },
                ),
              ),
            for (final i in list)
              ListTile(
                leading: Icon(
                  switch (i.level) {
                    StockLevel.full => Icons.check_circle_outline,
                    StockLevel.low => Icons.hourglass_bottom,
                    StockLevel.empty => Icons.remove_circle_outline,
                  },
                  color: i.level == StockLevel.full
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(i.name),
                subtitle: Text(
                  [
                    i.level.label,
                    if (i.place.isNotEmpty) i.place,
                    if (i.bestBefore != null)
                      'MHD ${formatShortDate(i.bestBefore!)}',
                  ].join(' · '),
                  style: i.expiresSoon(now)
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                trailing: PopupMenuButton<StockLevel>(
                  tooltip: 'Bestand ändern',
                  icon: const Icon(Icons.tune),
                  onSelected: (l) =>
                      store.update('pantry', i.id, {'level': l.name}),
                  itemBuilder: (_) => [
                    for (final l in StockLevel.values)
                      PopupMenuItem(value: l, child: Text(l.label)),
                  ],
                ),
                onTap: () => _open(context, i),
              ),
          ],
        );
      }),
    );
  }

  void _open(BuildContext context, PantryItem? i) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PantryEditScreen(householdId: householdId, item: i),
    ),
  );
}

class PantryEditScreen extends ConsumerStatefulWidget {
  const PantryEditScreen({super.key, required this.householdId, this.item});

  final String householdId;
  final PantryItem? item;

  @override
  ConsumerState<PantryEditScreen> createState() => _PantryEditScreenState();
}

class _PantryEditScreenState extends ConsumerState<PantryEditScreen> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _place = TextEditingController(text: widget.item?.place);
  late StockLevel _level = widget.item?.level ?? StockLevel.full;
  late DateTime? _bestBefore = widget.item?.bestBefore;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showError(context, 'Bitte gib einen Namen ein.');
    await ref.read(storeProvider(widget.householdId)).save(
      'pantry',
      widget.item?.id,
      {
        'name': name,
        'place': _place.text.trim(),
        'level': _level.name,
        'bestBefore': writeDate(_bestBefore),
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return EditScaffold(
      title: i == null ? 'Neuer Vorrat' : 'Vorrat bearbeiten',
      onSave: _save,
      onDelete: i == null
          ? null
          : () async {
              if (!await confirmDelete(context, i.name) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('pantry', i.id);
            },
      children: [
        TextField(
          controller: _name,
          autofocus: i == null,
          decoration: const InputDecoration(
            labelText: 'Was?',
            hintText: 'z. B. Nudeln, Klopapier',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _place,
          decoration: const InputDecoration(
            labelText: 'Wo? (optional)',
            hintText: 'z. B. Keller, Kühlschrank',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        SegmentedButton<StockLevel>(
          segments: [
            for (final l in StockLevel.values)
              ButtonSegment(value: l, label: Text(l.label)),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        DateField(
          label: 'Mindestens haltbar bis (optional)',
          value: _bestBefore,
          onChanged: (v) => setState(() => _bestBefore = v),
        ),
      ],
    );
  }
}
