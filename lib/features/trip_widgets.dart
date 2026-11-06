import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:url_launcher/url_launcher.dart';

import '../data/offline.dart';
import '../data/store.dart';
import '../services/dish_image.dart';
import '../services/place_image.dart';
import '../services/weather.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/cute.dart';
import '../widgets/recipe_image.dart' show recipePhotoPickerProvider;
import 'contract_files.dart';
import 'trips.dart';

// ---------------------------------------------------------------------------
// Foto des Reiseziels

/// households/{id}/tripPhotos/{tripId}: das eigene Titelfoto einer Reise.
typedef TripKey = ({String householdId, String tripId});

final tripPhotoProvider = StreamProvider.family<Uint8List?, TripKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .doc('households/${key.householdId}/tripPhotos/${key.tripId}')
      .snapshots()
      .map(
        (s) => switch (s.data()?['image']) {
          Blob b when b.bytes.isNotEmpty => b.bytes,
          _ => null,
        },
      ),
);

/// Sucht ein Foto des Reiseziels. Im Test ersetzbar.
final placeImageFinderProvider =
    Provider<Future<DishImage?> Function(String name, String? place)>((ref) {
      final client = ref.watch(httpClientProvider);
      return (name, place) => fetchPlaceImage(client, name, place: place);
    });

/// Reisen, für die schon ein Foto gesucht wird (nicht doppelt suchen).
final _searching = <String>{};

/// Das Titelbild einer Reise: das eigene Foto, sonst das automatisch
/// gefundene, sonst ein grüner Verlauf mit Koffer. Fehlt das automatische
/// Foto noch, wird es beim ersten Anzeigen gesucht und gespeichert.
class TripImage extends ConsumerStatefulWidget {
  const TripImage({
    super.key,
    required this.householdId,
    required this.trip,
    this.editable = false,
  });

  final String householdId;
  final Trip trip;
  final bool editable;

  @override
  ConsumerState<TripImage> createState() => _TripImageState();
}

class _TripImageState extends ConsumerState<TripImage> {
  @override
  void initState() {
    super.initState();
    _findImage();
  }

  @override
  void didUpdateWidget(TripImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _findImage();
  }

  Future<void> _findImage() async {
    final trip = widget.trip;
    if (trip.imageUrl != null || trip.name.trim().isEmpty) return;
    final key =
        '${widget.householdId}/${trip.id}/${trip.name}/${trip.place?.name}';
    if (!_searching.add(key)) return;
    final find = ref.read(placeImageFinderProvider);
    final store = ref.read(storeProvider(widget.householdId));
    try {
      final image = await find(trip.name, trip.place?.name);
      await store.update('trips', trip.id, {
        'imageUrl': image?.url ?? '',
        'imagePage': image?.page ?? FieldValue.delete(),
      });
    } catch (_) {
      // Kein Netz: beim nächsten Anzeigen noch mal versuchen.
      _searching.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final photo = ref
        .watch(
          tripPhotoProvider((householdId: widget.householdId, tripId: trip.id)),
        )
        .value;
    final url = trip.imageUrl ?? '';
    final placeholder = TripPlaceholder(wish: trip.wish);
    final Widget image;
    if (photo != null) {
      image = Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, error, stack) => placeholder,
      );
    } else {
      image = placeholder;
    }
    final page = trip.imagePage;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (widget.editable && photo == null && url.isNotEmpty && page != null)
          Positioned(
            left: 8,
            top: 8,
            child: ImageBadge(
              label: 'Bild: Wikipedia',
              onTap: () => launchUrl(
                Uri.parse(page),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        if (widget.editable)
          Positioned(
            right: 8,
            top: 8,
            child: ImageBadge(
              icon: Icons.photo_camera_outlined,
              label: photo == null ? 'Eigenes Foto' : 'Foto ändern',
              onTap: () => _photoSheet(context, hasPhoto: photo != null),
            ),
          ),
      ],
    );
  }

