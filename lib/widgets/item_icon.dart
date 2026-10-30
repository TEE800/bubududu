import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/offline.dart';
import '../data/store.dart';
import 'common.dart';

/// Stichworte → Symbol. Das erste passende gewinnt, deshalb stehen
/// zusammengesetzte Wörter (Erdnussbutter, Hafermilch) vor ihren Teilen.
const _symbols = <(List<String>, String)>[
  (['erdnussbutter'], '🥜'),
  (['salzstangen', 'salzbrezel'], '🥨'),
  (['eistee'], '🧃'),
  (['olivenöl', 'sonnenblumenöl', 'rapsöl', 'speiseöl'], '🫒'),
  (['speiseeis', 'vanilleeis', 'eiscreme'], '🍦'),
  (['hafermilch', 'sojamilch', 'mandelmilch'], '🥛'),
  (['kokosmilch'], '🥥'),
  (['zahnpasta', 'zahnbürste', 'zahnseide', 'mundspülung'], '🪥'),
  (
    [
      'klopapier',
      'toilettenpapier',
      'küchenrolle',
      'küchenpapier',
      'taschentücher',
      'zewa',
    ],
    '🧻',
  ),
  (
    [
      'spülmittel',
      'waschmittel',
      'weichspüler',
      'reiniger',
      'putzmittel',
      'spültabs',
      'tabs',
      'entkalker',
      'wc-',
    ],
    '🧴',
  ),
  (
    [
      'shampoo',
      'duschgel',
      'seife',
      'creme',
      'lotion',
      'deo',
      'sonnencreme',
      'spülung',
    ],
    '🧴',
  ),
  (['schwamm', 'lappen', 'tücher'], '🧽'),
  (['müllbeutel', 'müllsack', 'mülltüten'], '🗑️'),
  (['batterie', 'akku'], '🔋'),
  (['glühbirne', 'lampe', 'leuchtmittel'], '💡'),
  (
    [
      'tablette',
      'medikament',
      'ibuprofen',
      'paracetamol',
      'vitamin',
      'pflaster',
    ],
    '💊',
  ),
  (['windel'], '👶'),
  (['katzenfutter', 'katzenstreu'], '🐈'),
  (['hundefutter', 'leckerli'], '🐕'),
  (['blumenerde', 'dünger', 'blumen'], '🪴'),
  (['milch', 'sahne', 'buttermilch'], '🥛'),
  (
    [
      'käse',
      'gouda',
      'mozzarella',
      'parmesan',
      'feta',
      'camembert',
      'emmentaler',
    ],
    '🧀',
  ),
  (['butter', 'margarine'], '🧈'),
  (['joghurt', 'quark', 'skyr', 'pudding'], '🥣'),
  (['ei', 'eier'], '🥚'),
  (['brötchen', 'croissant', 'baguette', 'brezel', 'toast', 'brot'], '🍞'),
  (['müsli', 'haferflocken', 'cornflakes', 'flocken'], '🥣'),
  (
    [
      'nudeln',
      'spaghetti',
      'pasta',
      'penne',
      'lasagne',
      'tortellini',
      'spätzle',
    ],
    '🍝',
  ),
  (['reis'], '🍚'),
  (['mehl', 'zucker', 'backpulver', 'hefe', 'salz'], '🧂'),
  (['pfeffer', 'gewürz', 'paprikapulver', 'oregano', 'zimt', 'curry'], '🧂'),
  (['öl', 'essig'], '🫒'),
  (['honig'], '🍯'),
  (['marmelade', 'konfitüre', 'nutella', 'aufstrich'], '🍯'),
  (['ketchup', 'senf', 'mayo', 'soße', 'sauce', 'pesto'], '🥫'),
  (
    [
      'dose',
      'tomatenmark',
      'passata',
      'mais',
      'bohnen',
      'linsen',
      'kichererbsen',
      'suppe',
    ],
    '🥫',
  ),
  (['kaffee', 'espresso'], '☕'),
  (['tee'], '🍵'),
  (['wasser', 'sprudel'], '💧'),
  (['saft', 'limo', 'cola', 'eistee', 'smoothie'], '🧃'),
  (['bier'], '🍺'),
  (['wein', 'sekt', 'prosecco'], '🍷'),
  (['schokolade', 'schoko'], '🍫'),
  (['chips', 'flips', 'snack', 'cracker', 'salzstangen'], '🍿'),
  (['keks', 'kekse', 'kuchen', 'waffel'], '🍪'),
  (['eis'], '🍦'),
  (['pizza'], '🍕'),
  (['hähnchen', 'huhn', 'hühnchen', 'pute', 'chicken'], '🍗'),
  (
    ['hack', 'rind', 'steak', 'schwein', 'fleisch', 'gulasch', 'schnitzel'],
    '🥩',
  ),
  (
    [
      'wurst',
      'salami',
      'schinken',
      'würstchen',
      'aufschnitt',
      'speck',
      'bacon',
    ],
    '🥓',
  ),
  (['fisch', 'lachs', 'thunfisch', 'garnelen', 'shrimps'], '🐟'),
  (['tofu', 'tempeh'], '🧊'),
  (['apfel', 'äpfel'], '🍎'),
  (['birne'], '🍐'),
  (['banane'], '🍌'),
  (['zitrone', 'limette'], '🍋'),
  (['orange', 'mandarine', 'clementine'], '🍊'),
  (['erdbeere'], '🍓'),
  (['heidelbeere', 'blaubeere', 'beeren', 'himbeere'], '🫐'),
  (['traube', 'trauben'], '🍇'),
  (['melone'], '🍉'),
  (['kiwi'], '🥝'),
  (['ananas'], '🍍'),
  (['mango'], '🥭'),
  (['pfirsich', 'nektarine', 'aprikose'], '🍑'),
  (['kirsche'], '🍒'),
  (['avocado'], '🥑'),
  (['tomate'], '🍅'),
  (['kartoffel', 'pommes'], '🥔'),
  (['karotte', 'möhre', 'möhren'], '🥕'),
  (['gurke', 'zucchini'], '🥒'),
  (['paprika', 'chili', 'peperoni'], '🫑'),
  (['zwiebel', 'lauch', 'frühlingszwiebel'], '🧅'),
  (['knoblauch'], '🧄'),
  (['brokkoli', 'blumenkohl'], '🥦'),
  (
    ['salat', 'spinat', 'rucola', 'kohl', 'kräuter', 'petersilie', 'basilikum'],
    '🥬',
  ),
  (['pilz', 'champignon'], '🍄'),
  (['aubergine'], '🍆'),
  (['nüsse', 'nuss', 'mandeln', 'cashew', 'erdnüsse'], '🥜'),
  (['obst'], '🍎'),
  (['gemüse'], '🥦'),
];

