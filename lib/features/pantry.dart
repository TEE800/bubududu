import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/item_icon.dart';
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

/// Wie oft etwas von selbst verbraucht wird: pro Tag oder pro Woche.
enum AutoUnit {
  day('pro Tag', 1),
  week('pro Woche', 7);

  const AutoUnit(this.label, this.days);
  final String label;
  final int days;

  static AutoUnit parse(String? name) =>
      AutoUnit.values.where((u) => u.name == name).firstOrNull ?? AutoUnit.day;
}

/// households/{id}/pantry: was zu Hause ist.
///
/// Optional mit Nutzungen: [uses] insgesamt, [usesLeft] übrig zum Zeitpunkt
/// [usesAt]. Bei automatischem Verbrauch ([autoAmount] pro [autoUnit]) wird
/// ab [usesAt] laufend abgezogen, ohne dass jemand etwas speichern muss.
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.level,
    required this.bestBefore,
    required this.place,
    this.uses,
    this.usesLeft,
    this.usesAt,
    this.autoAmount = 0,
    this.autoUnit = AutoUnit.day,
  });

  final String id;
  final String name;
  final StockLevel level;
  final DateTime? bestBefore;
  final String place;
  final int? uses;
  final double? usesLeft;
  final DateTime? usesAt;
  final double autoAmount;
  final AutoUnit autoUnit;

  bool get countsUses => (uses ?? 0) > 0;
  bool get autoUses => countsUses && autoAmount > 0;
  double get perDay => autoUses ? autoAmount / autoUnit.days : 0;

  /// Genaue Nutzungen übrig, mit automatischem Verbrauch bis [now].
  double usesLeftAt(DateTime now) {
    final left = usesLeft ?? (uses ?? 0).toDouble();
    if (perDay <= 0 || usesAt == null) return math.max(0, left);
    final days = math.max(0, now.difference(usesAt!).inMinutes) / 1440;
    return math.max(0, left - perDay * days);
  }

  /// Zum Anzeigen: angebrochene Nutzungen zählen noch mit.
  int remaining(DateTime now) => (usesLeftAt(now) - 1e-9).ceil();

  /// Bestand: bei gezählten Nutzungen aus dem, was übrig ist.
  StockLevel levelAt(DateTime now) =>
      countsUses ? levelForUses(usesLeftAt(now), uses!) : level;

  /// Wie viel noch da ist, von 0 (leer) bis 1 (voll); zum Sortieren.
  /// Ohne Nutzungen grob nach Bestand.
  double fractionLeft(DateTime now) => countsUses
      ? math.min(1, usesLeftAt(now) / uses!)
      : switch (level) {
          StockLevel.full => 1,
          StockLevel.low => 0.2,
          StockLevel.empty => 0,
        };

  /// Wann es bei automatischem Verbrauch ungefähr leer ist.
  DateTime? emptyOn(DateTime now) {
    if (perDay <= 0) return null;
    final left = usesLeftAt(now);
    if (left <= 0) return null;
    return now.add(Duration(minutes: (left / perDay * 1440).round()));
  }

  /// Felder für einen neuen Stand von [left] Nutzungen.
  Map<String, dynamic> usesUpdate(double left, DateTime now) => {
    'usesLeft': math.max(0.0, left),
    'usesAt': Timestamp.fromDate(now),
    'level': levelForUses(left, uses ?? 0).name,
  };

  /// Läuft in den nächsten 3 Tagen ab oder ist schon abgelaufen.
  bool expiresSoon(DateTime now) =>
      bestBefore != null && daysBetween(now, bestBefore!) <= 3;

  factory PantryItem.fromDoc(Doc d) => PantryItem(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    level: StockLevel.parse(d.data['level'] as String?),
    bestBefore: readDate(d.data['bestBefore']),
    place: d.data['place'] as String? ?? '',
    uses: (d.data['uses'] as num?)?.toInt(),
    usesLeft: (d.data['usesLeft'] as num?)?.toDouble(),
    usesAt: readDate(d.data['usesAt']),
    autoAmount: (d.data['autoAmount'] as num?)?.toDouble() ?? 0,
    autoUnit: AutoUnit.parse(d.data['autoUnit'] as String?),
  );
}

/// Leer bei 0, knapp ab einem Fünftel (mindestens bei 1 übrig).
StockLevel levelForUses(double left, int total) {
  if (left <= 1e-9) return StockLevel.empty;
  if (left <= math.max(1, total * 0.2)) return StockLevel.low;
  return StockLevel.full;
}

