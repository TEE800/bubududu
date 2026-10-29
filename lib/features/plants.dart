import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/offline.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import 'care.dart';

/// households/{id}/plantPhotos: Fotos einer Pflanze, je Foto ein Dokument.
/// Die Bilder liegen verkleinert direkt in Firestore (kein Firebase Storage
/// nötig, das im kostenlosen Tarif nicht mehr angeboten wird).
class PlantPhoto {
  const PlantPhoto({
    required this.id,
    required this.plantId,
    required this.takenAt,
    required this.bytes,
  });

  final String id;
  final String plantId;
  final DateTime takenAt;
  final Uint8List bytes;

  factory PlantPhoto.fromDoc(Doc d) => PlantPhoto(
    id: d.id,
    plantId: d.data['plantId'] as String? ?? '',
    takenAt: readDate(d.data['takenAt']) ?? today(),
    bytes: switch (d.data['image']) {
      Blob b => b.bytes,
      _ => Uint8List(0),
    },
  );
}

/// Ein Firestore-Dokument darf höchstens 1 MB groß sein.
const maxPhotoBytes = 900 * 1024;

typedef PlantKey = ({String householdId, String plantId});

/// Alle Fotos einer Pflanze, das älteste zuerst.
final plantPhotosProvider = StreamProvider.family<List<PlantPhoto>, PlantKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .collection('households/${key.householdId}/plantPhotos')
      .where('plantId', isEqualTo: key.plantId)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) PlantPhoto.fromDoc(Doc(d.id, d.data()))]
              ..sort(byDate),
      ),
);

