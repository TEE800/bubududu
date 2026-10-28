import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';

/// Tab "Rezepte": gemeinsame Rezeptsammlung des Haushalts.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider(householdId));

    return Scaffold(
      appBar: AppBar(title: const Text('Rezepte')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Neues Rezept'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(householdId: householdId),
          ),
        ),
      ),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Noch keine Rezepte. Legt euer erstes an!'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final recipe = list[index];
              final count = recipe.ingredients.length;
              return ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(recipe.title),
                subtitle: Text(count == 1 ? '1 Zutat' : '$count Zutaten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      householdId: householdId,
                      recipeId: recipe.id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({
    super.key,
    required this.householdId,
    required this.recipeId,
  });

  final String householdId;
  final String recipeId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Recipe r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: Text('„${r.title}“ wird für euch beide gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(householdRepositoryProvider);
    Navigator.of(context).pop();
    await repo.deleteRecipe(householdId, r.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider(householdId));
    final recipe = recipes.value
        ?.where((r) => r.id == recipeId)
        .firstOrNull;
    final household = ref.watch(householdProvider(householdId)).value;

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: recipes.isLoading
              ? const CircularProgressIndicator()
              : const Text('Dieses Rezept gibt es nicht mehr.'),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    RecipeEditScreen(householdId: householdId, recipe: recipe),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, recipe),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (household != null)
            Text(
              'von ${household.memberNames[recipe.addedBy] ?? '?'}',
              style: textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Zutaten auf die Einkaufsliste'),
            onPressed: recipe.ingredients.isEmpty
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _SendToShoppingSheet(
                      householdId: householdId,
                      recipe: recipe,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text('Zutaten', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          if (recipe.ingredients.isEmpty) const Text('Keine Zutaten eingetragen.'),
          for (final ingredient in recipe.ingredients)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 8),
              minLeadingWidth: 8,
              title: Text(ingredient),
            ),
          if (recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Zubereitung', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(recipe.instructions),
          ],
        ],
      ),
    );
  }
}

/// Auswahl, welche Zutaten auf die Einkaufsliste sollen. Was dort schon
/// offen steht, ist anfangs abgewählt.
class _SendToShoppingSheet extends ConsumerStatefulWidget {
  const _SendToShoppingSheet({required this.householdId, required this.recipe});

  final String householdId;
  final Recipe recipe;

  @override
  ConsumerState<_SendToShoppingSheet> createState() =>
      _SendToShoppingSheetState();
}

class _SendToShoppingSheetState extends ConsumerState<_SendToShoppingSheet> {
  late final Set<int> _selected;
  late final Set<int> _alreadyOnList;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final open =
        ref
            .read(shoppingItemsProvider(widget.householdId))
            .value
            ?.where((i) => !i.done)
            .map((i) => i.text.trim().toLowerCase())
            .toSet() ??
        const <String>{};
    final ingredients = widget.recipe.ingredients;
    _alreadyOnList = {
      for (var i = 0; i < ingredients.length; i++)
        if (open.contains(ingredients[i].trim().toLowerCase())) i,
    };
    _selected = {
      for (var i = 0; i < ingredients.length; i++)
        if (!_alreadyOnList.contains(i)) i,
    };
  }

  Future<void> _send() async {
    setState(() => _saving = true);
    final texts = [
      for (var i = 0; i < widget.recipe.ingredients.length; i++)
        if (_selected.contains(i)) widget.recipe.ingredients[i],
    ];
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(householdRepositoryProvider)
        .addShoppingItems(
          widget.householdId,
          texts,
          FirebaseAuth.instance.currentUser!.uid,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          texts.length == 1
              ? '1 Zutat steht jetzt auf der Einkaufsliste.'
              : '${texts.length} Zutaten stehen jetzt auf der Einkaufsliste.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = widget.recipe.ingredients;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Was soll auf die Liste?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < ingredients.length; i++)
                    CheckboxListTile(
                      value: _selected.contains(i),
                      title: Text(ingredients[i]),
                      subtitle: _alreadyOnList.contains(i)
                          ? const Text('steht schon auf der Liste')
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(
                        () => v == true ? _selected.add(i) : _selected.remove(i),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _send,
                child: Text('${_selected.length} auf die Einkaufsliste'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, required this.householdId, this.recipe});

  final String householdId;

  /// null = neues Rezept anlegen.
  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  late final _title = TextEditingController(text: widget.recipe?.title);
  late final _ingredients = TextEditingController(
    text: widget.recipe?.ingredients.join('\n'),
  );
  late final _instructions = TextEditingController(
    text: widget.recipe?.instructions,
  );
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _ingredients.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib dem Rezept einen Namen.')),
      );
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(householdRepositoryProvider)
        .saveRecipe(
          widget.householdId,
          recipeId: widget.recipe?.id,
          title: title,
          ingredients: _ingredients.text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList(),
          instructions: _instructions.text.trim(),
          uid: FirebaseAuth.instance.currentUser!.uid,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Neues Rezept' : 'Rezept bearbeiten'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'z. B. Spaghetti Bolognese',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ingredients,
            decoration: const InputDecoration(
              labelText: 'Zutaten',
              hintText: 'Eine Zutat pro Zeile, z. B.\n500 g Hackfleisch\n1 Zwiebel',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            minLines: 5,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructions,
            decoration: const InputDecoration(
              labelText: 'Zubereitung (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