/// "noch 9 von 10", "noch 1 von 10".
String usesText(int left, int total) => 'noch $left von $total';

/// Zahl mit Komma oder Punkt, z. B. "0,5".
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

String formatAmount(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toString().replaceAll('.', ',');

/// Namen der fehlenden Vorräte, die noch nicht offen auf der Einkaufsliste
/// stehen ([onList]: kleingeschriebene Einträge), ohne Doppelte.
List<String> missingForShopping(List<PantryItem> missing, Set<String> onList) {
  final seen = {...onList};
  return [
    for (final i in missing)
      if (seen.add(i.name.trim().toLowerCase())) i.name,
  ];
}

final pantryProvider = Provider.family<AsyncValue<List<PantryItem>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'pantry')),
      )
      .whenData((docs) {
        final now = DateTime.now();
        return docs.map(PantryItem.fromDoc).toList()..sort((a, b) {
          final c = b.levelAt(now).index.compareTo(a.levelAt(now).index);
          return c != 0
              ? c
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }),
);

/// Wie die Vorräte angeordnet sind. Merkt sich jedes Gerät selbst.
enum PantrySort {
  rooms('Nach Räumen', Icons.meeting_room_outlined),
  name('Alphabetisch', Icons.sort_by_alpha),
  left('Nach Restmenge', Icons.battery_3_bar);

  const PantrySort(this.label, this.icon);
  final String label;
  final IconData icon;

  static PantrySort parse(String? name) =>
      PantrySort.values.where((s) => s.name == name).firstOrNull ??
      PantrySort.rooms;
}

class PantrySortNotifier extends Notifier<PantrySort> {
  static const _key = 'pantrySort';

  @override
  PantrySort build() {
    _load();
    return PantrySort.rooms;
  }

  Future<void> _load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_key);
      if (saved != null) state = PantrySort.parse(saved);
    } catch (_) {
      // Ohne Speicher (z. B. im Test) bleibt es bei „Nach Räumen“.
    }
  }

  void set(PantrySort sort) {
    state = sort;
    try {
      SharedPreferencesAsync().setString(_key, sort.name).ignore();
    } catch (_) {}
  }
}

final pantrySortProvider = NotifierProvider<PantrySortNotifier, PantrySort>(
  PantrySortNotifier.new,
);

/// Name für Vorräte ohne Raum.
const noRoom = 'Ohne Raum';