int byDate(PlantPhoto a, PlantPhoto b) {
  final c = a.takenAt.compareTo(b.takenAt);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// Nur ein einzelnes Foto (fürs Vorschaubild in der Liste).
final plantPhotoProvider =
    StreamProvider.family<PlantPhoto?, ({String householdId, String photoId})>(
      (ref, key) => ref
          .watch(firestoreProvider)
          .doc('households/${key.householdId}/plantPhotos/${key.photoId}')
          .snapshots()
          .map(
            (s) => s.exists ? PlantPhoto.fromDoc(Doc(s.id, s.data()!)) : null,
          ),
    );

final _plantProvider = Provider.family<AsyncValue<CareItem?>, PlantKey>(
  (ref, key) => ref
      .watch(careProvider(key.householdId))
      .whenData((list) => list.where((c) => c.id == key.plantId).firstOrNull),
);

/// Wählt ein Foto aus und gibt es verkleinert zurück. Im Test ersetzbar.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

final plantPhotoPickerProvider = Provider<PhotoPicker>(
  (ref) => (source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    return image?.readAsBytes();
  },
);

/// Speichert ein Foto und merkt es sich als neuestes, wenn es das ist.
Future<void> addPlantPhoto(
  HouseholdStore store,
  CareItem plant,
  Uint8List bytes,
  DateTime takenAt, {
  DateTime? latest,
}) async {
  final ref = store.col('plantPhotos').doc();
  await writeInBackground(
    ref.set({
      'plantId': plant.id,
      'takenAt': writeDate(takenAt),
      'image': Blob(bytes),
      'createdBy': store.uid,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );
  if (latest == null || !dateOnly(takenAt).isBefore(dateOnly(latest))) {
    await store.update('care', plant.id, {'photoId': ref.id});
  }
}

Future<void> deletePlantPhoto(
  HouseholdStore store,
  CareItem plant,
  PlantPhoto photo,
  List<PlantPhoto> all,
) async {
  await store.delete('plantPhotos', photo.id);
  if (plant.photoId == photo.id) {
    final rest = all.where((p) => p.id != photo.id).toList();
    await store.update('care', plant.id, {
      'photoId': rest.isEmpty ? '' : rest.last.id,
    });
  }
}

/// Beim Löschen einer Pflanze verschwinden auch ihre Fotos.
Future<void> deletePlantPhotos(HouseholdStore store, String plantId) async {
  final docs = await store
      .col('plantPhotos')
      .where('plantId', isEqualTo: plantId)
      .get();
  for (final d in docs.docs) {
    await store.delete('plantPhotos', d.id);
  }
}

/// "nach 3 Wochen", "nach 2 Monaten" seit dem ersten Foto.
String growthText(DateTime first, DateTime d) {
  final days = daysBetween(first, d);
  if (days <= 0) return 'Erstes Foto';
  if (days == 1) return 'nach 1 Tag';
  if (days < 14) return 'nach $days Tagen';
  if (days < 60) return 'nach ${days ~/ 7} Wochen';
  if (days < 730) return 'nach ${days ~/ 30} Monaten';
  return 'nach ${days ~/ 365} Jahren';
}

/// Rundes Vorschaubild in der Liste (oder das Pflanzen-Symbol).
class PlantAvatar extends ConsumerWidget {
  const PlantAvatar({
    super.key,
    required this.householdId,
    required this.plant,
  });

  final String householdId;
  final CareItem plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = plant.photoId.isEmpty
        ? null
        : ref
              .watch(
                plantPhotoProvider((
                  householdId: householdId,
                  photoId: plant.photoId,
                )),
              )
              .value;
    if (photo == null || photo.bytes.isEmpty) {
      return CircleAvatar(child: Icon(plant.kind.icon));
    }
    return CircleAvatar(
      backgroundImage: ResizeImage(MemoryImage(photo.bytes), width: 120),
    );
  }
}

class PlantProfileScreen extends ConsumerWidget {
  const PlantProfileScreen({
    super.key,
    required this.householdId,
    required this.plantId,
  });

  final String householdId;
  final String plantId;

  PlantKey get _key => (householdId: householdId, plantId: plantId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = ref.watch(_plantProvider(_key));
    final photos = ref.watch(plantPhotosProvider(_key)).value ?? const [];
    final store = ref.read(storeProvider(householdId));
    final names = memberNames(ref, householdId);
    final now = DateTime.now();

    return asyncBody(plant, (p) {
      if (p == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Diese Pflanze gibt es nicht mehr.')),
        );
      }
      final latest = photos.isEmpty ? null : photos.last;
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final deleted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CareEditScreen(householdId: householdId, item: p),
                  ),
                );
                if (deleted == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(photos.isEmpty ? 'Foto' : 'Neues Foto'),
          onPressed: () => _addPhoto(context, ref, p, latest),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (latest != null)
              GestureDetector(
                onTap: () => _openPhoto(context, p, photos, photos.length - 1),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(
                    latest.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: 1280,
                  ),
                ),
              )
            else
              Container(
                height: 160,
                color: scheme.primaryContainer,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_florist_outlined,
                      size: 56,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Noch kein Foto',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (p.species.isNotEmpty)
                    Text(
                      p.species,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            _CareCard(
              icon: Icons.water_drop_outlined,
              title: '${p.action} alle ${daysText(p.intervalDays)}',
              lines: [
                if (p.lastDone != null)
                  'Zuletzt ${relativeDay(p.lastDone!)}'
                      '${p.lastBy.isEmpty ? '' : ' von ${names[p.lastBy] ?? '?'}'}',
                p.isDue(now) ? 'Jetzt fällig' : 'Fällig ${dueText(p.nextDue)}',
                if (p.waterNote.isNotEmpty) p.waterNote,
              ],
              due: p.isDue(now),
              button: 'Gegossen',
              onDone: () => store.update('care', p.id, {
                'lastDone': writeDate(today()),
                'lastBy': store.uid,
              }),
            ),
            if (p.fertilizes || p.fertilizeNote.isNotEmpty)
              _CareCard(
                icon: Icons.science_outlined,
                title: p.fertilizes
                    ? 'Düngen alle ${daysText(p.fertilizeDays)}'
                    : 'Düngen',
                lines: [
                  if (p.lastFertilized != null)
                    'Zuletzt ${relativeDay(p.lastFertilized!)}',
                  if (p.fertilizes)
                    p.isFertilizeDue(now)
                        ? 'Jetzt fällig'
                        : 'Fällig ${dueText(p.nextFertilize!)}',
                  if (p.fertilizeNote.isNotEmpty) p.fertilizeNote,
                ],
                due: p.isFertilizeDue(now),
                button: 'Gedüngt',
                onDone: () => store.update('care', p.id, {
                  'lastFertilized': writeDate(today()),
                }),
              ),
            if (p.location.isNotEmpty)
              _InfoTile(Icons.place_outlined, 'Standort', p.location),
            if (p.light.isNotEmpty)
              _InfoTile(Icons.wb_sunny_outlined, 'Licht', p.light),
            if (p.since != null)
              _InfoTile(
                Icons.cake_outlined,
                'Bei uns seit',
                formatDate(p.since!, now: now),
              ),
            if (p.notes.isNotEmpty)
              _InfoTile(Icons.notes_outlined, 'Notizen', p.notes),
            const SectionHeader('Wachstum'),
            if (photos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Mach ab und zu ein Foto, dann siehst du hier, '
                  'wie die Pflanze wächst.',
                ),
              )
            else ...[
              if (photos.length >= 2)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text('Zeitraffer ansehen (${photos.length} Fotos)'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlantTimelapseScreen(
                          householdId: householdId,
                          plantId: plantId,
                        ),
                      ),
                    ),
                  ),
                ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = photos.length - 1; i >= 0; i--)
                    _PhotoThumb(
                      photo: photos[i],
                      label: formatShortDate(photos[i].takenAt),
                      onTap: () => _openPhoto(context, p, photos, i),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _addPhoto(
    BuildContext context,
    WidgetRef ref,
    CareItem plant,
    PlantPhoto? latest,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Aus der Galerie'),
              subtitle: const Text('Auch ältere Fotos, mit Datum'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(plantPhotoPickerProvider)(source);
    } catch (e) {
      if (context.mounted) showError(context, 'Foto ging nicht: $e');
      return;
    }
    if (bytes == null || !context.mounted) return;
    if (bytes.length > maxPhotoBytes) {
      return showError(context, 'Das Foto ist zu groß. Probier ein anderes.');
    }
    var takenAt = today();
    // Bei Galerie-Fotos fragen, wann sie entstanden sind (für den Zeitraffer).
    if (source == ImageSource.gallery) {
      final picked = await showDatePicker(
        context: context,
        helpText: 'Wann wurde das Foto gemacht?',
        initialDate: takenAt,
        firstDate: DateTime(2000),
        lastDate: takenAt,
      );
      if (picked == null) return;
      takenAt = picked;
    }
    await addPlantPhoto(
      ref.read(storeProvider(householdId)),
      plant,
      bytes,
      takenAt,
      latest: latest?.takenAt,
    );
  }

  void _openPhoto(
    BuildContext context,
    CareItem plant,
    List<PlantPhoto> photos,
    int index,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlantPhotoScreen(
        householdId: householdId,
        plantId: plant.id,
        initialPhotoId: photos[index].id,
      ),
    ),
  );
}

class _CareCard extends StatelessWidget {
  const _CareCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.due,
    required this.button,
    required this.onDone,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final bool due;
  final String button;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: due ? scheme.error : scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  for (final l in lines)
                    Text(
                      l,
                      style: l == 'Jetzt fällig'
                          ? TextStyle(color: scheme.error)
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            due
                ? FilledButton(onPressed: onDone, child: Text(button))
                : OutlinedButton(onPressed: onDone, child: Text(button)),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(value), subtitle: Text(label));
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.label,
    required this.onTap,
  });

  final PlantPhoto photo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            cacheWidth: 300,
            gaplessPlayback: true,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ein Foto groß, mit Wischen zum nächsten, Datum ändern und Löschen.
