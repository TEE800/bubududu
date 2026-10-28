import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';

/// households/{id}/mealPlan/{yyyy-mm-dd}: was es an einem Tag zu essen gibt.
String mealDocId(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime startOfWeek(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

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
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${weekdayLong(day)}, ${day.day}. ${monthNames[day.month - 1]}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Was gibt es?'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Leeren'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final end = _week.add(const Duration(days: 6));
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
                  onPressed: () => setState(
                    () => _week = _week.subtract(const Duration(days: 7)),
                  ),
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
                  onPressed: () => setState(
                    () => _week = _week.add(const Duration(days: 7)),
                  ),
                ),
              ],
            ),
            for (var i = 0; i < 7; i++)
              Builder(
                builder: (context) {
                  final day = _week.add(Duration(days: i));
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
