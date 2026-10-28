import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/store.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

/// Standort teilen ist freiwillig und für jede Person getrennt:
/// users/{uid}.shareLocation schaltet es ein oder aus (Standard: aus),
/// households/{id}/locations/{uid} enthält die letzte Position.
/// Geteilt wird nur, solange die App geöffnet ist.

final shareLocationProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid.isEmpty) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.data()?['shareLocation'] as bool? ?? false);
});

class SharedLocation {
  const SharedLocation({
    required this.uid,
    required this.point,
    required this.updatedAt,
  });

  final String uid;
  final LatLng point;
  final DateTime? updatedAt;

  factory SharedLocation.fromDoc(Doc d) => SharedLocation(
    uid: d.id,
    point: LatLng(
      (d.data['lat'] as num?)?.toDouble() ?? 0,
      (d.data['lng'] as num?)?.toDouble() ?? 0,
    ),
    updatedAt: (d.data['updatedAt'] as Timestamp?)?.toDate(),
  );
}

final locationsProvider =
    Provider.family<AsyncValue<List<SharedLocation>>, String>(
      (ref, householdId) => ref
          .watch(
            collectionProvider((
              householdId: householdId,
              collection: 'locations',
            )),
          )
          .whenData((docs) => docs.map(SharedLocation.fromDoc).toList()),
    );

String agoText(DateTime? t, {DateTime? now}) {
  if (t == null) return 'gerade eben';
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  return 'vor ${diff.inDays} ${diff.inDays == 1 ? 'Tag' : 'Tagen'}';
}

/// Fragt die Berechtigung an. Gibt eine Fehlermeldung zurück oder null.
Future<String?> ensureLocationPermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return 'Bitte schalte die Standortdienste auf dem Handy ein.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'Ohne Standort-Berechtigung kann die App deinen Standort nicht teilen.';
  }
  return null;
}

Future<void> setShareLocation(
  WidgetRef ref,
  String householdId,
  bool share,
) async {
  final uid = ref.read(uidProvider);
  final db = ref.read(firestoreProvider);
  await db.doc('users/$uid').set({
    'shareLocation': share,
  }, SetOptions(merge: true));
  if (!share) {
    await ref.read(storeProvider(householdId)).delete('locations', uid);
  }
}

/// Läuft unsichtbar im Hintergrund der geöffneten App und schreibt die eigene
/// Position, solange Teilen eingeschaltet ist. Zeigt dann einen Hinweis-Balken.
class LocationSharer extends ConsumerStatefulWidget {
  const LocationSharer({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<LocationSharer> createState() => _LocationSharerState();
}

class _LocationSharerState extends ConsumerState<LocationSharer> {
  StreamSubscription<Position>? _sub;
  DateTime? _lastWrite;
  bool _starting = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_sub != null || _starting) return;
    _starting = true;
    final error = await ensureLocationPermission();
    _starting = false;
    if (error != null || !mounted || _sub != null) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(_write, onError: (_) {});
    // Sofort eine erste Position schicken, nicht erst nach 30 Metern.
    try {
      _write(await Geolocator.getCurrentPosition(), force: true);
    } catch (_) {}
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _write(Position p, {bool force = false}) {
    final now = DateTime.now();
    // Höchstens alle 20 Sekunden schreiben, um Akku und Kontingent zu schonen.
    if (!force &&
        _lastWrite != null &&
        now.difference(_lastWrite!).inSeconds < 20) {
      return;
    }
    _lastWrite = now;
    final store = ref.read(storeProvider(widget.householdId));
    store.set('locations', store.uid, {
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final sharing = ref.watch(shareLocationProvider).value ?? false;
    // Start/Stopp nach dem Zeichnen, nicht mitten im build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sharing ? _start() : _stop();
    });
    if (!sharing) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationScreen(householdId: widget.householdId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.my_location,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Du teilst gerade deinen Standort',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setShareLocation(ref, widget.householdId, false),
                child: const Text('Aus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(shareLocationProvider).value ?? false;
    final locations = ref.watch(locationsProvider(householdId));
    final names = memberNames(ref, householdId);
    final uid = ref.watch(uidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wo seid ihr?')),
      body: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.my_location),
            title: const Text('Meinen Standort teilen'),
            subtitle: const Text(
              'Nur ihr zwei seht ihn, und nur solange die App bei dir offen ist. '
              'Du kannst es jederzeit wieder ausschalten.',
            ),
            value: sharing,
            onChanged: (v) async {
              if (v) {
                final error = await ensureLocationPermission();
                if (error != null) {
                  if (context.mounted) showError(context, error);
                  return;
                }
              }
              await setShareLocation(ref, householdId, v);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: asyncBody(locations, (list) {
              if (list.isEmpty) {
                return const EmptyHint(
                  icon: Icons.location_off_outlined,
                  mood: MascotMood.love,
                  text: 'Gerade teilt niemand seinen Standort.',
                );
              }
              final center = list.first.point;
              return Column(
                children: [
                  for (final l in list)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_pin_circle),
                      title: Text(l.uid == uid ? 'Du' : names[l.uid] ?? '?'),
                      trailing: Text(agoText(l.updatedAt)),
                    ),
                  Expanded(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'de.bubududu.bubududu',
                        ),
                        MarkerLayer(
                          markers: [
                            for (final l in list)
                              Marker(
                                point: l.point,
                                width: 120,
                                height: 64,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        l.uid == uid
                                            ? 'Du'
                                            : names[l.uid] ?? '?',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.location_on,
                                      size: 36,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution('OpenStreetMap-Mitwirkende'),
                          ],
                        ),
                      ],
                    ),
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