class PlantPhotoScreen extends ConsumerStatefulWidget {
  const PlantPhotoScreen({
    super.key,
    required this.householdId,
    required this.plantId,
    required this.initialPhotoId,
  });

  final String householdId;
  final String plantId;
  final String initialPhotoId;

  @override
  ConsumerState<PlantPhotoScreen> createState() => _PlantPhotoScreenState();
}

class _PlantPhotoScreenState extends ConsumerState<PlantPhotoScreen> {
  PageController? _pages;
  late String _currentId = widget.initialPhotoId;

  PlantKey get _key =>
      (householdId: widget.householdId, plantId: widget.plantId);

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(plantPhotosProvider(_key)).value ?? const [];
    final plant = ref.watch(_plantProvider(_key)).value;
    final index = photos.indexWhere((p) => p.id == _currentId);
    final current = index < 0 ? null : photos[index];
    _pages ??= PageController(initialPage: index < 0 ? 0 : index);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          current == null
              ? ''
              : '${formatDate(current.takenAt)} · '
                    '${growthText(photos.first.takenAt, current.takenAt)}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (current != null && plant != null) ...[
            IconButton(
              tooltip: 'Datum ändern',
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: current.takenAt,
                  firstDate: DateTime(2000),
                  lastDate: today(),
                );
                if (picked == null) return;
                final store = ref.read(storeProvider(widget.householdId));
                await store.update('plantPhotos', current.id, {
                  'takenAt': writeDate(picked),
                });
                // Neuestes Foto fürs Vorschaubild neu bestimmen.
                final moved = [
                  for (final p in photos)
                    p.id == current.id
                        ? PlantPhoto(
                            id: p.id,
                            plantId: p.plantId,
                            takenAt: picked,
                            bytes: p.bytes,
                          )
                        : p,
                ]..sort(byDate);
                if (moved.last.id != plant.photoId) {
                  await store.update('care', plant.id, {
                    'photoId': moved.last.id,
                  });
                }
              },
            ),
            IconButton(
              tooltip: 'Foto löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, 'Foto') || !mounted) return;
                final nav = Navigator.of(this.context);
                await deletePlantPhoto(
                  ref.read(storeProvider(widget.householdId)),
                  plant,
                  current,
                  photos,
                );
                nav.pop();
              },
            ),
          ],
        ],
      ),
      body: photos.isEmpty
          ? const SizedBox.shrink()
          : PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _currentId = photos[i].id),
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: Image.memory(photos[i].bytes, gaplessPlayback: true),
                ),
              ),
            ),
    );
  }
}

