import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';

/// "Zusammen seit" steht im Haushalts-Dokument (togetherSince).
/// households/{id}/ideas: Bucket-Liste und Date-Ideen.
enum IdeaKind {
  date('Date-Ideen', Icons.local_bar_outlined),
  bucket('Bucket-Liste', Icons.star_outline),
  goal('Gemeinsame Ziele', Icons.flag_outlined);

  const IdeaKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static IdeaKind parse(String? name) =>
      IdeaKind.values.where((k) => k.name == name).firstOrNull ?? IdeaKind.date;
}

class Idea {
  const Idea({
    required this.id,
    required this.text,
    required this.kind,
    required this.done,
  });

  final String id;
  final String text;
  final IdeaKind kind;
  final bool done;

  factory Idea.fromDoc(Doc d) => Idea(
    id: d.id,
    text: d.data['text'] as String? ?? '',
    kind: IdeaKind.parse(d.data['kind'] as String?),
    done: d.data['done'] as bool? ?? false,
  );
}

final ideasProvider = Provider.family<AsyncValue<List<Idea>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'ideas')),
      )
      .whenData(
        (docs) => docs.map(Idea.fromDoc).toList()
          ..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            return a.text.toLowerCase().compareTo(b.text.toLowerCase());
          }),
      ),
);

final togetherSinceProvider = Provider.family<DateTime?, String>(
  (ref, householdId) => readDate(
    ref.watch(householdDataProvider(householdId)).value?['togetherSince'],
  ),
);

/// Karte mit "Zusammen seit …" und dem nächsten Jahrestag.
class TogetherCard extends ConsumerWidget {
  const TogetherCard({super.key, required this.householdId});

  final String householdId;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'Seit wann seid ihr zusammen?',
      initialDate: current ?? today(),
      firstDate: DateTime(1950),
      lastDate: today(),
    );
    if (picked == null) return;
    await ref.read(storeProvider(householdId)).updateHousehold({
      'togetherSince': writeDate(picked),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = ref.watch(togetherSinceProvider(householdId));
    final textTheme = Theme.of(context).textTheme;
    if (since == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('Seit wann seid ihr zusammen?'),
          subtitle: const Text(
            'Dann zählt die App eure Tage und erinnert an den Jahrestag.',
          ),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () => _pick(context, ref, null),
        ),
      );
    }
    final days = daysBetween(since, today());
    final next = nextAnniversary(since);
    final years = next.year - since.year;
    final until = daysBetween(today(), next);
    return Card(
      child: InkWell(
        onTap: () => _pick(context, ref, since),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.favorite,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$days Tage zusammen', style: textTheme.titleLarge),
                    Text('seit ${formatShortDate(since)}'),
                    Text(
                      until == 0
                          ? 'Heute ist euer $years. Jahrestag!'
                          : 'Noch $until Tage bis zum $years. Jahrestag',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key, required this.householdId, required this.kind});

  final String householdId;
  final IdeaKind kind;

  @override
  ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(storeProvider(widget.householdId)).add('ideas', {
      'text': text,
      'kind': widget.kind.name,
      'done': false,
    });
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ideas = ref.watch(ideasProvider(widget.householdId));
    final store = ref.read(storeProvider(widget.householdId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.label)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _input,
              decoration: InputDecoration(
                hintText: switch (widget.kind) {
                  IdeaKind.date => 'z. B. Picknick im Park',
                  IdeaKind.bucket => 'z. B. Polarlichter sehen',
                  IdeaKind.goal => 'z. B. Zusammen 1.000 € sparen',
                },
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _add,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _add(),
            ),
          ),
          Expanded(
            child: asyncBody(ideas, (all) {
              final list = all.where((i) => i.kind == widget.kind).toList();
              if (list.isEmpty) {
                return EmptyHint(icon: widget.kind.icon, text: 'Noch leer.');
              }
              return ListView(
                children: [
                  for (final i in list)
                    CheckboxListTile(
                      value: i.done,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        i.text,
                        style: i.done
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      secondary: IconButton(
                        tooltip: 'Löschen',
                        icon: const Icon(Icons.close),
                        onPressed: () => store.delete('ideas', i.id),
                      ),
                      onChanged: (v) =>
                          store.update('ideas', i.id, {'done': v ?? false}),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
