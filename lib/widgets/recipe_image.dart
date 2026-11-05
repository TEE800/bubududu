import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/offline.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/dish_image.dart';
import '../services/weather.dart' show httpClientProvider;
import 'common.dart';

/// households/{id}/recipePhotos/{recipeId}: das eigene Foto eines Gerichts.
/// Gibt es keins, zeigt das Kochbuch das automatisch gefundene Bild.
typedef RecipePhotoKey = ({String householdId, String recipeId});

final recipePhotoProvider = StreamProvider.family<Uint8List?, RecipePhotoKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .doc('households/${key.householdId}/recipePhotos/${key.recipeId}')
      .snapshots()
      .map(
        (s) => switch (s.data()?['image']) {
          Blob b when b.bytes.isNotEmpty => b.bytes,
          _ => null,
        },
      ),
);

/// Wählt ein eigenes Foto aus, schon klein gerechnet. Im Test ersetzbar.
final recipePhotoPickerProvider =
    Provider<Future<Uint8List?> Function(ImageSource source)>(
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

/// Sucht ein Bild zu einem Gericht. Im Test ersetzbar.
final dishImageFinderProvider =
    Provider<Future<DishImage?> Function(String title)>((ref) {
      final client = ref.watch(httpClientProvider);
      return (title) => fetchDishImage(client, title);
    });

/// Rezepte, für die schon ein Bild gesucht wurde (nicht doppelt suchen,
/// auch nicht, solange das Ergebnis noch nicht zurück im Rezept ist).
final _searching = <String>{};

/// Das Bild eines Rezepts im Kochbuch: das eigene Foto, sonst das
/// automatisch gefundene, sonst eine Zeichnung. Fehlt das automatische Bild
/// noch, wird es beim ersten Anzeigen gesucht und für beide gespeichert.
class RecipeImage extends ConsumerStatefulWidget {
  const RecipeImage({
    super.key,
    required this.householdId,
    required this.recipe,
    this.editable = true,
  });

  final String householdId;
  final Recipe recipe;
  final bool editable;

  @override
  ConsumerState<RecipeImage> createState() => _RecipeImageState();
}

class _RecipeImageState extends ConsumerState<RecipeImage> {
  @override
  void initState() {
    super.initState();
    _findImage();
  }

  @override
  void didUpdateWidget(RecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _findImage();
  }

  Future<void> _findImage() async {
    final recipe = widget.recipe;
    if (recipe.imageUrl != null || recipe.title.trim().isEmpty) return;
    final key = '${widget.householdId}/${recipe.id}/${recipe.title}';
    if (!_searching.add(key)) return;
    final find = ref.read(dishImageFinderProvider);
    final repo = ref.read(householdRepositoryProvider);
    try {
      final image = await find(recipe.title);
      await repo.setRecipeImage(
        widget.householdId,
        recipe.id,
        url: image?.url ?? '',
        page: image?.page,
      );
    } catch (_) {
      // Kein Netz: beim nächsten Anzeigen noch mal versuchen.
      _searching.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final photo = ref
        .watch(
          recipePhotoProvider((
            householdId: widget.householdId,
            recipeId: recipe.id,
          )),
        )
        .value;
    final url = recipe.imageUrl ?? '';
    final Widget image;
    if (photo != null) {
      image = Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const DishPlaceholder(),
        errorBuilder: (context, error, stack) => const DishPlaceholder(),
      );
    } else {
      image = DishPlaceholder(searching: recipe.imageUrl == null);
    }
    final page = recipe.imagePage;

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (widget.editable && photo == null && url.isNotEmpty && page != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: _Badge(
              label: 'Bild: Wikipedia',
              onTap: () => launchUrl(
                Uri.parse(page),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        if (widget.editable)
          Positioned(
            right: 6,
            bottom: 6,
            child: _Badge(
              icon: Icons.photo_camera_outlined,
              label: photo == null ? 'Eigenes Foto' : 'Foto ändern',
              onTap: () => showRecipePhotoSheet(
                context,
                ref,
                householdId: widget.householdId,
                recipe: recipe,
                hasPhoto: photo != null,
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

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

/// Gezeichneter Teller, solange es kein Bild gibt.
class DishPlaceholder extends StatelessWidget {
  const DishPlaceholder({super.key, this.searching = false});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
      ),
      child: Center(
        // Passt auch in kleine Kacheln.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 56)),
                if (searching) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Bild wird gesucht …',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> saveRecipePhoto(
  HouseholdStore store,
  String recipeId,
  Uint8List bytes,
) => writeInBackground(
  store.col('recipePhotos').doc(recipeId).set({
    'image': Blob(bytes),
    'createdBy': store.uid,
    'createdAt': FieldValue.serverTimestamp(),
  }),
);

/// Kamera / Galerie / eigenes Foto entfernen für das Rezept [recipe].
Future<void> showRecipePhotoSheet(
  BuildContext context,
  WidgetRef ref, {
  required String householdId,
  required Recipe recipe,
  required bool hasPhoto,
}) async {
  final store = ref.read(storeProvider(householdId));
  final pick = ref.read(recipePhotoPickerProvider);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Foto für „${recipe.title}“',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
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
              subtitle: const Text('Dann wird wieder ein Bild gesucht'),
              onTap: () => Navigator.of(context).pop(false),
            ),
        ],
      ),
    ),
  );
  if (choice == false) return store.delete('recipePhotos', recipe.id);
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
  await saveRecipePhoto(store, recipe.id, bytes);
}