  Future<void> _photoSheet(
    BuildContext context, {
    required bool hasPhoto,
  }) async {
    final store = ref.read(storeProvider(widget.householdId));
    final pick = ref.read(recipePhotoPickerProvider);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Aus der Galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Eigenes Foto entfernen'),
                subtitle: const Text('Dann kommt wieder das Foto vom Ort'),
                onTap: () => Navigator.of(context).pop(false),
              ),
          ],
        ),
      ),
    );
    final tripId = widget.trip.id;
    if (choice == false) return store.delete('tripPhotos', tripId);
    if (choice is! ImageSource) return;
    final Uint8List? bytes;
    try {
      bytes = await pick(choice);
    } catch (e) {
      if (context.mounted) showError(context, 'Kein Foto möglich: $e');
      return;
    }
    if (bytes == null) return;
    if (bytes.length > 900 * 1024) {
      if (context.mounted) showError(context, 'Das Foto ist zu groß.');
      return;
    }
    await writeInBackground(
      store.col('tripPhotos').doc(tripId).set({
        'image': Blob(bytes),
        'createdBy': store.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }
}

class ImageBadge extends StatelessWidget {
  const ImageBadge({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grüner Verlauf mit Koffer (oder Sternchen beim Wunschziel).
class TripPlaceholder extends StatelessWidget {
  const TripPlaceholder({super.key, this.wish = false});

  final bool wish;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: wish
              ? const [Color(0xFF43A047), Color(0xFF1B5E20)]
              : const [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              wish ? '💭' : '🧳',
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kachel in der Übersicht: Foto mit Name, darunter Datum und Fortschritt.
class TripTile extends StatelessWidget {
  const TripTile({
    super.key,
    required this.householdId,
    required this.trip,
    required this.today,
    required this.names,
    required this.onTap,
    this.big = false,
  });

  final String householdId;
  final Trip trip;
  final DateTime today;
  final Map<String, String> names;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countdown = tripCountdown(trip, today);
    final past = tripIsPast(trip, today);
    final packed = trip.packing.where((p) => p.done).length;
    final meta = [
      if (trip.wish)
        names[trip.createdBy] == null
            ? 'Wunschziel'
            : 'Idee von ${names[trip.createdBy]}'
      else
        tripDates(trip),
      if (big && trip.packing.isNotEmpty && !past)
        '$packed/${trip.packing.length} gepackt',
      if (big && trip.place != null) trip.place!.name.split(',').first,
    ].join(' · ');

    final image = Stack(
      fit: StackFit.expand,
      children: [
        TripImage(householdId: householdId, trip: trip),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.45, 1],
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Text(
            trip.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (big
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
          ),
        ),
        if (countdown != null)
          Positioned(right: 8, top: 8, child: _Chip(countdown)),
      ],
    );

    final framed = Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: ClipRRect(borderRadius: BorderRadius.circular(21), child: image),
    );
    return CuteBox(
      tone: trip.wish ? CuteTone.vanilla : CuteTone.pink,
      radius: 26,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (big)
            SizedBox(height: 176, child: framed)
          else
            Expanded(child: framed),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, big ? 12 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  maxLines: big ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (past && trip.rating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Stars(rating: trip.rating, size: 14),
                  ),
                if (big && trip.packing.isNotEmpty && !past) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: packed / trip.packing.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Fünf Sterne, [rating] davon gefüllt. Mit [onChanged] antippbar.
class Stars extends StatelessWidget {
  const Stars({
    super.key,
    required this.rating,
    this.size = 28,
    this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF9A825);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          onChanged == null
              ? Icon(
                  i <= rating ? Icons.star : Icons.star_border,
                  size: size,
                  color: color,
                )
              : IconButton(
                  tooltip: '$i Sterne',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    size: size,
                    color: color,
                  ),
                  // Noch mal auf denselben Stern: wieder ohne Sterne.
                  onPressed: () => onChanged!(i == rating ? 0 : i),
                ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Wetter am Reiseziel

/// Tagesvorhersage für 16 Tage an einem Ort (Open-Meteo).
final tripForecastProvider =
    FutureProvider.family<List<DayForecast>, ({double lat, double lng})>((
      ref,
      p,
    ) async {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${p.lat}',
        'longitude': '${p.lng}',
        'daily':
            'temperature_2m_max,temperature_2m_min,weather_code,'
            'precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '16',
      });
      final res = await ref.watch(httpClientProvider).get(uri);
      if (res.statusCode != 200) {
        throw Exception('Wetter nicht erreichbar (${res.statusCode})');
      }
      return parseDailyForecast(jsonDecode(res.body) as Map<String, dynamic>);
    });

List<DayForecast> parseDailyForecast(Map<String, dynamic> json) {
  final daily = json['daily'] as Map<String, dynamic>? ?? const {};
  final dates = (daily['time'] as List?)?.cast<String>() ?? const [];
  num? at(String key, int i) {
    final list = daily[key];
    return list is List && i < list.length ? list[i] as num? : null;
  }

  return [
    for (var i = 0; i < dates.length; i++)
      if (at('temperature_2m_max', i) != null)
        DayForecast(
          date: DateTime.parse(dates[i]),
          min: at('temperature_2m_min', i)!.toDouble(),
          max: at('temperature_2m_max', i)!.toDouble(),
          code: at('weather_code', i)?.toInt() ?? 0,
          rainChance: at('precipitation_probability_max', i)?.toInt() ?? 0,
        ),
  ];
}

/// Die vorhergesagten Tage, an denen ihr unterwegs seid (ab heute).
List<DayForecast> tripWeatherDays(
  Trip t,
  List<DayForecast> days,
  DateTime today,
) {
  if (t.wish || t.start == null) return const [];
  final from = dateOnly(t.start!).isBefore(dateOnly(today))
      ? dateOnly(today)
      : dateOnly(t.start!);
  final to = dateOnly(t.end ?? t.start!);
  return [
    for (final d in days)
      if (!dateOnly(d.date).isBefore(from) && !dateOnly(d.date).isAfter(to)) d,
  ];
}

/// Lohnt sich die Vorhersage? Nur, wenn die Reise in den nächsten zwei
/// Wochen beginnt oder gerade läuft und einen Ort hat.
bool tripHasForecast(Trip t, DateTime today) =>
    t.place != null &&
    !t.wish &&
    t.start != null &&
    !tripIsPast(t, today) &&
    daysBetween(today, t.start!) <= 15;

/// Eine Reihe Wetterkärtchen für die Reisetage.
class TripWeatherRow extends ConsumerWidget {
  const TripWeatherRow({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = today();
    if (!tripHasForecast(trip, t)) return const SizedBox.shrink();
    final place = trip.place!;
    final forecast = ref.watch(
      tripForecastProvider((lat: place.lat, lng: place.lng)),
    );
    final days = tripWeatherDays(trip, forecast.value ?? const [], t);
    if (days.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Wetter in ${place.name.split(',').first}'),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final d in days)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayShort(d.date),
                          style: theme.textTheme.labelMedium,
                        ),
                        Icon(
                          describeWeather(d.code).$2,
                          color: theme.colorScheme.primary,
                        ),
                        Text(
                          '${d.max.round()}° / ${d.min.round()}°',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (d.rainChance >= 30)
                          Text(
                            '${d.rainChance} % Regen',
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dateien: Tickets, Buchungen und Erinnerungsfotos

/// households/{id}/tripFiles: Dateien zu einer Reise, je Datei ein
/// Dokument (höchstens knapp 1 MB). [kind] ist 'doc' für Unterlagen wie
/// Tickets und Buchungen oder 'memory' für Fotos nach der Reise.
class TripFile {
  const TripFile({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.name,
    required this.mime,
    required this.addedAt,
    required this.bytes,
  });

  final String id;
  final String tripId;
  final String kind;
  final String name;
  final String mime;
  final DateTime addedAt;
  final Uint8List bytes;

  bool get isImage => mime.startsWith('image/');

  factory TripFile.fromDoc(Doc d) => TripFile(
    id: d.id,
    tripId: d.data['tripId'] as String? ?? '',
    kind: d.data['kind'] as String? ?? 'doc',
    name: d.data['name'] as String? ?? 'Datei',
    mime: d.data['mime'] as String? ?? 'application/octet-stream',
    addedAt: readDate(d.data['addedAt']) ?? today(),
    bytes: switch (d.data['data']) {
      Blob b => b.bytes,
      _ => Uint8List(0),
    },
  );
}

final tripFilesProvider = StreamProvider.family<List<TripFile>, TripKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .collection('households/${key.householdId}/tripFiles')
      .where('tripId', isEqualTo: key.tripId)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) TripFile.fromDoc(Doc(d.id, d.data()))]
              ..sort((a, b) => a.addedAt.compareTo(b.addedAt)),
      ),
);

Future<void> addTripFile(
  HouseholdStore store,
  String tripId,
  String kind,
  PickedFile file,
) => writeInBackground(
  store.col('tripFiles').doc().set({
    'tripId': tripId,
    'kind': kind,
    'name': file.name,
    'mime': file.mime,
    'addedAt': writeDate(today()),
    'data': Blob(file.bytes),
    'createdBy': store.uid,
    'createdAt': FieldValue.serverTimestamp(),
  }),
);

/// Beim Löschen einer Reise verschwinden auch ihre Dateien.
Future<void> deleteTripFiles(HouseholdStore store, String tripId) async {
  final docs = await store
      .col('tripFiles')
      .where('tripId', isEqualTo: tripId)
      .get();
  for (final d in docs.docs) {
    await store.delete('tripFiles', d.id);
  }
}

/// Tickets und Buchungen als Liste.
class TripDocumentsSection extends ConsumerWidget {
  const TripDocumentsSection({
    super.key,
    required this.householdId,
    required this.tripId,
  });

  final String householdId;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = [
      for (final f
          in ref
                  .watch(
                    tripFilesProvider((
                      householdId: householdId,
                      tripId: tripId,
                    )),
                  )
                  .value ??
              const <TripFile>[])
        if (f.kind == 'doc') f,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (files.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Tickets, Buchungen, Reservierungen als PDF oder Foto'),
          ),
        for (final f in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: f.isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      f.bytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    ),
                  )
                : Icon(
                    f.mime == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
            title: Text(f.name, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Datei löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, f.name)) return;
                await ref
                    .read(storeProvider(householdId))
                    .delete('tripFiles', f.id);
              },
            ),
            onTap: () => openAttachment(
              context,
              bytes: f.bytes,
              name: f.name,
              mime: f.mime,
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: const Text('Ticket oder Buchung anhängen'),
          onPressed: () async {
            final file = await pickAttachment(context, ref);
            if (file == null) return;
            await addTripFile(
              ref.read(storeProvider(householdId)),
              tripId,
              'doc',
              file,
            );
          },
        ),
      ],
    );
  }
}

/// Fotos nach der Reise als Raster.
class TripMemoryPhotos extends ConsumerWidget {
  const TripMemoryPhotos({
    super.key,
    required this.householdId,
    required this.tripId,
  });

  final String householdId;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [
      for (final f
          in ref
                  .watch(
                    tripFilesProvider((
                      householdId: householdId,
                      tripId: tripId,
                    )),
                  )
                  .value ??
              const <TripFile>[])
        if (f.kind == 'memory' && f.isImage) f,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty)
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final f in photos)
                GestureDetector(
                  onTap: () => openAttachment(
                    context,
                    bytes: f.bytes,
                    name: f.name,
                    mime: f.mime,
                  ),
                  onLongPress: () async {
                    if (!await confirmDelete(context, 'dieses Foto')) return;
                    await ref
                        .read(storeProvider(householdId))
                        .delete('tripFiles', f.id);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      f.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Foto hinzufügen'),
          onPressed: () async {
            final file = await pickAttachment(context, ref, photosOnly: true);
            if (file == null) return;
            await addTripFile(
              ref.read(storeProvider(householdId)),
              tripId,
              'memory',
              file,
            );
          },
        ),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Lange drücken zum Löschen',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Öffnet eine Kartensuche (Google Maps, sonst Browser).
Future<void> openMap(String query) => launchUrl(
  Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
  mode: LaunchMode.externalApplication,
);
