import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

enum CareKind {
  plant('Pflanze', Icons.local_florist_outlined),
  pet('Haustier', Icons.pets);

  const CareKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static CareKind parse(String? name) =>
      CareKind.values.where((k) => k.name == name).firstOrNull ??
      CareKind.plant;
}

/// households/{id}/care: Pflanzen gießen, Tiere füttern, Tierarzt usw.
class CareItem {
  const CareItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.action,
    required this.intervalDays,
    required this.lastDone,
    required this.lastBy,
  });

  final String id;
  final String name;
  final CareKind kind;
  final String action;
  final int intervalDays;
  final DateTime? lastDone;
  final String lastBy;

  /// Nie erledigt = heute fällig.
  DateTime get nextDue =>
      lastDone == null ? today() : addDays(lastDone!, intervalDays);

  bool isDue(DateTime now) => !nextDue.isAfter(dateOnly(now));

  factory CareItem.fromDoc(Doc d) => CareItem(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    kind: CareKind.parse(d.data['kind'] as String?),
    action: d.data['action'] as String? ?? '',
    intervalDays: (d.data['intervalDays'] as num?)?.toInt() ?? 7,
    lastDone: readDate(d.data['lastDone']),
    lastBy: d.data['lastBy'] as String? ?? '',
  );
}

final careProvider = Provider.family<AsyncValue<List<CareItem>>, String>(
  (ref, householdId) => ref
      .watch(collectionProvider((householdId: householdId, collection: 'care')))
      .whenData(
        (docs) =>
            docs.map(CareItem.fromDoc).toList()
              ..sort((a, b) => a.nextDue.compareTo(b.nextDue)),
      ),
);

class CareScreen extends ConsumerWidget {
  const CareScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(careProvider(householdId));
    final store = ref.read(storeProvider(householdId));
    final names = memberNames(ref, householdId);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Haustiere & Pflanzen')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Eintrag'),
        onPressed: () => _open(context, null),
      ),
      body: asyncBody(items, (list) {
        if (list.isEmpty) {
          return const EmptyHint(
            icon: Icons.local_florist_outlined,
            mood: MascotMood.care,
            text: 'Z. B. „Monstera gießen alle 7 Tage“ oder „Katze entwurmen alle 90 Tage“.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final c in list)
              ListTile(
                leading: CircleAvatar(child: Icon(c.kind.icon)),
                title: Text('${c.name}: ${c.action}'),
                subtitle: Text(
                  [
                    'alle ${c.intervalDays} Tage',
                    if (c.lastDone != null)
                      'zuletzt ${relativeDay(c.lastDone!)}'
                          '${c.lastBy.isEmpty ? '' : ' von ${names[c.lastBy] ?? '?'}'}',
                    c.isDue(now)
                        ? 'jetzt fällig'
                        : 'fällig ${dueText(c.nextDue)}',
                  ].join(' · '),
                  style: c.isDue(now)
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                trailing: IconButton(
                  tooltip: 'Erledigt',
                  icon: Icon(
                    Icons.check_circle,
                    color: c.isDue(now)
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => store.update('care', c.id, {
                    'lastDone': writeDate(today()),
                    'lastBy': store.uid,
                  }),
                ),
                onTap: () => _open(context, c),
              ),
          ],
        );
      }),
    );
  }

  void _open(BuildContext context, CareItem? c) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CareEditScreen(householdId: householdId, item: c),
    ),
  );
}

class CareEditScreen extends ConsumerStatefulWidget {
  const CareEditScreen({super.key, required this.householdId, this.item});

  final String householdId;
  final CareItem? item;

  @override
  ConsumerState<CareEditScreen> createState() => _CareEditScreenState();
}

class _CareEditScreenState extends ConsumerState<CareEditScreen> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _action = TextEditingController(
    text: widget.item?.action ?? 'Gießen',
  );
  late final _interval = TextEditingController(
    text: '${widget.item?.intervalDays ?? 7}',
  );
  late CareKind _kind = widget.item?.kind ?? CareKind.plant;

  @override
  void dispose() {
    _name.dispose();
    _action.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final interval = int.tryParse(_interval.text.trim());
    if (name.isEmpty) return showError(context, 'Bitte gib einen Namen ein.');
    if (interval == null || interval < 1) {
      return showError(context, 'Bitte gib an, alle wie viele Tage.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'care',
      widget.item?.id,
      {
        'name': name,
        'kind': _kind.name,
        'action': _action.text.trim().isEmpty ? 'Pflegen' : _action.text.trim(),
        'intervalDays': interval,
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    return EditScaffold(
      title: c == null ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
      onSave: _save,
      onDelete: c == null
          ? null
          : () async {
              if (!await confirmDelete(context, c.name) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('care', c.id);
            },
      children: [
        SegmentedButton<CareKind>(
          segments: [
            for (final k in CareKind.values)
              ButtonSegment(value: k, label: Text(k.label), icon: Icon(k.icon)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            if (_action.text == 'Gießen' || _action.text == 'Füttern') {
              _action.text = _kind == CareKind.plant ? 'Gießen' : 'Füttern';
            }
          }),
        ),
        TextField(
          controller: _name,
          autofocus: c == null,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: _kind == CareKind.plant ? 'z. B. Monstera' : 'z. B. Mimi',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _action,
          decoration: const InputDecoration(
            labelText: 'Was ist zu tun?',
            hintText: 'z. B. Gießen, Füttern, Tierarzt',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _interval,
          decoration: const InputDecoration(
            labelText: 'Alle wie viele Tage?',
            suffixText: 'Tage',
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
