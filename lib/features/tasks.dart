import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

/// households/{id}/tasks: Haushaltsaufgaben.
/// households/{id}/taskLog: wer wann was erledigt hat (für die Punkte).
class HouseTask {
  const HouseTask({
    required this.id,
    required this.title,
    required this.assignee,
    required this.due,
    required this.repeat,
    required this.points,
    required this.done,
  });

  final String id;
  final String title;

  /// uid oder '' für beide.
  final String assignee;
  final DateTime? due;
  final Repeat repeat;
  final int points;
  final bool done;

  factory HouseTask.fromDoc(Doc d) => HouseTask(
    id: d.id,
    title: d.data['title'] as String? ?? '',
    assignee: d.data['assignee'] as String? ?? '',
    due: readDate(d.data['due']),
    repeat: Repeat.parse(d.data['repeat'] as String?),
    points: (d.data['points'] as num?)?.toInt() ?? 1,
    done: d.data['done'] as bool? ?? false,
  );

  bool isOverdue(DateTime now) =>
      !done && due != null && due!.isBefore(dateOnly(now));
  bool isDueToday(DateTime now) =>
      !done && due != null && daysBetween(now, due!) == 0;
}

final tasksProvider = Provider.family<AsyncValue<List<HouseTask>>, String>((
  ref,
  householdId,
) {
  return ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'tasks')),
      )
      .whenData((docs) {
        final list = docs.map(HouseTask.fromDoc).toList();
        list.sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          final ad = a.due, bd = b.due;
          if (ad == null && bd == null) return a.title.compareTo(b.title);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
        return list;
      });
});

/// Punkte pro Person im laufenden Monat.
Map<String, int> pointsThisMonth(List<Doc> log, DateTime now) {
  final result = <String, int>{};
  for (final entry in log) {
    final at = readDate(entry.data['at']);
    if (at == null || at.year != now.year || at.month != now.month) continue;
    final uid = entry.data['uid'] as String? ?? '';
    result[uid] =
        (result[uid] ?? 0) + ((entry.data['points'] as num?)?.toInt() ?? 1);
  }
  return result;
}

/// Hakt eine Aufgabe ab. Wiederkehrende Aufgaben rücken auf den nächsten
/// Termin, der dann zurückgegeben wird.
Future<DateTime?> completeTask(HouseholdStore store, HouseTask task) async {
  final now = DateTime.now();
  DateTime? next;
  if (task.repeat == Repeat.none) {
    await store.update('tasks', task.id, {'done': true});
  } else {
    // Vom alten Fälligkeitsdatum weiterrechnen, bis der Termin in der Zukunft liegt.
    var due = nextOccurrence(task.due ?? today(), task.repeat);
    while (!due.isAfter(today())) {
      due = nextOccurrence(due, task.repeat);
    }
    next = due;
    await store.update('tasks', task.id, {'due': writeDate(due)});
  }
  await store.add('taskLog', {
    'taskId': task.id,
    'title': task.title,
    'uid': store.uid,
    'points': task.points,
    'at': Timestamp.fromDate(now),
  });
  return next;
}

