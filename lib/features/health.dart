import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import 'health_rules.dart';

/// Gesundheit:
/// - gemeinsame Einträge: households/{id}/health
/// - private Einträge: users/{uid}/health (sieht nur die Person selbst)
/// - Geburtsdatum und Geschlecht: households/{id}.healthProfiles.{uid}
enum HealthKind {
  appointment('Arzttermin', Icons.medical_services_outlined),
  vaccination('Impfung', Icons.vaccines_outlined),
  checkup('Vorsorge', Icons.health_and_safety_outlined);

  const HealthKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static HealthKind parse(String? name) =>
      HealthKind.values.where((k) => k.name == name).firstOrNull ??
      HealthKind.appointment;
}

class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.person,
    required this.recKey,
    required this.doctor,
    required this.note,
    required this.isPrivate,
  });

  final String id;
  final HealthKind kind;
  final String title;
  final DateTime date;
  final String person;

  /// Schlüssel der Empfehlung (z. B. "tetanus"), falls zugeordnet.
  final String? recKey;
  final String doctor;
  final String note;
  final bool isPrivate;

  factory HealthEntry.fromDoc(Doc d, {required bool isPrivate}) => HealthEntry(
    id: d.id,
    kind: HealthKind.parse(d.data['kind'] as String?),
    title: d.data['title'] as String? ?? '',
    date: readDate(d.data['date']) ?? today(),
    person: d.data['person'] as String? ?? '',
    recKey: d.data['recKey'] as String?,
    doctor: d.data['doctor'] as String? ?? '',
    note: d.data['note'] as String? ?? '',
    isPrivate: isPrivate,
  );
}

typedef HealthProfile = ({DateTime? birthday, Sex sex});

final healthProfilesProvider =
    Provider.family<Map<String, HealthProfile>, String>((ref, householdId) {
      final raw =
          ref.watch(householdDataProvider(householdId)).value?['healthProfiles']
              as Map? ??
          const {};
      return {
        for (final e in raw.entries)
          if (e.value is Map)
            e.key as String: (
              birthday: readDate((e.value as Map)['birthday']),
              sex: Sex.parse((e.value as Map)['sex'] as String?),
            ),
      };
    });

final privateHealthProvider = StreamProvider<List<Doc>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('users/$uid/health')
      .snapshots()
      .map((s) => [for (final d in s.docs) Doc(d.id, d.data())]);
});