/// Symbol (Emoji) zu einem Artikelnamen, z. B. „2 Liter Milch“ → 🥛.
/// Kurze Stichworte (bis 3 Buchstaben) müssen ein ganzes Wort sein,
/// damit „Eis“ nicht in „Reis“ oder „Ei“ nicht in „Eimer“ gefunden wird.
String itemSymbol(String name) {
  final text = name.toLowerCase();
  final words = text.split(RegExp(r'[^a-zäöüß-]+'));
  for (final (keys, symbol) in _symbols) {
    for (final k in keys) {
      if (k.length <= 3 ? words.contains(k) : text.contains(k)) return symbol;
    }
  }
  return '🛒';
}

/// households/{id}/itemPhotos/{key}: ein Produktfoto je Artikelname, gemeinsam
/// für Einkaufsliste und Vorräte. So taucht das Foto der Milch jede Woche
/// wieder auf, egal ob sie gerade auf der Liste oder im Vorrat steht.
String itemPhotoKey(String name) {
  final key = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('/', '-');
  return key.isEmpty || key == '.' || key == '..' ? '_' : key;
}

typedef ItemPhotoKey = ({String householdId, String name});

final itemPhotoProvider = StreamProvider.family<Uint8List?, ItemPhotoKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .doc('households/${key.householdId}/itemPhotos/${itemPhotoKey(key.name)}')
      .snapshots()
      .map(
        (s) => switch (s.data()?['image']) {
          Blob b when b.bytes.isNotEmpty => b.bytes,
          _ => null,
        },
      ),
);

/// Wählt ein Produktfoto aus, schon klein gerechnet. Im Test ersetzbar.
final itemPhotoPickerProvider =
    Provider<Future<Uint8List?> Function(ImageSource source)>(
      (ref) => (source) async {
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 70,
        );
        return image?.readAsBytes();
      },
    );

Future<void> saveItemPhoto(
  HouseholdStore store,
  String name,
  Uint8List bytes,
) => writeInBackground(
  store.col('itemPhotos').doc(itemPhotoKey(name)).set({
    'name': name.trim(),
    'image': Blob(bytes),
    'createdBy': store.uid,
    'createdAt': FieldValue.serverTimestamp(),
  }),
);

Future<void> deleteItemPhoto(HouseholdStore store, String name) =>
    store.delete('itemPhotos', itemPhotoKey(name));

/// Produktfoto, sonst das passende Symbol. Antippen ([editable]) öffnet die
/// Auswahl Kamera / Galerie / Foto entfernen.
class ItemAvatar extends ConsumerWidget {
  const ItemAvatar({
    super.key,
    required this.householdId,
    required this.name,
    this.size = 40,
    this.editable = true,
  });

  final String householdId;
  final String name;
  final double size;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref
        .watch(itemPhotoProvider((householdId: householdId, name: name)))
        .value;
    final scheme = Theme.of(context).colorScheme;
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox.square(
        dimension: size,
        child: photo != null
            ? Image.memory(
                photo,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: (size * 3).round(),
              )
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    itemSymbol(name),
                    style: TextStyle(fontSize: size * 0.55),
                  ),
                ),
              ),
      ),
    );
    if (!editable) return avatar;
    return Tooltip(
      message: 'Produktfoto',
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 4),
        onTap: () => showItemPhotoSheet(
          context,
          ref,
          householdId: householdId,
          name: name,
          hasPhoto: photo != null,
        ),
        child: avatar,
      ),
    );
  }
}

/// Kamera / Galerie / Foto entfernen für den Artikel [name].
Future<void> showItemPhotoSheet(
  BuildContext context,
  WidgetRef ref, {
  required String householdId,
  required String name,
  required bool hasPhoto,
}) async {
  if (name.trim().isEmpty) {
    return showError(context, 'Bitte gib zuerst einen Namen ein.');
  }
  final store = ref.read(storeProvider(householdId));
  final pick = ref.read(itemPhotoPickerProvider);
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
              'Produktfoto für „${name.trim()}“',
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
              title: const Text('Foto entfernen, Symbol zeigen'),
              onTap: () => Navigator.of(context).pop(false),
            ),
        ],
      ),
    ),
  );
  if (choice == false) return deleteItemPhoto(store, name);
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
  await saveItemPhoto(store, name, bytes);
}
