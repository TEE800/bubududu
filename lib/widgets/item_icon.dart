import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/offline.dart';
import '../data/store.dart';
import '../services/product_image.dart';
import '../services/weather.dart' show httpClientProvider;
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

/// Produktgruppen, in der Reihenfolge eines typischen Einkaufs.
enum ProductGroup {
  fruitVeg('Obst & Gemüse'),
  bakery('Brot & Frühstück'),
  dairy('Milch, Käse & Eier'),
  meatFish('Fleisch & Fisch'),
  pantry('Nudeln, Reis & Konserven'),
  frozen('Tiefkühl'),
  sweets('Süßes & Snacks'),
  drinks('Getränke'),
  household('Haushalt'),
  care('Drogerie & Gesundheit'),
  petsPlants('Tiere & Pflanzen'),
  other('Sonstiges');

  const ProductGroup(this.label);
  final String label;
}

const _groupBySymbol = {
  '🥜': ProductGroup.sweets,
  '🥨': ProductGroup.sweets,
  '🧃': ProductGroup.drinks,
  '🫒': ProductGroup.pantry,
  '🍦': ProductGroup.frozen,
  '🥛': ProductGroup.dairy,
  '🥥': ProductGroup.pantry,
  '🪥': ProductGroup.care,
  '🧻': ProductGroup.household,
  '🧴': ProductGroup.care,
  '🧽': ProductGroup.household,
  '🗑️': ProductGroup.household,
  '🔋': ProductGroup.household,
  '💡': ProductGroup.household,
  '💊': ProductGroup.care,
  '👶': ProductGroup.care,
  '🐈': ProductGroup.petsPlants,
  '🐕': ProductGroup.petsPlants,
  '🪴': ProductGroup.petsPlants,
  '🧀': ProductGroup.dairy,
  '🧈': ProductGroup.dairy,
  '🥣': ProductGroup.dairy,
  '🥚': ProductGroup.dairy,
  '🍞': ProductGroup.bakery,
  '🍝': ProductGroup.pantry,
  '🍚': ProductGroup.pantry,
  '🧂': ProductGroup.pantry,
  '🍯': ProductGroup.bakery,
  '🥫': ProductGroup.pantry,
  '☕': ProductGroup.drinks,
  '🍵': ProductGroup.drinks,
  '💧': ProductGroup.drinks,
  '🍺': ProductGroup.drinks,
  '🍷': ProductGroup.drinks,
  '🍫': ProductGroup.sweets,
  '🍿': ProductGroup.sweets,
  '🍪': ProductGroup.sweets,
  '🍕': ProductGroup.frozen,
  '🍗': ProductGroup.meatFish,
  '🥩': ProductGroup.meatFish,
  '🥓': ProductGroup.meatFish,
  '🐟': ProductGroup.meatFish,
  '🧊': ProductGroup.dairy,
};

/// Wo das Symbol allein nicht reicht (gleiches Symbol, andere Gruppe),
/// entscheidet das erste Stichwort der Zeile.
const _groupByFirstKey = {
  'spülmittel': ProductGroup.household,
  'müsli': ProductGroup.bakery,
  'erdnussbutter': ProductGroup.bakery,
  'hafermilch': ProductGroup.drinks,
};

(List<String>, String)? _match(String name) {
  final text = name.toLowerCase();
  final words = text.split(RegExp(r'[^a-zäöüß-]+'));
  for (final entry in _symbols) {
    for (final k in entry.$1) {
      if (k.length <= 3 ? words.contains(k) : text.contains(k)) return entry;
    }
  }
  return null;
}

/// Das Stichwort, an dem ein Artikel erkannt wurde, z. B. „milch“ in
/// „Bio-Vollmilch“. Hilft bei der Bildsuche. Nichts erkannt: null.
String? itemKeyword(String name) {
  final text = name.toLowerCase();
  final words = text.split(RegExp(r'[^a-zäöüß-]+'));
  for (final entry in _symbols) {
    for (final k in entry.$1) {
      if (k.length <= 3 ? words.contains(k) : text.contains(k)) {
        return k.endsWith('-') ? null : k;
      }
    }
  }
  return null;
}

/// Symbol (Emoji) zu einem Artikelnamen, z. B. „2 Liter Milch“ → 🥛.
/// Kurze Stichworte (bis 3 Buchstaben) müssen ein ganzes Wort sein,
/// damit „Eis“ nicht in „Reis“ oder „Ei“ nicht in „Eimer“ gefunden wird.
String itemSymbol(String name) => _match(name)?.$2 ?? '🛒';

