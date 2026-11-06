import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/recipe_scanner.dart';
import '../util/recipe_parser.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';
import '../widgets/recipe_image.dart';

/// Tab "Rezepte": das gemeinsame Kochbuch des Haushalts. Vorne das
/// Inhaltsverzeichnis, danach eine Seite je Rezept zum Umblättern.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({
    super.key,
    required this.householdId,
    this.initialRecipeId,
  });

  final String householdId;

  /// Schlägt das Kochbuch gleich bei diesem Rezept auf.
  final String? initialRecipeId;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  PageController? _controller;
  int _page = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  PageController _controllerFor(List<Recipe> list) {
    final existing = _controller;
    if (existing != null) return existing;
    final index = list.indexWhere((r) => r.id == widget.initialRecipeId);
    _page = index < 0 ? 0 : index + 1;
    return _controller = PageController(initialPage: _page);
  }

  void _goTo(int page) => _controller?.animateToPage(
    page,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOut,
  );

  Future<void> _delete(Recipe r) async {
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
    if (ok != true || !mounted) return;
    // Eine Seite zurückblättern, damit keine leere Seite stehen bleibt.
    final back = _page > 0 ? _page - 1 : 0;
    _controller?.jumpToPage(back);
    setState(() => _page = back);
    await ref
        .read(householdRepositoryProvider)
        .deleteRecipe(widget.householdId, r.id);
  }

  void _openEditor({Recipe? recipe}) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          RecipeEditScreen(householdId: widget.householdId, recipe: recipe),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider(widget.householdId));
    // Hält die Einkaufsliste geladen, damit die Auswahl weiß, was schon drauf steht.
    ref.watch(shoppingItemsProvider(widget.householdId));
    final list = recipes.value ?? const <Recipe>[];
    if (list.isNotEmpty) _controllerFor(list);
    final current = _page > 0 && _page <= list.length ? list[_page - 1] : null;

    return Scaffold(
      backgroundColor: _cover,
      appBar: AppBar(
        title: const Text('Kochbuch'),
        actions: [
          if (current != null) ...[
            IconButton(
              tooltip: 'Inhalt',
              icon: const Icon(Icons.toc),
              onPressed: () => _goTo(0),
            ),
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditor(recipe: current),
            ),
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(current),
            ),
          ] else if (!kIsWeb)
            // Die Texterkennung gibt es nur in der installierten App.
            IconButton(
              tooltip: 'Rezept scannen',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => _scanRecipe(context, widget.householdId),
            ),
        ],
      ),
      floatingActionButton: current == null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Neues Rezept'),
              onPressed: _openEditor,
            )
          : null,
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Fehler: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _BookPage(
              child: EmptyHint(
                icon: Icons.menu_book_outlined,
                text:
                    'Euer Kochbuch ist noch leer. Legt euer erstes Rezept an!',
                mood: MascotMood.hungry,
              ),
            );
          }
          final controller = _controllerFor(list);
          return PageView.builder(
            controller: controller,
            itemCount: list.length + 1,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _PageTurn(
              controller: controller,
              index: index,
              child: _BookPage(
                pageNumber: index + 1,
                child: index == 0
                    ? _Contents(
                        householdId: widget.householdId,
                        recipes: list,
                        onOpen: _goTo,
                      )
                    : _RecipePage(
                        householdId: widget.householdId,
                        recipe: list[index - 1],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ein einzelnes Rezept, aufgeschlagen im Kochbuch.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({
    super.key,
    required this.householdId,
    required this.recipeId,
  });

  final String householdId;
  final String recipeId;

  @override
  Widget build(BuildContext context) =>
      RecipesScreen(householdId: householdId, initialRecipeId: recipeId);
}

// Farben des Kochbuchs: dunkelgrüner Einband, cremefarbenes Papier.
const _cover = Color(0xFF123F17);
const _paper = Color(0xFFFBF6EA);
const _ink = Color(0xFF2B2A26);
const _inkSoft = Color(0xFF6E675B);
const _accent = Color(0xFF1B5E20);
const _serif = 'serif';
const _serifFallback = ['Georgia', 'Noto Serif', 'Times New Roman'];

TextStyle _bookText({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  FontStyle style = FontStyle.normal,
  Color color = _ink,
  double? letterSpacing,
  double height = 1.45,
}) => TextStyle(
  fontFamily: _serif,
  fontFamilyFallback: _serifFallback,
  fontSize: size,
  fontWeight: weight,
  fontStyle: style,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Dreht die Seiten beim Wischen leicht weg, wie beim Umblättern.
class _PageTurn extends StatelessWidget {
  const _PageTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var offset = 0.0;
        if (controller.hasClients && controller.position.haveDimensions) {
          offset = (index - (controller.page ?? 0)).clamp(-1.0, 1.0).toDouble();
        }
        if (offset == 0) return child!;
        return Transform(
          alignment: offset > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(-offset * 0.6),
          child: child,
        );
      },
    );
  }
}

/// Ein Blatt Papier mit Buchrücken links und Seitenzahl unten.
class _BookPage extends StatelessWidget {
  const _BookPage({required this.child, this.pageNumber});

  final Widget child;
  final int? pageNumber;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.horizontal(
      left: Radius.circular(4),
      right: Radius.circular(16),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _paper,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(2, 4),
            ),
            // Angedeutete Seiten darunter
            BoxShadow(color: Color(0xFFE9E0CC), offset: Offset(4, 3)),
            BoxShadow(color: Color(0xFFDCD1B8), offset: Offset(7, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // Schatten des Buchrückens
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: _bookText(),
                      child: child,
                    ),
                  ),
                  if (pageNumber != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Text(
                        '– $pageNumber –',
                        style: _bookText(size: 13, color: _inkSoft),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zierlinie zwischen Abschnitten.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(color: Color(0x551B5E20), height: 1));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('❦', style: _bookText(size: 20, color: _accent)),
          ),
          line,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: _bookText(
        size: 14,
        weight: FontWeight.bold,
        color: _accent,
        letterSpacing: 2.5,
      ),
    ),
  );
}