int _byName(PantryItem a, PantryItem b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// Ordnet die Vorräte in Abschnitte: nach Räumen (alphabetisch, „Ohne Raum“
/// zuletzt) oder als ein einziger Abschnitt ohne Überschrift ('').
List<(String, List<PantryItem>)> pantrySections(
  List<PantryItem> items,
  PantrySort sort,
  DateTime now,
) {
  switch (sort) {
    case PantrySort.name:
      return [
        ('', [...items]..sort(_byName)),
      ];
    case PantrySort.left:
      return [
        (
          '',
          [...items]..sort((a, b) {
            final c = a.fractionLeft(now).compareTo(b.fractionLeft(now));
            return c != 0 ? c : _byName(a, b);
          }),
        ),
      ];
    case PantrySort.rooms:
      final rooms = <String, (String, List<PantryItem>)>{};
      for (final i in items) {
        final room = i.place.trim().isEmpty ? noRoom : i.place.trim();
        rooms
            .putIfAbsent(room.toLowerCase(), () => (room, <PantryItem>[]))
            .$2
            .add(i);
      }
      final keys = rooms.keys.toList()
        ..sort((a, b) {
          if (a == noRoom.toLowerCase()) return 1;
          if (b == noRoom.toLowerCase()) return -1;
          return a.compareTo(b);
        });
      return [
        for (final k in keys) (rooms[k]!.$1, rooms[k]!.$2..sort(_byName)),
      ];
  }
}

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pantryProvider(householdId));
    final sort = ref.watch(pantrySortProvider);
    final store = ref.read(storeProvider(householdId));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorräte'),
        actions: [
          PopupMenuButton<PantrySort>(
            tooltip: 'Sortieren',
            icon: Icon(sort.icon),
            initialValue: sort,
            onSelected: ref.read(pantrySortProvider.notifier).set,
            itemBuilder: (_) => [
              for (final s in PantrySort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == sort,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
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
        final missing = list
            .where((i) => i.levelAt(now) != StockLevel.full)
            .toList();
        final textTheme = Theme.of(context).textTheme;
        // Größere Schrift braucht höhere Kacheln.
        final extraHeight =
            (MediaQuery.textScalerOf(context).scale(14) - 14) * 6;
        return CustomScrollView(
          slivers: [
            if (missing.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                      missing.length == 1
                          ? '1 fehlenden Vorrat auf die Einkaufsliste'
                          : '${missing.length} fehlende Vorräte auf die Einkaufsliste',
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final onList = {
                        for (final s
                            in ref
                                    .read(shoppingItemsProvider(householdId))
                                    .value ??
                                const <ShoppingItem>[])
                          if (!s.done) s.text.trim().toLowerCase(),
                      };
                      final toAdd = missingForShopping(missing, onList);
                      for (final name in toAdd) {
                        await store.addToShoppingList(name);
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            toAdd.isEmpty
                                ? 'Steht schon alles auf der Einkaufsliste.'
                                : 'Steht auf der Einkaufsliste.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            for (final (room, roomItems) in pantrySections(
              list,
              sort,
              now,
            )) ...[
              if (room.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '$room (${roomItems.length})',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 196 + extraHeight,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: roomItems.length,
                  itemBuilder: (context, n) => _tile(
                    context,
                    store,
                    roomItems[n],
                    now,
                    showPlace: sort != PantrySort.rooms,
                  ),
                ),
              ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
          ],
        );
      }),
    );
  }

  Widget _tile(
    BuildContext context,
    HouseholdStore store,
    PantryItem i,
    DateTime now, {
    required bool showPlace,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = i.levelAt(now);
    final emptyOn = i.emptyOn(now);
    final warn = level == StockLevel.full ? scheme.primary : scheme.error;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemAvatar(householdId: householdId, name: i.name, size: 52),
                  const Spacer(),
                  if (level != StockLevel.full)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        level == StockLevel.low
                            ? Icons.hourglass_bottom
                            : Icons.remove_circle_outline,
                        color: scheme.error,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                i.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                [
                  if (i.countsUses)
                    usesText(i.remaining(now), i.uses!)
                  else
                    level.label,
                  if (i.autoUses)
                    emptyOn == null
                        ? 'automatisch'
                        : 'reicht bis ca. ${formatShortDate(emptyOn)}',
                  if (showPlace && i.place.isNotEmpty) i.place,
                  if (i.bestBefore != null)
                    'MHD ${formatShortDate(i.bestBefore!)}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: i.expiresSoon(now) ? scheme.error : null,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: LinearProgressIndicator(
                  value: i.fractionLeft(now),
                  color: warn,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  if (i.countsUses)
                    IconButton.filledTonal(
                      tooltip: 'Einmal benutzt',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                      onPressed: i.remaining(now) == 0
                          ? null
                          : () => _useOnce(context, store, i),
                    ),
                  const Spacer(),
                  if (i.countsUses)
                    PopupMenuButton<void>(
                      tooltip: 'Bestand ändern',
                      icon: const Icon(Icons.tune),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          onTap: () => store.update(
                            'pantry',
                            i.id,
                            i.usesUpdate(i.uses!.toDouble(), DateTime.now()),
                          ),
                          child: Text('Wieder voll (${i.uses})'),
                        ),
                      ],
                    )
                  else
                    PopupMenuButton<StockLevel>(
                      tooltip: 'Bestand ändern',
                      icon: const Icon(Icons.tune),
                      onSelected: (l) =>
                          store.update('pantry', i.id, {'level': l.name}),
                      itemBuilder: (_) => [
                        for (final l in StockLevel.values)
                          PopupMenuItem(value: l, child: Text(l.label)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Eine Nutzung abziehen, mit Rückgängig.
  void _useOnce(BuildContext context, HouseholdStore store, PantryItem i) {
    final now = DateTime.now();
    final before = i.usesLeftAt(now);
    final after = math.max(0.0, before - 1);
    store.update('pantry', i.id, i.usesUpdate(after, now));
    final left = (after - 1e-9).ceil();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            left == 0
                ? '${i.name} ist aufgebraucht.'
                : '${i.name}: ${usesText(left, i.uses!)}',
          ),
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () =>
                store.update('pantry', i.id, i.usesUpdate(before, now)),
          ),
        ),
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

  late bool _countUses = widget.item?.countsUses ?? false;
  late final _uses = TextEditingController(text: widget.item?.uses?.toString());
  late final String _leftAtStart = widget.item?.countsUses == true
      ? widget.item!.remaining(DateTime.now()).toString()
      : '';
  late final _left = TextEditingController(text: _leftAtStart);
  late bool _auto = widget.item?.autoUses ?? false;
  late final _autoAmount = TextEditingController(
    text: widget.item?.autoUses == true
        ? formatAmount(widget.item!.autoAmount)
        : '1',
  );
  late AutoUnit _autoUnit = widget.item?.autoUnit ?? AutoUnit.day;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _uses.dispose();
    _left.dispose();
    _autoAmount.dispose();
    super.dispose();
  }

  /// Felder für Nutzungen, oder null bei einer Eingabe, die nicht passt.
  Map<String, dynamic>? _usesFields() {
    if (!_countUses) {
      return {'uses': null, 'usesLeft': null, 'usesAt': null, 'autoAmount': 0};
    }
    final total = int.tryParse(_uses.text.trim());
    if (total == null || total <= 0) {
      showError(
        context,
        'Bitte gib an, wie viele Nutzungen es insgesamt sind.',
      );
      return null;
    }
    final now = DateTime.now();
    final i = widget.item;
    // Unverändert: genauen Stand behalten, sonst die Eingabe (leer = voll).
    final double left;
    if (i != null && i.countsUses && _left.text.trim() == _leftAtStart) {
      left = math.min(i.usesLeftAt(now), total.toDouble());
    } else if (_left.text.trim().isEmpty) {
      left = total.toDouble();
    } else {
      final l = int.tryParse(_left.text.trim());
      if (l == null || l < 0) {
        showError(
          context,
          'Bitte gib an, wie viele Nutzungen noch übrig sind.',
        );
        return null;
      }
      left = math.min(l, total).toDouble();
    }
    var amount = 0.0;
    if (_auto) {
      final a = parseAmount(_autoAmount.text);
      if (a == null || a <= 0) {
        showError(
          context,
          'Bitte gib an, wie viel automatisch verbraucht wird.',
        );
        return null;
      }
      amount = a;
    }
    return {
      'uses': total,
      'usesLeft': left,
      'usesAt': Timestamp.fromDate(now),
      'autoAmount': amount,
      'autoUnit': _autoUnit.name,
      'level': levelForUses(left, total).name,
    };
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showError(context, 'Bitte gib einen Namen ein.');
    final uses = _usesFields();
    if (uses == null) return;
    await ref.read(storeProvider(widget.householdId)).save(
      'pantry',
      widget.item?.id,
      {
        'name': name,
        'place': _place.text.trim(),
        'level': _level.name,
        'bestBefore': writeDate(_bestBefore),
        ...uses,
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
        Row(
          children: [
            ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, name, _) => ItemAvatar(
                householdId: widget.householdId,
                name: name.text,
                size: 48,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                autofocus: i == null,
                decoration: const InputDecoration(
                  labelText: 'Was?',
                  hintText: 'z. B. Nudeln, Klopapier',
                  helperText: 'Symbol antippen für ein Produktfoto',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
        TextField(
          controller: _place,
          decoration: const InputDecoration(
            labelText: 'Raum (optional)',
            hintText: 'z. B. Keller, Küche, Bad',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (!_countUses)
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Nutzungen zählen'),
          subtitle: const Text('z. B. Badezusatz für 10 Bäder'),
          value: _countUses,
          onChanged: (v) => setState(() => _countUses = v),
        ),
        if (_countUses) ...[
          TextField(
            controller: _uses,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nutzungen insgesamt',
              hintText: 'z. B. 10',
            ),
          ),
          TextField(
            controller: _left,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Davon noch übrig',
              hintText: 'leer = alle',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatisch verbrauchen'),
            subtitle: const Text(
              'Für Sachen, die ihr ständig nutzt, z. B. Seife',
            ),
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          if (_auto) ...[
            TextField(
              controller: _autoAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Wie viele Nutzungen?',
                hintText: 'z. B. 1 oder 0,5',
              ),
            ),
            SegmentedButton<AutoUnit>(
              segments: [
                for (final u in AutoUnit.values)
                  ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {_autoUnit},
              onSelectionChanged: (s) => setState(() => _autoUnit = s.first),
            ),
          ],
        ],
      ],
    );
  }
}