/// Spielt alle Fotos nacheinander ab, damit man das Wachstum sieht.
class PlantTimelapseScreen extends ConsumerStatefulWidget {
  const PlantTimelapseScreen({
    super.key,
    required this.householdId,
    required this.plantId,
  });

  final String householdId;
  final String plantId;

  @override
  ConsumerState<PlantTimelapseScreen> createState() =>
      _PlantTimelapseScreenState();
}

enum TimelapseSpeed {
  slow('Langsam', 1600),
  normal('Normal', 900),
  fast('Schnell', 400);

  const TimelapseSpeed(this.label, this.ms);
  final String label;
  final int ms;
}

class _PlantTimelapseScreenState extends ConsumerState<PlantTimelapseScreen> {
  Timer? _timer;
  int _index = 0;
  bool _playing = true;
  bool _compare = false;
  TimelapseSpeed _speed = TimelapseSpeed.normal;
  int _count = 0;

  PlantKey get _key =>
      (householdId: widget.householdId, plantId: widget.plantId);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (!_playing) return;
    _timer = Timer.periodic(Duration(milliseconds: _speed.ms), (_) {
      if (_count < 2) return;
      setState(() {
        // Am Ende kurz stehen bleiben und von vorn beginnen.
        _index = _index >= _count - 1 ? 0 : _index + 1;
      });
    });
  }

  void _toggle() => setState(() {
    _playing = !_playing;
    _restart();
  });

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(plantPhotosProvider(_key)).value ?? const [];
    final plant = ref.watch(_plantProvider(_key)).value;
    _count = photos.length;
    if (photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zeitraffer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final i = _index.clamp(0, photos.length - 1);
    final photo = photos[i];
    final first = photos.first;
    final fade = Duration(milliseconds: (_speed.ms * 0.45).round());

    Widget frame(PlantPhoto p) => Image.memory(
      p.bytes,
      key: ValueKey(p.id),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      cacheWidth: 1280,
    );

    Widget caption(String date, String text) => Column(
      children: [
        Text(
          date,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${plant?.name ?? ''} im Zeitraffer'),
        actions: [
          IconButton(
            tooltip: _compare ? 'Zeitraffer' : 'Vorher / Nachher',
            icon: Icon(_compare ? Icons.movie_outlined : Icons.compare),
            onPressed: () => setState(() => _compare = !_compare),
          ),
        ],
      ),
      body: SafeArea(
        child: _compare
            ? Column(
                children: [
                  for (final (label, p) in [
                    ('Vorher', first),
                    ('Nachher', photos.last),
                  ])
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: Center(child: frame(p))),
                          const SizedBox(height: 4),
                          caption(
                            '$label · ${formatShortDate(p.takenAt)}',
                            growthText(first.takenAt, p.takenAt),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggle,
                      child: AnimatedSwitcher(
                        duration: fade,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, ?current],
                        ),
                        child: frame(photo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  caption(
                    formatDate(photo.takenAt),
                    '${growthText(first.takenAt, photo.takenAt)} · '
                    'Foto ${i + 1} von ${photos.length}',
                  ),
                  Slider(
                    value: i.toDouble(),
                    max: (photos.length - 1).toDouble(),
                    divisions: photos.length > 1 ? photos.length - 1 : null,
                    onChanged: (v) => setState(() {
                      _index = v.round();
                      _playing = false;
                      _restart();
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        IconButton.filled(
                          tooltip: _playing ? 'Pause' : 'Abspielen',
                          iconSize: 32,
                          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                          onPressed: _toggle,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<TimelapseSpeed>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              foregroundColor: Colors.white,
                              selectedForegroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            segments: [
                              for (final s in TimelapseSpeed.values)
                                ButtonSegment(value: s, label: Text(s.label)),
                            ],
                            selected: {_speed},
                            onSelectionChanged: (s) => setState(() {
                              _speed = s.first;
                              _restart();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
