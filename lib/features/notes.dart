import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/symbols.dart';
import '../widgets/common.dart';
import '../widgets/cute.dart';
import '../widgets/pic_tile.dart';
import '../widgets/mascots.dart';

const noteCategories = [
  'Allgemein',
  'Wichtig',
  'Geschenkideen',
  'Kontakte & Nummern',
  'Größen & Maße',
];

/// households/{id}/notes: geteilte Notizen und Pinnwand.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.pinned,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool pinned;

  factory Note.fromDoc(Doc d) => Note(
    id: d.id,
    title: d.data['title'] as String? ?? '',
    body: d.data['body'] as String? ?? '',
    category: d.data['category'] as String? ?? 'Allgemein',
    pinned: d.data['pinned'] as bool? ?? false,
  );
}

final notesProvider = Provider.family<AsyncValue<List<Note>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'notes')),
      )
      .whenData(
        (docs) => docs.map(Note.fromDoc).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }),
      ),
);

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(widget.householdId));
    return Scaffold(
      appBar: AppBar(title: const Text('Notizen & Pinnwand')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Notiz'),
        onPressed: () => _open(context, null),
      ),
      body: asyncBody(notes, (list) {
        final shown = _filter == null
            ? list
            : list.where((n) => n.category == _filter).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final c in [null, ...noteCategories])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(c ?? 'Alle'),
                        selected: _filter == c,
                        onSelected: (_) => setState(() => _filter = c),
                      ),
                    ),
                ],
              ),
            ),
            if (shown.isEmpty)
              const EmptyHint(
                icon: Icons.sticky_note_2_outlined,
                mood: MascotMood.thinking,
                text:
                    'Hier ist Platz für WLAN-Passwort, Handwerker-Nummern, '
                    'Kleidergrößen und Geschenkideen.',
              ),
            PicGrid(
              children: [
                for (final n in shown)
                  PicTile(
                    title: n.title,
                    emoji: symbolFor(
                      '${n.category} ${n.title}',
                      noteSymbols,
                      '📝',
                    ),
                    tone: _toneFor(n),
                    picture: n.body.trim().isEmpty
                        ? null
                        : _NotePaper(note: n, tone: _toneFor(n)),
                    subtitle: n.category,
                    badge: n.pinned ? 'angepinnt' : null,
                    badgeIcon: n.pinned ? Icons.push_pin : null,
                    onTap: () => _open(context, n),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }

  void _open(BuildContext context, Note? n) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NoteEditScreen(
        householdId: widget.householdId,
        note: n,
        initialCategory: _filter,
      ),
    ),
  );
}

CuteTone _toneFor(Note n) => switch (n.category) {
  'Wichtig' || 'Geschenkideen' => CuteTone.pink,
  'Kontakte & Nummern' || 'Größen & Maße' => CuteTone.mint,
  _ => CuteTone.vanilla,
};

/// Notizzettel als Bild der Kachel: der Anfang des Textes auf Pastellpapier.
class _NotePaper extends StatelessWidget {
  const _NotePaper({required this.note, required this.tone});

  final Note note;
  final CuteTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? theme.colorScheme.surfaceContainerHighest : tone.soft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Text(
          note.body.trim(),
          overflow: TextOverflow.fade,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
        ),
      ),
    );
  }
}

class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({
    super.key,
    required this.householdId,
    this.note,
    this.initialCategory,
  });

  final String householdId;
  final Note? note;
  final String? initialCategory;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late String _category =
      widget.note?.category ?? widget.initialCategory ?? noteCategories.first;
  late bool _pinned = widget.note?.pinned ?? false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return showError(context, 'Bitte gib einen Titel ein.');
    await ref.read(storeProvider(widget.householdId)).save(
      'notes',
      widget.note?.id,
      {
        'title': title,
        'body': _body.text.trim(),
        'category': _category,
        'pinned': _pinned,
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return EditScaffold(
      title: n == null ? 'Neue Notiz' : 'Notiz bearbeiten',
      onSave: _save,
      onDelete: n == null
          ? null
          : () async {
              if (!await confirmDelete(context, n.title) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('notes', n.id);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: n == null,
          decoration: const InputDecoration(
            labelText: 'Titel',
            hintText: 'z. B. WLAN-Passwort',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _body,
          decoration: const InputDecoration(
            labelText: 'Inhalt',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 5,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
        ),
        DropdownButtonFormField<String>(
          initialValue: noteCategories.contains(_category)
              ? _category
              : 'Allgemein',
          decoration: const InputDecoration(labelText: 'Kategorie'),
          items: [
            for (final c in noteCategories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Oben anpinnen'),
          value: _pinned,
          onChanged: (v) => setState(() => _pinned = v),
        ),
      ],
    );
  }
}