/// Produktgruppe zu einem Artikelnamen; Obst und Gemüse sind alles, was
/// nicht anders eingeordnet ist und ein Obst- oder Gemüse-Symbol hat.
ProductGroup itemGroup(String name) {
  final entry = _match(name);
  if (entry == null) return ProductGroup.other;
  return _groupByFirstKey[entry.$1.first] ??
      _groupBySymbol[entry.$2] ??
      ProductGroup.fruitVeg;
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
  ItemImageInfo? autoImage,
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
              title: Text(
                autoImage == null
                    ? 'Foto entfernen, Symbol zeigen'
                    : 'Eigenes Foto entfernen',
              ),
              onTap: () => Navigator.of(context).pop(false),
            ),
          if (!hasPhoto && autoImage != null && autoImage.shows)
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Passt nicht, lieber Symbol zeigen'),
              onTap: () => Navigator.of(context).pop(#hideAuto),
            ),
          if (!hasPhoto && autoImage != null && !autoImage.shows)
            ListTile(
              leading: const Icon(Icons.image_search),
              title: const Text('Bild automatisch suchen'),
              onTap: () => Navigator.of(context).pop(#searchAuto),
            ),
          if (!hasPhoto &&
              autoImage != null &&
              autoImage.shows &&
              autoImage.page != null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Bildquelle: Wikipedia'),
              onTap: () =>
                  Navigator.of(context).pop(Uri.parse(autoImage.page!)),
            ),
        ],
      ),
    ),
  );
  if (choice == false) return deleteItemPhoto(store, name);
  final autoDoc = store.col('itemImages').doc(itemPhotoKey(name));
  if (choice == #hideAuto) {
    return writeInBackground(autoDoc.update({'hidden': true}));
  }
  if (choice == #searchAuto) {
    _searching.remove('$householdId/${itemPhotoKey(name)}');
    return writeInBackground(autoDoc.delete());
  }
  if (choice is Uri) {
    await launchUrl(choice, mode: LaunchMode.externalApplication);
    return;
  }
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

/// households/{id}/itemImages/{key}: das automatisch gefundene Bild je
/// Artikelname. [url] '' heißt: gesucht, nichts gefunden, oder [hidden]
/// (ausgeblendet, weil es nicht passte).
class ItemImageInfo {
  const ItemImageInfo({required this.url, this.page, this.hidden = false});

  final String url;
  final String? page;
  final bool hidden;

  bool get shows => url.isNotEmpty && !hidden;
}

/// null: für diesen Namen wurde noch nicht gesucht.
final itemImageProvider = StreamProvider.family<ItemImageInfo?, ItemPhotoKey>(
  (ref, key) => ref
      .watch(firestoreProvider)
      .doc('households/${key.householdId}/itemImages/${itemPhotoKey(key.name)}')
      .snapshots()
      .map((s) {
        final d = s.data();
        if (d == null) return null;
        return ItemImageInfo(
          url: d['url'] as String? ?? '',
          page: d['page'] as String?,
          hidden: d['hidden'] == true,
        );
      }),
);

/// Sucht ein Bild zu einem Produkt. Im Test ersetzbar.
final productImageFinderProvider =
    Provider<Future<ProductImage?> Function(String name)>((ref) {
      final client = ref.watch(httpClientProvider);
      return (name) =>
          fetchProductImage(client, name, keyword: itemKeyword(name));
    });

/// Namen, für die schon gesucht wird (nicht doppelt suchen, auch nicht,
/// solange das Ergebnis noch nicht zurück in Firestore ist).
final _searching = <String>{};

Future<void> _findItemImage(
  WidgetRef ref,
  String householdId,
  String name,
) async {
  final key = '$householdId/${itemPhotoKey(name)}';
  if (name.trim().isEmpty || !_searching.add(key)) return;
  final find = ref.read(productImageFinderProvider);
  final store = ref.read(storeProvider(householdId));
  try {
    final image = await find(name);
    await writeInBackground(
      store.col('itemImages').doc(itemPhotoKey(name)).set({
        'name': name.trim(),
        'url': image?.url ?? '',
        'page': image?.page,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  } catch (_) {
    // Kein Netz: beim nächsten Anzeigen noch mal versuchen.
    _searching.remove(key);
  }
}

/// Großes Bild für eine Kachel: das eigene Produktfoto, sonst das automatisch
/// gefundene Bild aus Wikipedia, sonst das Symbol auf getöntem Grund. Fehlt
/// das automatische Bild noch, wird es beim ersten Anzeigen gesucht und für
/// beide gespeichert. Antippen ([editable]) öffnet die Fotoauswahl.
class ItemPicture extends ConsumerWidget {
  const ItemPicture({
    super.key,
    required this.householdId,
    required this.name,
    this.editable = true,
  });

  final String householdId;
  final String name;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (householdId: householdId, name: name);
    final photo = ref.watch(itemPhotoProvider(key)).value;
    final auto = ref.watch(itemImageProvider(key));
    if (photo == null && auto.hasValue && auto.value == null) {
      Future.microtask(() => _findItemImage(ref, householdId, name));
    }
    final info = auto.value;
    final symbol = _SymbolPicture(name: name);
    final Widget image;
    if (photo != null) {
      image = Image.memory(
        photo,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: 600,
      );
    } else if (info != null && info.shows) {
      image = Image.network(
        info.url,
        fit: BoxFit.cover,
        cacheWidth: 600,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : symbol,
        errorBuilder: (context, error, stack) => symbol,
      );
    } else {
      image = symbol;
    }
    if (!editable) return image;
    return Semantics(
      button: true,
      label: 'Bild für $name',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showItemPhotoSheet(
          context,
          ref,
          householdId: householdId,
          name: name,
          hasPhoto: photo != null,
          autoImage: info,
        ),
        child: image,
      ),
    );
  }
}

class _SymbolPicture extends StatelessWidget {
  const _SymbolPicture({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(itemSymbol(name), style: const TextStyle(fontSize: 48)),
          ),
        ),
      ),
    );
  }
}
