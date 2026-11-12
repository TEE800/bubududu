import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../features/pantry.dart';
import '../features/receipt_import.dart';
import '../features/shopping_to_pantry.dart';
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
  final _amount = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _amount.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref
        .read(householdRepositoryProvider)
        .addShoppingItem(
          widget.householdId,
          text,
          ref.read(uidProvider),
          amount: _amount.text,
        );
    _input.clear();
    _amount.clear();
    _inputFocus.requestFocus();
  }

  /// Lange drücken: Name und Menge ändern oder ein Foto wählen.
  Future<void> _more(ShoppingItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Name und Menge ändern'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto wählen'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _edit(item);
    if (action == 'photo') await _photo(item.text);
  }

  Future<void> _edit(ShoppingItem item) async {
    final result = await showDialog<({String text, String amount})>(
      context: context,
      builder: (_) => _EditItemDialog(item: item),
    );
    if (result == null || result.text.trim().isEmpty) return;
    await ref
        .read(householdRepositoryProvider)
        .updateShoppingItem(
          widget.householdId,
          item.id,
          text: result.text,
          amount: result.amount,
        );
  }

  /// Abhaken bucht den Einkauf in die Vorräte, "Wieder offen" nimmt das
  /// zurück.
  void _toggle(ShoppingItem item) {
    final store = ref.read(storeProvider(widget.householdId));
    if (item.done) {
      reopenFromPantry(store, item);
      return;
    }
    final pantry = ref.read(pantryProvider(widget.householdId)).value;
    if (pantry == null) {
      // Vorräte noch nicht geladen: nur abhaken.
      ref
          .read(householdRepositoryProvider)
          .setShoppingItemDone(widget.householdId, item.id, true);
      return;
    }
    final plan = checkOffIntoPantry(store, pantry, item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            plan.created
                ? '„${plan.name}“ ist jetzt in den Vorräten.'
                : '„${plan.name}“ in den Vorräten: ${countText(plan.count)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
              amount: item.amount,
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
    // Für das Abhaken: Vorräte schon geladen halten.
    ref.watch(pantryProvider(widget.householdId));

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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    decoration: const InputDecoration(
                      hintText: 'Was brauchen wir?',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: TextField(
                    controller: _amount,
                    decoration: InputDecoration(
                      hintText: 'Menge',
                      suffixIcon: IconButton(
                        tooltip: 'Hinzufügen',
                        icon: const Icon(Icons.add),
                        onPressed: _add,
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
              ],
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
                void toggle(ShoppingItem item) => _toggle(item);
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
                      tag: item.amount,
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
                      // Lange drücken: Name/Menge ändern oder Foto wählen.
                      onLongPress: () => _more(item),
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

/// Name und Menge eines Eintrags ändern.
class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});

  final ShoppingItem item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final _text = TextEditingController(text: widget.item.text);
  late final _amount = TextEditingController(text: widget.item.amount);

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() =>
      Navigator.pop(context, (text: _text.text, amount: _amount.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eintrag ändern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            decoration: const InputDecoration(labelText: 'Was'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(
              labelText: 'Menge (optional)',
              hintText: 'z. B. 2 oder 500 g',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
