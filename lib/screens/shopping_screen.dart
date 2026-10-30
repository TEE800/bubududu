import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import '../widgets/item_icon.dart';
import '../widgets/mascots.dart';

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

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(householdRepositoryProvider);
    final items = ref.watch(shoppingItemsProvider(widget.householdId));
    final household = ref.watch(householdProvider(widget.householdId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
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
                return ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete),
                      ),
                      onDismissed: (_) => _delete(item),
                      child: CheckboxListTile(
                        value: item.done,
                        onChanged: (v) => repo.setShoppingItemDone(
                          widget.householdId,
                          item.id,
                          v ?? false,
                        ),
                        title: Row(
                          children: [
                            Opacity(
                              opacity: item.done ? 0.5 : 1,
                              child: ItemAvatar(
                                householdId: widget.householdId,
                                name: item.text,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.text,
                                    style: item.done
                                        ? const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                          )
                                        : null,
                                  ),
                                  if (household != null || item.pending)
                                    Text(
                                      [
                                        if (household != null)
                                          'von ${household.memberNames[item.addedBy] ?? '?'}',
                                        if (item.pending)
                                          'noch nicht abgeglichen',
                                      ].join(' · '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.close),
                          onPressed: () => _delete(item),
                        ),
                      ),
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