/// Erste Seite: Titel und alle Rezepte als Kacheln mit Bild des Gerichts.
class _Contents extends StatelessWidget {
  const _Contents({
    required this.householdId,
    required this.recipes,
    required this.onOpen,
  });

  final String householdId;
  final List<Recipe> recipes;
  final void Function(int page) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 28, 20, 88),
      children: [
        Text(
          'Unser Kochbuch',
          textAlign: TextAlign.center,
          style: _bookText(size: 32, weight: FontWeight.bold, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Rezepte von Bubu & Dudu',
          textAlign: TextAlign.center,
          style: _bookText(style: FontStyle.italic, color: _inkSoft),
        ),
        const _Ornament(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: recipes.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, i) => _RecipeTile(
            householdId: householdId,
            recipe: recipes[i],
            page: i + 2,
            onTap: () => onOpen(i + 1),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Kachel antippen oder nach links wischen zum Blättern',
          textAlign: TextAlign.center,
          style: _bookText(size: 13, style: FontStyle.italic, color: _inkSoft),
        ),
      ],
    );
  }
}

/// Kachel auf der ersten Seite: eingeklebtes Foto, Name und Seitenzahl.
class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.householdId,
    required this.recipe,
    required this.page,
    required this.onTap,
  });

  final String householdId;
  final Recipe recipe;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: RecipeImage(
                    householdId: householdId,
                    recipe: recipe,
                    editable: false,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _bookText(
                        size: 15,
                        weight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Text(' $page', style: _bookText(size: 12, color: _inkSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Rezeptseite: Foto, Titel, Zutaten, Zubereitung.
class _RecipePage extends ConsumerWidget {
  const _RecipePage({required this.householdId, required this.recipe});

  final String householdId;
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider(householdId)).value;
    final author = household?.memberNames[recipe.addedBy];
    final steps = recipe.instructions
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 8),
      children: [
        // Eingeklebtes Foto mit weißem Rand
        Transform.rotate(
          angle: -0.012,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 6,
                  offset: Offset(1, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: RecipeImage(householdId: householdId, recipe: recipe),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          recipe.title,
          textAlign: TextAlign.center,
          style: _bookText(size: 28, weight: FontWeight.bold, height: 1.2),
        ),
        if (author != null) ...[
          const SizedBox(height: 4),
          Text(
            'von $author',
            textAlign: TextAlign.center,
            style: _bookText(style: FontStyle.italic, color: _inkSoft),
          ),
        ],
        const _Ornament(),
        const _SectionTitle('Zutaten'),
        if (recipe.ingredients.isEmpty)
          Text(
            'Keine Zutaten eingetragen.',
            style: _bookText(style: FontStyle.italic, color: _inkSoft),
          ),
        for (final ingredient in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: _bookText(color: _accent)),
                Expanded(child: Text(ingredient)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
            ),
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
        ),
        if (steps.isNotEmpty) ...[
          const _Ornament(),
          const _SectionTitle('Zubereitung'),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: steps.length == 1
                  ? Text(steps[i])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}.',
                            style: _bookText(
                              weight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                        ),
                        Expanded(child: Text(steps[i])),
                      ],
                    ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Fotografiert oder wählt Rezeptbilder und liest das Rezept daraus.
Future<void> _scanRecipe(BuildContext context, String householdId) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Rezept scannen'),
            subtitle: Text(
              'Passt das Rezept nicht auf ein Bild, einfach mehrere '
              'nehmen, sie werden zu einem Rezept zusammengefügt.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Fotos aufnehmen'),
            subtitle: const Text('Gerade von oben, mit gutem Licht'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Bilder aus der Galerie'),
            subtitle: const Text(
              'Screenshots von oben nach unten antippen, weitere kannst du danach nachlegen',
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final images = <XFile>[];
  try {
    final gallery = source == ImageSource.gallery;
    while (true) {
      final picked = gallery
          ? await pickRecipeImages()
          : [?await takeRecipePhoto()];
      if (!context.mounted) return;
      if (picked.isEmpty) break;
      images.addAll(picked);
      // Nachlegen geht immer, auch wenn die Galerie nur ein Bild auf
      // einmal auswählen lässt.
      final more = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            images.length == 1
                ? '1 Bild ausgewählt'
                : '${images.length} Bilder ausgewählt',
          ),
          content: const Text('Geht das Rezept noch weiter?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(gallery ? 'Weitere Bilder' : 'Weiteres Foto'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Fertig'),
            ),
          ],
        ),
      );
      if (more != true) break;
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Bilder konnten nicht geöffnet werden.'),
        ),
      );
    }
    return;
  }
  if (images.isEmpty || !context.mounted) return;

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 24),
          Expanded(child: Text('Rezept wird gelesen …')),
        ],
      ),
    ),
  );
  List<OcrLine>? lines;
  Object? error;
  try {
    lines = await scanRecipeImages(images);
  } catch (e) {
    error = e;
  }
  navigator.pop();

  if (error != null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Die Bilder konnten nicht gelesen werden.')),
    );
    return;
  }
  final draft = parseRecipeLines(lines!);
  if (draft.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Auf den Bildern wurde kein Text erkannt.')),
    );
    return;
  }
  navigator.push(
    MaterialPageRoute(
      builder: (_) => RecipeEditScreen(householdId: householdId, draft: draft),
    ),
  );
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
        .addShoppingItems(widget.householdId, texts, ref.read(uidProvider));
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
                        () =>
                            v == true ? _selected.add(i) : _selected.remove(i),
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
  const RecipeEditScreen({
    super.key,
    required this.householdId,
    this.recipe,
    this.draft,
  });

  final String householdId;

  /// null = neues Rezept anlegen.
  final Recipe? recipe;

  /// Vorschlag aus einem gescannten Foto, wird zum Prüfen vorausgefüllt.
  final RecipeDraft? draft;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  late final _title = TextEditingController(
    text: widget.recipe?.title ?? widget.draft?.title,
  );
  late final _ingredients = TextEditingController(
    text: (widget.recipe?.ingredients ?? widget.draft?.ingredients)?.join('\n'),
  );
  late final _instructions = TextEditingController(
    text: widget.recipe?.instructions ?? widget.draft?.instructions,
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
          uid: ref.read(uidProvider),
          resetImage: widget.recipe != null && widget.recipe!.title != title,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipe == null ? 'Neues Rezept' : 'Rezept bearbeiten',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            // Sonst Dunkelgrün auf der dunkelgrünen Leiste.
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.draft != null) ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.document_scanner_outlined),
                title: Text('Aus dem Foto erkannt'),
                subtitle: Text(
                  'Bitte kurz prüfen und korrigieren, dann speichern.',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
              hintText:
                  'Eine Zutat pro Zeile, z. B.\n500 g Hackfleisch\n1 Zwiebel',
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
