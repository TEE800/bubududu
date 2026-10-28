import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../util/dates.dart';
import 'mascots.dart';

/// Hinweis für leere Listen. Mit [mood] zeigen sich Bubu und Dudu statt des Symbols.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.mood,
  });

  final IconData icon;
  final String text;
  final MascotMood? mood;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mood != null)
              Mascots(mood: mood!, height: 110)
            else
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Lade- und Fehleranzeige für AsyncValue in einer Zeile.
Widget asyncBody<T>(AsyncValue<T> value, Widget Function(T data) data) =>
    value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: data,
    );

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Löschen?'),
      content: Text('„$what“ wird für euch beide gelöscht.'),
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
  return ok ?? false;
}

/// Namen der Haushaltsmitglieder (uid → Name), leer solange geladen wird.
Map<String, String> memberNames(WidgetRef ref, String householdId) =>
    ref.watch(householdProvider(householdId)).value?.memberNames ?? const {};

List<String> memberIds(WidgetRef ref, String householdId) =>
    ref.watch(householdProvider(householdId)).value?.members ?? const [];

/// Auswahl "Beide" oder eine Person. '' steht für beide.
class MemberPicker extends ConsumerWidget {
  const MemberPicker({
    super.key,
    required this.householdId,
    required this.value,
    required this.onChanged,
    this.allowBoth = true,
    this.label = 'Wer?',
  });

  final String householdId;
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowBoth;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Household? household = ref
        .watch(householdProvider(householdId))
        .value;
    final names = household?.memberNames ?? const {};
    final ids = household?.members ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (allowBoth)
              ChoiceChip(
                label: const Text('Beide'),
                selected: value.isEmpty,
                onSelected: (_) => onChanged(''),
              ),
            for (final id in ids)
              ChoiceChip(
                label: Text(names[id] ?? '?'),
                selected: value == id,
                onSelected: (_) => onChanged(id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Knopf, der ein Datum zeigt und beim Antippen den Kalender öffnet.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null && allowClear
            ? IconButton(
                tooltip: 'Datum entfernen',
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? today(),
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: Text(value == null ? 'Kein Datum' : formatDate(value!)),
      ),
    );
  }
}

/// Einheitliche Bearbeiten-Seite mit Speichern und optional Löschen.
class EditScaffold extends StatelessWidget {
  const EditScaffold({
    super.key,
    required this.title,
    required this.onSave,
    required this.children,
    this.onDelete,
  });

  final String title;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onDelete != null)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          TextButton(
            onPressed: onSave,
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
          for (final c in children) ...[c, const SizedBox(height: 16)],
        ],
      ),
    );
  }
}

void showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
