import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';

/// households/{id}/mealPlan/{yyyy-mm-dd}: was es an einem Tag zu essen gibt.
String mealDocId(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime startOfWeek(DateTime d) => addDays(d, 1 - d.weekday);

final mealPlanProvider =
    Provider.family<AsyncValue<Map<String, String>>, String>(
      (ref, householdId) => ref
          .watch(
            collectionProvider((
              householdId: householdId,
              collection: 'mealPlan',
            )),
          )
          .whenData(
            (docs) => {
              for (final d in docs)
                if ((d.data['text'] as String? ?? '').isNotEmpty)
                  d.id: d.data['text'] as String,
            },
          ),
    );

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  DateTime _week = startOfWeek(DateTime.now());

  Future<void> _edit(DateTime day, String current) async {
    final recipes =
        ref.read(recipesProvider(widget.householdId)).value ?? const [];
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          _MealDialog(day: day, current: current, recipes: recipes),
    );
    if (result == null) return;
    await ref.read(storeProvider(widget.householdId)).set(
      'mealPlan',
      mealDocId(day),
      {'text': result.trim()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(mealPlanProvider(widget.householdId));
    final end = addDays(_week, 6);
    return Scaffold(
      appBar: AppBar(title: const Text('Essensplan')),
      body: asyncBody(plan, (map) {
        return ListView(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Vorige Woche',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _week = addDays(_week, -7)),
                ),
                Expanded(
                  child: Text(
                    '${_week.day}.${_week.month}. – ${end.day}.${end.month}.${end.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Nächste Woche',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _week = addDays(_week, 7)),
                ),
              ],
            ),
            for (var i = 0; i < 7; i++)
              Builder(
                builder: (context) {
                  final day = addDays(_week, i);
                  final text = map[mealDocId(day)] ?? '';
                  final isToday = day == today();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    color: isToday
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekdayShort(day),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text('${day.day}.'),
                          ],
                        ),
                      ),
                      title: Text(
                        text.isEmpty ? 'Noch nichts geplant' : text,
                        style: text.isEmpty
                            ? TextStyle(color: Theme.of(context).hintColor)
                            : null,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(day, text),
                    ),
                  );
                },
              ),
          ],
        );
      }),
    );
  }
}

/// Eingabe für einen Tag. Eigenes Widget, damit das Textfeld erst nach der
/// Schließen-Animation aufgeräumt wird.
class _MealDialog extends StatefulWidget {
  const _MealDialog({
    required this.day,
    required this.current,
    required this.recipes,
  });

  final DateTime day;
  final String current;
  final List<Recipe> recipes;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    return AlertDialog(
      title: Text(
        '${weekdayLong(day)}, ${day.day}. ${monthNames[day.month - 1]}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Was gibt es?'),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            if (widget.recipes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Aus euren Rezepten:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final r in widget.recipes)
                    ActionChip(
                      label: Text(r.title),
                      onPressed: () => Navigator.pop(context, r.title),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Leeren'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