/// Alle Einträge, die ich sehen darf: gemeinsame plus meine privaten.
final healthEntriesProvider =
    Provider.family<AsyncValue<List<HealthEntry>>, String>((ref, householdId) {
      final shared = ref.watch(
        collectionProvider((householdId: householdId, collection: 'health')),
      );
      final private = ref.watch(privateHealthProvider);
      return shared.whenData((s) {
        final list = [
          for (final d in s) HealthEntry.fromDoc(d, isPrivate: false),
          for (final d in private.value ?? const <Doc>[])
            HealthEntry.fromDoc(d, isPrivate: true),
        ];
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
    });

/// Letztes Datum je Empfehlung für eine Person (nur vergangene Einträge).
Map<String, DateTime> lastDoneByKey(
  List<HealthEntry> entries,
  String person,
  DateTime now,
) {
  final result = <String, DateTime>{};
  for (final e in entries) {
    if (e.person != person || e.recKey == null || e.date.isAfter(now)) continue;
    final current = result[e.recKey!];
    if (current == null || e.date.isAfter(current)) result[e.recKey!] = e.date;
  }
  return result;
}

/// Kommende Arzttermine (gemeinsame und eigene private), ab heute.
List<HealthEntry> upcomingAppointments(
  List<HealthEntry> entries,
  DateTime now,
) =>
    entries
        .where(
          (e) =>
              e.kind == HealthKind.appointment &&
              !e.date.isBefore(dateOnly(now)),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

class HealthStore {
  HealthStore(this.store);

  final HouseholdStore store;

  Future<void> save(
    HealthEntry? old,
    Map<String, dynamic> data,
    bool isPrivate,
  ) async {
    final privateCol = store.firestore.collection('users/${store.uid}/health');
    // Wechselt ein Eintrag zwischen privat und gemeinsam, zieht er um.
    if (old != null && old.isPrivate != isPrivate) await delete(old);
    final keep = old != null && old.isPrivate == isPrivate;
    if (isPrivate) {
      await writeInBackground(
        keep ? privateCol.doc(old.id).update(data) : privateCol.doc().set(data),
      );
    } else {
      await store.save('health', keep ? old.id : null, data);
    }
  }

  Future<void> delete(HealthEntry e) => e.isPrivate
      ? writeInBackground(
          store.firestore
              .collection('users/${store.uid}/health')
              .doc(e.id)
              .delete(),
        )
      : store.delete('health', e.id);
}

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  String? _person;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final ids = memberIds(ref, widget.householdId);
    final names = memberNames(ref, widget.householdId);
    final person = _person ?? uid;
    final entries = ref.watch(healthEntriesProvider(widget.householdId));
    final profile = ref.watch(
      healthProfilesProvider(widget.householdId),
    )[person];
    final isMe = person == uid;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Gesundheit')),
      floatingActionButton: isMe
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Eintrag'),
              onPressed: () => _open(context, null, null),
            )
          : null,
      body: asyncBody(entries, (all) {
        final mine = all.where((e) => e.person == person).toList();
        final appointments = upcomingAppointments(mine, now);
        final history = mine
            .where(
              (e) =>
                  !(e.kind == HealthKind.appointment &&
                      !e.date.isBefore(dateOnly(now))),
            )
            .toList();
        final states = profile?.birthday == null
            ? const <RecState>[]
            : evaluate(
                birthday: profile!.birthday!,
                sex: profile.sex,
                lastDone: lastDoneByKey(mine, person, now),
                now: now,
              );

        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (ids.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<String>(
                  segments: [
                    for (final id in ids)
                      ButtonSegment(
                        value: id,
                        label: Text(id == uid ? 'Ich' : names[id] ?? '?'),
                      ),
                  ],
                  selected: {person},
                  onSelectionChanged: (s) => setState(() => _person = s.first),
                ),
              ),
            if (!isMe)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Private Einträge siehst nur die Person selbst.'),
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: Text(
                  profile?.birthday == null
                      ? 'Geburtsdatum eintragen'
                      : 'Geboren am ${formatShortDate(profile!.birthday!)} '
                            '(${ageOn(profile.birthday!, now)} Jahre)',
                ),
                subtitle: Text(
                  profile?.birthday == null
                      ? 'Dann zeigt die App passende Vorsorge und Impfungen.'
                      : 'Angabe für Vorsorge: ${profile!.sex.label}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editProfile(context, profile),
              ),
            const SectionHeader('Nächste Arzttermine'),
            if (appointments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Keine Termine eingetragen.'),
              ),
            for (final e in appointments) _entryTile(context, e, isMe),
            if (profile?.birthday != null) ...[
              const SectionHeader('Empfehlungen'),
              for (final s in states)
                ListTile(
                  leading: Icon(
                    s.rec.kind == RecommendationKind.vaccination
                        ? Icons.vaccines_outlined
                        : Icons.health_and_safety_outlined,
                    color: s.status == RecStatus.due
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(s.rec.title),
                  subtitle: Text(
                    [
                      s.rec.detail,
                      switch (s.status) {
                        RecStatus.due when s.last == null =>
                          'Noch nicht eingetragen',
                        RecStatus.due =>
                          'Fällig (zuletzt ${formatShortDate(s.last!)})',
                        RecStatus.ok =>
                          'Nächste ab ${formatShortDate(s.next!)}',
                        RecStatus.done =>
                          'Erledigt am ${formatShortDate(s.last!)}',
                      },
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: isMe
                      ? IconButton(
                          tooltip: 'Erledigt eintragen',
                          icon: const Icon(Icons.add_task),
                          onPressed: () => _open(context, null, s.rec),
                        )
                      : null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Allgemeine Empfehlungen der gesetzlichen Krankenkassen und der '
                  'STIKO für Erwachsene, vereinfacht. Sie ersetzen keine ärztliche '
                  'Beratung, bei Vorerkrankungen oder Reisen kann mehr sinnvoll sein.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SectionHeader('Verlauf'),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Noch keine Impfungen oder Vorsorge eingetragen.'),
              ),
            for (final e in history) _entryTile(context, e, isMe),
          ],
        );
      }),
    );
  }

  Widget _entryTile(BuildContext context, HealthEntry e, bool editable) =>
      ListTile(
        leading: Icon(e.kind.icon),
        title: Text(e.title),
        subtitle: Text(
          [
            formatDate(e.date),
            if (e.doctor.isNotEmpty) e.doctor,
            if (e.isPrivate) 'privat',
          ].join(' · '),
        ),
        trailing: e.isPrivate ? const Icon(Icons.lock_outline, size: 18) : null,
        onTap: editable ? () => _open(context, e, null) : null,
      );

  Future<void> _editProfile(
    BuildContext context,
    HealthProfile? profile,
  ) async {
    final birthday = await showDatePicker(
      context: context,
      helpText: 'Dein Geburtsdatum',
      initialDate: profile?.birthday ?? DateTime(1995),
      firstDate: DateTime(1920),
      lastDate: today(),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (birthday == null || !context.mounted) return;
    final sex = await showDialog<Sex>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Für welche Vorsorge?'),
        children: [
          for (final s in Sex.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(switch (s) {
                Sex.female => 'Vorsorge für Frauen',
                Sex.male => 'Vorsorge für Männer',
                Sex.unknown => 'Keine Angabe (alles zeigen)',
              }),
            ),
        ],
      ),
    );
    final store = ref.read(storeProvider(widget.householdId));
    await store.updateHousehold({
      'healthProfiles.${store.uid}': {
        'birthday': writeDate(birthday),
        'sex': (sex ?? profile?.sex ?? Sex.unknown).name,
      },
    });
  }

  void _open(BuildContext context, HealthEntry? e, Recommendation? rec) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HealthEditScreen(
            householdId: widget.householdId,
            entry: e,
            fromRecommendation: rec,
          ),
        ),
      );
}

