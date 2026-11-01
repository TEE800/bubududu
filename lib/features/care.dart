import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';
import 'plant_identify.dart';
import 'plants.dart';

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
    this.fertilizeDays = 0,
    this.lastFertilized,
    this.species = '',
    this.location = '',
    this.light = '',
    this.waterNote = '',
    this.fertilizeNote = '',
    this.notes = '',
    this.since,
    this.photoId = '',
  });

  final String id;
  final String name;
  final CareKind kind;
  final String action;
  final int intervalDays;
  final DateTime? lastDone;
  final String lastBy;

  // Pflanzenprofil (bei Haustieren leer).
  /// Düngen alle so viele Tage, 0 = gar nicht.
  final int fertilizeDays;
  final DateTime? lastFertilized;
  final String species;
  final String location;
  final String light;
  final String waterNote;
  final String fertilizeNote;
  final String notes;

  /// Seit wann die Pflanze bei uns ist.
  final DateTime? since;

  /// Neuestes Foto in plantPhotos, '' = keins.
  final String photoId;

  bool get fertilizes => fertilizeDays > 0;

  /// Nie gedüngt = heute fällig.
  DateTime? get nextFertilize => !fertilizes
      ? null
      : lastFertilized == null
      ? today()
      : addDays(lastFertilized!, fertilizeDays);

  bool isFertilizeDue(DateTime now) =>
      nextFertilize != null && !nextFertilize!.isAfter(dateOnly(now));

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
    fertilizeDays: (d.data['fertilizeDays'] as num?)?.toInt() ?? 0,
    lastFertilized: readDate(d.data['lastFertilized']),
    species: d.data['species'] as String? ?? '',
    location: d.data['location'] as String? ?? '',
    light: d.data['light'] as String? ?? '',
    waterNote: d.data['waterNote'] as String? ?? '',
    fertilizeNote: d.data['fertilizeNote'] as String? ?? '',
    notes: d.data['notes'] as String? ?? '',
    since: readDate(d.data['since']),
    photoId: d.data['photoId'] as String? ?? '',
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
        final plants = list.where((c) => c.kind == CareKind.plant).toList();
        final pets = list.where((c) => c.kind == CareKind.pet).toList();
        Widget tile(CareItem c) => ListTile(
          leading: c.kind == CareKind.plant
              ? PlantAvatar(householdId: householdId, plant: c)
              : CircleAvatar(child: Icon(c.kind.icon)),
          title: Text('${c.name}: ${c.action}'),
          subtitle: Text(
            [
              if (c.location.isNotEmpty) c.location,
              'alle ${c.intervalDays} Tage',
              if (c.lastDone != null)
                'zuletzt ${relativeDay(c.lastDone!)}'
                    '${c.lastBy.isEmpty ? '' : ' von ${names[c.lastBy] ?? '?'}'}',
              c.isDue(now) ? 'jetzt fällig' : 'fällig ${dueText(c.nextDue)}',
              if (c.isFertilizeDue(now)) 'Düngen fällig',
            ].join(' · '),
            style: c.isDue(now) || c.isFertilizeDue(now)
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
          onTap: () => c.kind == CareKind.plant
              ? Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlantProfileScreen(
                      householdId: householdId,
                      plantId: c.id,
                    ),
                  ),
                )
              : _open(context, c),
        );
        final both = plants.isNotEmpty && pets.isNotEmpty;
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (both) const SectionHeader('Pflanzen'),
            for (final c in plants) tile(c),
            if (both) const SectionHeader('Haustiere'),
            for (final c in pets) tile(c),
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

const plantLights = ['Sonnig', 'Hell', 'Halbschatten', 'Schattig'];

