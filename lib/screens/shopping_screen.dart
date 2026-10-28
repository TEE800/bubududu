import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

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
        .addShoppingItem(
          widget.householdId,
          text,
          FirebaseAuth.instance.currentUser!.uid,
        );
    _input.clear();
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
              onPressed: () => repo.clearDoneItems(widget.householdId),
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
                  return const Center(child: Text('Die Liste ist leer.'));
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
                      onDismissed: (_) =>
                          repo.deleteShoppingItem(widget.householdId, item.id),
                      child: CheckboxListTile(
                        value: item.done,
                        onChanged: (v) => repo.setShoppingItemDone(
                          widget.householdId,
                          item.id,
                          v ?? false,
                        ),
                        title: Text(
                          item.text,
                          style: item.done
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: household == null
                            ? null
                            : Text(
                                'von ${household.memberNames[item.addedBy] ?? '?'}',
                              ),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.close),
                          onPressed: () => repo.deleteShoppingItem(
                            widget.householdId,
                            item.id,
                          ),
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