class HealthEditScreen extends ConsumerStatefulWidget {
  const HealthEditScreen({
    super.key,
    required this.householdId,
    this.entry,
    this.fromRecommendation,
  });

  final String householdId;
  final HealthEntry? entry;
  final Recommendation? fromRecommendation;

  @override
  ConsumerState<HealthEditScreen> createState() => _HealthEditScreenState();
}

class _HealthEditScreenState extends ConsumerState<HealthEditScreen> {
  late final _title = TextEditingController(
    text: widget.entry?.title ?? widget.fromRecommendation?.title,
  );
  late final _doctor = TextEditingController(text: widget.entry?.doctor);
  late final _note = TextEditingController(text: widget.entry?.note);
  late HealthKind _kind =
      widget.entry?.kind ??
      switch (widget.fromRecommendation?.kind) {
        RecommendationKind.vaccination => HealthKind.vaccination,
        RecommendationKind.checkup => HealthKind.checkup,
        null => HealthKind.appointment,
      };
  late DateTime _date = widget.entry?.date ?? today();
  late String? _recKey = widget.entry?.recKey ?? widget.fromRecommendation?.key;
  late bool _private = widget.entry?.isPrivate ?? false;

  @override
  void dispose() {
    _title.dispose();
    _doctor.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return showError(context, 'Bitte gib einen Titel ein.');
    final store = ref.read(storeProvider(widget.householdId));
    await HealthStore(store).save(widget.entry, {
      'kind': _kind.name,
      'title': title,
      'date': writeDate(_date),
      'person': store.uid,
      'recKey': _kind == HealthKind.appointment ? null : _recKey,
      'doctor': _doctor.text.trim(),
      'note': _note.text.trim(),
    }, _private);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final matching = recommendations
        .where(
          (r) =>
              (_kind == HealthKind.vaccination &&
                  r.kind == RecommendationKind.vaccination) ||
              (_kind == HealthKind.checkup &&
                  r.kind == RecommendationKind.checkup),
        )
        .toList();
    return EditScaffold(
      title: e == null ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
      onSave: _save,
      onDelete: e == null
          ? null
          : () async {
              if (!await confirmDelete(context, e.title) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await HealthStore(ref.read(storeProvider(widget.householdId)))
                  .delete(e);
            },
      children: [
        SegmentedButton<HealthKind>(
          segments: [
            for (final k in HealthKind.values)
              ButtonSegment(value: k, label: Text(k.label)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: 'Was?',
            hintText: switch (_kind) {
              HealthKind.appointment => 'z. B. Zahnarzt Kontrolle',
              HealthKind.vaccination => 'z. B. Tetanus-Auffrischung',
              HealthKind.checkup => 'z. B. Hautkrebs-Screening',
            },
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        DateField(
          label: _kind == HealthKind.appointment ? 'Termin am' : 'Erledigt am',
          value: _date,
          allowClear: false,
          onChanged: (v) => setState(() => _date = v ?? _date),
        ),
        if (_kind != HealthKind.appointment)
          DropdownButtonFormField<String?>(
            initialValue: matching.any((r) => r.key == _recKey)
                ? _recKey
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Zählt als Empfehlung',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Keine')),
              for (final r in matching)
                DropdownMenuItem(value: r.key, child: Text(r.title)),
            ],
            onChanged: (v) => setState(() => _recKey = v),
          ),
        TextField(
          controller: _doctor,
          decoration: const InputDecoration(
            labelText: 'Arzt oder Praxis (optional)',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Notiz (optional)'),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lock_outline),
          title: const Text('Privat'),
          subtitle: const Text('Nur du siehst diesen Eintrag.'),
          value: _private,
          onChanged: (v) => setState(() => _private = v),
        ),
      ],
    );
  }
}