class _CareEditScreenState extends ConsumerState<CareEditScreen> {
  late final CareItem? _c = widget.item;
  late final _name = TextEditingController(text: _c?.name);
  late final _action = TextEditingController(text: _c?.action ?? 'Gießen');
  late final _interval = TextEditingController(
    text: '${_c?.intervalDays ?? 7}',
  );
  late final _species = TextEditingController(text: _c?.species);
  late final _location = TextEditingController(text: _c?.location);
  late final _waterNote = TextEditingController(text: _c?.waterNote);
  late final _fertilizeDays = TextEditingController(
    text: (_c?.fertilizeDays ?? 0) > 0 ? '${_c!.fertilizeDays}' : '',
  );
  late final _fertilizeNote = TextEditingController(text: _c?.fertilizeNote);
  late final _notes = TextEditingController(text: _c?.notes);
  late CareKind _kind = _c?.kind ?? CareKind.plant;
  late String _light = _c?.light ?? '';
  late DateTime? _since = _c?.since;

  /// Foto aus der Erkennung, wird bei neuen Pflanzen das erste Profilfoto.
  Uint8List? _photo;
  bool _identifying = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _action,
      _interval,
      _species,
      _location,
      _waterNote,
      _fertilizeDays,
      _fertilizeNote,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final interval = int.tryParse(_interval.text.trim());
    final fertilize = _fertilizeDays.text.trim().isEmpty
        ? 0
        : int.tryParse(_fertilizeDays.text.trim());
    if (name.isEmpty) return showError(context, 'Bitte gib einen Namen ein.');
    if (interval == null || interval < 1) {
      return showError(context, 'Bitte gib an, alle wie viele Tage.');
    }
    if (_kind == CareKind.plant && (fertilize == null || fertilize < 0)) {
      return showError(
        context,
        'Bitte gib an, alle wie viele Tage gedüngt wird.',
      );
    }
    final plant = _kind == CareKind.plant;
    final store = ref.read(storeProvider(widget.householdId));
    final photo = plant && _c == null ? _photo : null;
    final newId = photo == null ? null : store.newId('care');
    final data = {
      'name': name,
      'kind': _kind.name,
      'action': _action.text.trim().isEmpty ? 'Pflegen' : _action.text.trim(),
      'intervalDays': interval,
      if (plant) ...{
        'species': _species.text.trim(),
        'location': _location.text.trim(),
        'light': _light,
        'waterNote': _waterNote.text.trim(),
        'fertilizeDays': fertilize,
        'fertilizeNote': _fertilizeNote.text.trim(),
        'notes': _notes.text.trim(),
        'since': writeDate(_since),
      },
    };
    if (newId != null) {
      await store.add('care', data, id: newId);
      await addPlantPhoto(store, newId, photo!, today());
    } else {
      await store.save('care', _c?.id, data);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Foto machen, Art erkennen lassen und das Profil vorausfüllen.
  Future<void> _identify() async {
    final source = await pickPhotoSource(context);
    if (source == null || !mounted) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(plantPhotoPickerProvider)(source);
    } catch (e) {
      if (mounted) showError(context, 'Foto ging nicht: $e');
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() => _identifying = true);
    List<PlantSuggestion> suggestions;
    try {
      suggestions = await ref.read(plantIdentifierProvider)(
        widget.householdId,
        bytes,
      );
    } on PlantIdentifyException catch (e) {
      if (mounted) {
        setState(() => _identifying = false);
        showError(context, e.message);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _identifying = false);
    final picked = await showPlantSuggestions(context, bytes, suggestions);
    if (picked == null || !mounted) return;
    _apply(picked, bytes);
  }

  void _apply(PlantSuggestion s, Uint8List photo) {
    final hint = s.careHint;
    void fill(TextEditingController c, String value) {
      if (c.text.trim().isEmpty && value.isNotEmpty) c.text = value;
    }

    setState(() {
      if (photo.length <= maxPhotoBytes) _photo = photo;
      fill(_name, s.displayName);
      _species.text = s.scientificName;
      if (hint != null) {
        // Nur Felder, die noch leer bzw. auf dem Standard stehen.
        if (_c == null || _interval.text.trim() == '7') {
          _interval.text = '${hint.intervalDays}';
        }
        if (_light.isEmpty) _light = hint.light;
        fill(_waterNote, hint.waterNote);
        if (hint.fertilizeDays > 0) {
          fill(_fertilizeDays, '${hint.fertilizeDays}');
          fill(_fertilizeNote, hint.fertilizeNote);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hint == null
              ? '${s.displayName} eingetragen. Pflegetipps bitte selbst ergänzen.'
              : '${s.displayName} mit Pflegetipps eingetragen. Schau kurz drüber.',
        ),
      ),
    );
  }

  TextField _text(
    TextEditingController controller,
    String label, {
    String? hint,
    String? suffix,
    bool number = false,
    bool multiline = false,
  }) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
    ),
    keyboardType: number
        ? TextInputType.number
        : multiline
        ? TextInputType.multiline
        : null,
    minLines: 1,
    maxLines: multiline ? 4 : 1,
    textCapitalization: TextCapitalization.sentences,
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final plant = _kind == CareKind.plant;
    return EditScaffold(
      title: c == null
          ? (plant ? 'Neue Pflanze' : 'Neuer Eintrag')
          : (plant ? 'Pflanze bearbeiten' : 'Eintrag bearbeiten'),
      onSave: _save,
      onDelete: c == null
          ? null
          : () async {
              if (!await confirmDelete(context, c.name) || !context.mounted) {
                return;
              }
              final store = ref.read(storeProvider(widget.householdId));
              // true: Das Profil dahinter schließt sich auch.
              Navigator.of(context).pop(true);
              await deletePlantPhotos(store, c.id);
              await store.delete('care', c.id);
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
        if (plant)
          FilledButton.tonalIcon(
            onPressed: _identifying ? null : _identify,
            icon: _identifying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.center_focus_strong_outlined),
            label: Text(
              _identifying ? 'Wird erkannt …' : 'Pflanze per Foto erkennen',
            ),
          ),
        if (plant && _photo != null)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _photo!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  c == null
                      ? 'Das Foto kommt als erstes Bild ins Profil.'
                      : 'Erkannt anhand dieses Fotos.',
                ),
              ),
            ],
          ),
        TextField(
          controller: _name,
          autofocus: c == null,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: plant ? 'z. B. Monstera' : 'z. B. Mimi',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (plant) ...[
          _text(_species, 'Art', hint: 'z. B. Monstera deliciosa'),
          _text(_location, 'Standort', hint: 'z. B. Wohnzimmer am Fenster'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Licht', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in plantLights)
                    ChoiceChip(
                      label: Text(l),
                      selected: _light == l,
                      onSelected: (on) => setState(() => _light = on ? l : ''),
                    ),
                ],
              ),
            ],
          ),
        ],
        TextField(
          controller: _action,
          decoration: const InputDecoration(
            labelText: 'Was ist zu tun?',
            hintText: 'z. B. Gießen, Füttern, Tierarzt',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        _text(_interval, 'Alle wie viele Tage?', suffix: 'Tage', number: true),
        if (plant) ...[
          _text(
            _waterNote,
            'Gießverhalten',
            hint: 'z. B. Erde antrocknen lassen, ca. 300 ml',
            multiline: true,
          ),
          _text(
            _fertilizeDays,
            'Düngen alle wie viele Tage?',
            hint: 'leer = nie',
            suffix: 'Tage',
            number: true,
          ),
          _text(
            _fertilizeNote,
            'Düngeverhalten',
            hint: 'z. B. Grünpflanzendünger, nur März bis September',
            multiline: true,
          ),
          DateField(
            label: 'Bei uns seit',
            value: _since,
            onChanged: (d) => setState(() => _since = d),
          ),
          _text(
            _notes,
            'Notizen',
            hint: 'z. B. umgetopft im April, mag keine Zugluft',
            multiline: true,
          ),
        ],
      ],
    );
  }
}