/// Nimmt das Abhaken zurück, samt der Punkte dafür.
Future<void> uncompleteTask(
  HouseholdStore store,
  HouseTask task,
  List<Doc> log,
) async {
  await store.update('tasks', task.id, {'done': false});
  Doc? last;
  DateTime? lastAt;
  for (final entry in log) {
    if (entry.data['taskId'] != task.id) continue;
    final at = readDate(entry.data['at']);
    if (at != null && (lastAt == null || at.isAfter(lastAt))) {
      last = entry;
      lastAt = at;
    }
  }
  if (last != null) await store.delete('taskLog', last.id);
}

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider(householdId));
    final log = ref
        .watch(
          collectionProvider((householdId: householdId, collection: 'taskLog')),
        )
        .value;
    final names = memberNames(ref, householdId);
    final ids = memberIds(ref, householdId);
    final store = ref.read(storeProvider(householdId));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalt'),
        actions: [
          if (tasks.value?.any((t) => t.done) ?? false)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              ),
              onPressed: () async {
                for (final t in tasks.value!.where((t) => t.done)) {
                  await store.delete('tasks', t.id);
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Erledigte löschen'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Aufgabe'),
        onPressed: () => _openEdit(context, null),
      ),
      body: asyncBody(tasks, (list) {
        final points = pointsThisMonth(log ?? const [], now);
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (ids.isNotEmpty)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Punkte im ${monthNames[now.month - 1]}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final id in ids)
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${points[id] ?? 0}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  Text(names[id] ?? '?'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (list.isEmpty)
              const EmptyHint(
                icon: Icons.cleaning_services_outlined,
                mood: MascotMood.cleaning,
                text: 'Noch keine Aufgaben. Legt z. B. „Bad putzen“ wöchentlich an.',
              ),
            ..._sections(list, now).entries.expand(
              (section) => [
                SectionHeader(section.key),
                for (final t in section.value)
                  _TaskTile(
                    task: t,
                    names: names,
                    onToggle: () async {
                      if (t.done) {
                        return uncompleteTask(store, t, log ?? const []);
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      final next = await completeTask(store, t);
                      // Wiederkehrende Aufgaben bleiben offen, rücken aber weiter.
                      if (next != null) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                '„${t.title}“ erledigt. '
                                'Nächstes Mal: ${relativeDay(next)}',
                              ),
                            ),
                          );
                      }
                    },
                    onTap: () => _openEdit(context, t),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Map<String, List<HouseTask>> _sections(List<HouseTask> list, DateTime now) {
    final result = <String, List<HouseTask>>{};
    for (final t in list) {
      final key = t.done
          ? 'Erledigt'
          : t.due == null
          ? 'Ohne Datum'
          : t.isOverdue(now)
          ? 'Überfällig'
          : t.isDueToday(now)
          ? 'Heute'
          : 'Demnächst';
      result.putIfAbsent(key, () => []).add(t);
    }
    const order = [
      'Überfällig',
      'Heute',
      'Demnächst',
      'Ohne Datum',
      'Erledigt',
    ];
    return {
      for (final k in order)
        if (result[k] != null) k: result[k]!,
    };
  }

  void _openEdit(BuildContext context, HouseTask? task) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaskEditScreen(householdId: householdId, task: task),
        ),
      );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.names,
    required this.onToggle,
    required this.onTap,
  });

  final HouseTask task;
  final Map<String, String> names;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = [
      task.assignee.isEmpty ? 'Beide' : names[task.assignee] ?? '?',
      if (task.due != null && !task.done) dueText(task.due!),
      if (task.repeat != Repeat.none) task.repeat.label,
      '${task.points} ${task.points == 1 ? 'Punkt' : 'Punkte'}',
    ];
    final overdue = task.isOverdue(DateTime.now());
    return ListTile(
      leading: Checkbox(value: task.done, onChanged: (_) => onToggle()),
      title: Text(
        task.title,
        style: task.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        parts.join(' · '),
        style: overdue
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: task.repeat != Repeat.none
          ? const Icon(Icons.repeat, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({super.key, required this.householdId, this.task});

  final String householdId;
  final HouseTask? task;

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  late final _title = TextEditingController(text: widget.task?.title);
  late String _assignee = widget.task?.assignee ?? '';
  late DateTime? _due = widget.task?.due ?? today();
  late Repeat _repeat = widget.task?.repeat ?? Repeat.none;
  late int _points = widget.task?.points ?? 1;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return showError(context, 'Bitte gib der Aufgabe einen Namen.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'tasks',
      widget.task?.id,
      {
        'title': title,
        'assignee': _assignee,
        'due': writeDate(_due),
        'repeat': _repeat.name,
        'points': _points,
        if (widget.task == null) 'done': false,
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return EditScaffold(
      title: task == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten',
      onSave: _save,
      onDelete: task == null
          ? null
          : () async {
              if (!await confirmDelete(context, task.title) ||
                  !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('tasks', task.id);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: task == null,
          decoration: const InputDecoration(
            labelText: 'Aufgabe',
            hintText: 'z. B. Bad putzen',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        MemberPicker(
          householdId: widget.householdId,
          label: 'Wer ist dran?',
          value: _assignee,
          onChanged: (v) => setState(() => _assignee = v),
        ),
        DateField(
          label: 'Fällig am',
          value: _due,
          onChanged: (v) => setState(() => _due = v),
        ),
        DropdownButtonFormField<Repeat>(
          initialValue: _repeat,
          decoration: const InputDecoration(labelText: 'Wiederholen'),
          items: [
            for (final r in Repeat.values)
              DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: (v) => setState(() => _repeat = v ?? Repeat.none),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aufwand (Punkte)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SegmentedButton<int>(
              segments: [
                for (var p = 1; p <= 5; p++)
                  ButtonSegment(value: p, label: Text('$p')),
              ],
              selected: {_points},
              onSelectionChanged: (s) => setState(() => _points = s.first),
            ),
          ],
        ),
      ],
    );
  }
}
