import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../features/receipt_import.dart';
import '../widgets/common.dart';
import '../widgets/item_icon.dart';
import '../widgets/mascots.dart';
import '../widgets/pic_tile.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref
        .read(householdRepositoryProvider)
        .addShoppingItem(widget.householdId, text, ref.read(uidProvider));
    _input.clear();
  }

  /// Löscht sofort, lässt sich aber ein paar Sekunden lang rückgängig machen.
  void _delete(ShoppingItem item) {
    final repo = ref.read(householdRepositoryProvider);
    final uid = ref.read(uidProvider);
    repo.deleteShoppingItem(widget.householdId, item.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('„${item.text}“ gelöscht'),
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: () => repo.addShoppingItem(
              widget.householdId,
              item.text,
              item.addedBy.isEmpty ? uid : item.addedBy,
              done: item.done,
            ),
          ),
        ),
      );
  }

  /// Öffnet Rewe: die Rewe-App, falls installiert und für rewe.de-Links
  /// zuständig, sonst die Webseite im Browser. Eine echte Verbindung zur
  /// Rewe-Bonus-App gibt es nicht, weil Rewe keine Schnittstelle anbietet.
  Future<void> _openRewe() async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('https://www.rewe.de/'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rewe ließ sich nicht öffnen.')),
      );
    }
  }

  /// Fotoauswahl für einen Eintrag, mit dem aktuellen Stand von Foto und
  /// automatischem Bild.
  Future<void> _photo(String name) async {
    final key = (householdId: widget.householdId, name: name);
    final photo = await ref.read(itemPhotoProvider(key).future);
    final auto = await ref.read(itemImageProvider(key).future);
    if (!mounted) return;
    await showItemPhotoSheet(
      context,
      ref,
      householdId: widget.householdId,
      name: name,
      hasPhoto: photo != null,
      autoImage: auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(householdRepositoryProvider);
    final items = ref.watch(shoppingItemsProvider(widget.householdId));
    final household = ref.watch(householdProvider(widget.householdId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
          PopupMenuButton<void Function()>(
            tooltip: 'Rewe',
            icon: const Icon(Icons.storefront_outlined),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => importReweReceipt(context, widget.householdId),
                child: const ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Kassenbon einlesen'),
                ),
              ),
              PopupMenuItem(
                value: _openRewe,
                child: const ListTile(
                  leading: Icon(Icons.open_in_new),
                  title: Text('Rewe öffnen'),
                ),
              ),
            ],
          ),
          if (items.value?.any((i) => i.done) ?? false)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              ),
              onPressed: () => repo.clearDoneItems(widget.householdId, [
                for (final i in items.value!)
                  if (i.done) i.id,
              ]),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Erledigte löschen'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _input,
              decoration: InputDecoration(
                hintText: 'Was brauchen wir?',
                suffixIcon: IconButton(
                  tooltip: 'Hinzufügen',
                  icon: const Icon(Icons.add),
                  onPressed: _add,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _add(),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyHint(
                    icon: Icons.shopping_cart_outlined,
                    text: 'Die Liste ist leer.',
                    mood: MascotMood.shopping,
                  );
                }
                // Offene Einträge oben, erledigte unten.
                final sorted = [
                  ...list.where((i) => !i.done),
                  ...list.where((i) => i.done),
                ];
                void toggle(ShoppingItem item) => repo.setShoppingItemDone(
                  widget.householdId,
                  item.id,
                  !item.done,
                );
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  gridDelegate: picGridDelegate(context, tileHeight: 196),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    return PicTile(
                      key: ValueKey(item.id),
                      title: item.text,
                      picture: ItemPicture(
                        householdId: widget.householdId,
                        name: item.text,
                        editable: false,
                      ),
                      done: item.done,
                      subtitle: [
                        if (household != null)
                          'von ${household.memberNames[item.addedBy] ?? '?'}',
                        if (item.pending) 'noch nicht abgeglichen',
                      ].join(' · '),
                      corner: TileButton(
                        tooltip: item.done ? 'Wieder offen' : 'Abhaken',
                        icon: Icons.check,
                        active: item.done,
                        onPressed: () => toggle(item),
                      ),
                      cornerRight: TileButton(
                        tooltip: 'Löschen',
                        icon: Icons.close,
                        onPressed: () => _delete(item),
                      ),
                      onTap: () => toggle(item),
                      // Lange drücken: eigenes Produktfoto wählen.
                      onLongPress: () => _photo(item.text),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
