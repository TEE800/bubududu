import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/common.dart';
import 'contracts.dart';

const expenseCategories = [
  'Lebensmittel',
  'Haushalt',
  'Wohnen',
  'Restaurant',
  'Freizeit',
  'Reisen',
  'Geschenke',
  'Sonstiges',
];

/// Kategorie für Ausgleichszahlungen zwischen euch.
const settlementCategory = 'Ausgleich';

enum Split {
  half('Halbe-halbe'),
  other('Nur für die andere Person');

  const Split(this.label);
  final String label;

  static Split parse(String? name) =>
      Split.values.where((s) => s.name == name).firstOrNull ?? Split.half;
}

/// households/{id}/expenses
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.paidBy,
    required this.split,
    required this.category,
    required this.date,
  });

  final String id;
  final String title;
  final int amountCents;
  final String paidBy;
  final Split split;
  final String category;
  final DateTime date;

  bool get isSettlement => category == settlementCategory;

  /// Was die andere Person der zahlenden Person für diese Ausgabe schuldet.
  int get owedByOther =>
      split == Split.half ? (amountCents / 2).round() : amountCents;

  factory Expense.fromDoc(Doc d) => Expense(
    id: d.id,
    title: d.data['title'] as String? ?? '',
    amountCents: (d.data['amountCents'] as num?)?.toInt() ?? 0,
    paidBy: d.data['paidBy'] as String? ?? '',
    split: Split.parse(d.data['split'] as String?),
    category: d.data['category'] as String? ?? 'Sonstiges',
    date: readDate(d.data['date']) ?? today(),
  );
}

/// Wie viel [b] an [a] schuldet (negativ: a schuldet b).
int balance(List<Expense> expenses, String a, String b) {
  var result = 0;
  for (final e in expenses) {
    if (e.paidBy == a) result += e.owedByOther;
    if (e.paidBy == b) result -= e.owedByOther;
  }
  return result;
}

/// Summe pro Kategorie für einen Monat, ohne Ausgleichszahlungen.
Map<String, int> categoryTotals(List<Expense> expenses, DateTime month) {
  final result = <String, int>{};
  for (final e in expenses) {
    if (e.isSettlement ||
        e.date.year != month.year ||
        e.date.month != month.month) {
      continue;
    }
    result[e.category] = (result[e.category] ?? 0) + e.amountCents;
  }
  return Map.fromEntries(
    result.entries.toList()..sort((x, y) => y.value.compareTo(x.value)),
  );
}

final expensesProvider = Provider.family<AsyncValue<List<Expense>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'expenses')),
      )
      .whenData(
        (docs) =>
            docs.map(Expense.fromDoc).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      ),
);

/// Satz wie "Bubu schuldet Dudu 12,50 €" oder null, wenn ausgeglichen/unbekannt.
String? balanceText(
  List<Expense> expenses,
  List<String> members,
  Map<String, String> names,
) {
  if (members.length < 2) return null;
  final a = members[0], b = members[1];
  final owed = balance(expenses, a, b);
  if (owed == 0) return 'Ihr seid quitt.';
  final debtor = owed > 0 ? b : a, creditor = owed > 0 ? a : b;
  return '${names[debtor] ?? '?'} schuldet ${names[creditor] ?? '?'} '
      '${formatCents(owed.abs())}';
}

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _settle(List<Expense> list, List<String> members) async {
    final a = members[0], b = members[1];
    final owed = balance(list, a, b);
    if (owed == 0) return;
    final names = memberNames(ref, widget.householdId);
    final debtor = owed > 0 ? b : a;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ausgleichen?'),
        content: Text(
          'Trage ein, dass ${names[debtor]} ${formatCents(owed.abs())} '
          'überwiesen oder bar gegeben hat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ausgleichen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(storeProvider(widget.householdId)).add('expenses', {
      'title': 'Ausgleich',
      'amountCents': owed.abs(),
      'paidBy': debtor,
      'split': Split.other.name,
      'category': settlementCategory,
      'date': Timestamp.fromDate(today()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider(widget.householdId));
    final contracts = ref.watch(contractsProvider(widget.householdId)).value;
    final names = memberNames(ref, widget.householdId);
    final members = memberIds(ref, widget.householdId);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzen')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ausgabe'),
        onPressed: () => _open(context, null),
      ),
      body: asyncBody(expenses, (list) {
        final inMonth = list
            .where(
              (e) => e.date.year == _month.year && e.date.month == _month.month,
            )
            .toList();
        final totals = categoryTotals(list, _month);
        final monthTotal = totals.values.fold<int>(0, (s, v) => s + v);
        final fixed = (contracts ?? const <Contract>[]).fold<int>(
          0,
          (s, c) => s + c.monthlyCents,
        );
        final text = balanceText(list, members, names);
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (text != null)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kontostand zwischen euch',
                        style: textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(text, style: textTheme.titleLarge),
                      if (balance(list, members[0], members[1]) != 0) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _settle(list, members),
                          child: const Text('Ausgleichen'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Voriger Monat',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Nächster Monat',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
              ],
            ),
            ListTile(
              title: const Text('Ausgaben in diesem Monat'),
              trailing: Text(
                formatCents(monthTotal),
                style: textTheme.titleMedium,
              ),
            ),
            if (fixed > 0)
              ListTile(
                title: const Text('Fixkosten (Verträge)'),
                subtitle: const Text('pro Monat, aus „Verträge & Abos“'),
                trailing: Text(
                  formatCents(fixed),
                  style: textTheme.titleMedium,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ContractsScreen(householdId: widget.householdId),
                  ),
                ),
              ),
            if (totals.isNotEmpty) ...[
              const SectionHeader('Nach Kategorie'),
              for (final entry in totals.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(formatCents(entry.value)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: monthTotal == 0 ? 0 : entry.value / monthTotal,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
            ],
            const SectionHeader('Buchungen'),
            if (inMonth.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('In diesem Monat noch nichts eingetragen.'),
              ),
            for (final e in inMonth)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    e.isSettlement ? Icons.swap_horiz : Icons.receipt_long,
                  ),
                ),
                title: Text(e.title),
                subtitle: Text(
                  [
                    formatShortDate(e.date),
                    '${names[e.paidBy] ?? '?'} hat bezahlt',
                    if (!e.isSettlement) e.category,
                    if (!e.isSettlement && e.split == Split.other)
                      'nur für die andere Person',
                  ].join(' · '),
                ),
                trailing: Text(formatCents(e.amountCents)),
                onTap: () => _open(context, e),
              ),
          ],
        );
      }),
    );
  }

  void _open(BuildContext context, Expense? e) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ExpenseEditScreen(householdId: widget.householdId, expense: e),
    ),
  );
}

class ExpenseEditScreen extends ConsumerStatefulWidget {
  const ExpenseEditScreen({super.key, required this.householdId, this.expense});

  final String householdId;
  final Expense? expense;

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  late final _title = TextEditingController(text: widget.expense?.title);
  late final _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : formatCents(widget.expense!.amountCents).replaceAll(' €', ''),
  );
  late String _paidBy = widget.expense?.paidBy ?? ref.read(uidProvider);
  late Split _split = widget.expense?.split ?? Split.half;
  late String _category = widget.expense?.category ?? expenseCategories.first;
  late DateTime _date = widget.expense?.date ?? today();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final amount = parseCents(_amount.text);
    if (title.isEmpty) return showError(context, 'Wofür war die Ausgabe?');
    if (amount == null || amount == 0) {
      return showError(context, 'Bitte gib einen Betrag ein, z. B. 23,40.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'expenses',
      widget.expense?.id,
      {
        'title': title,
        'amountCents': amount,
        'paidBy': _paidBy,
        'split': _split.name,
        'category': _category,
        'date': writeDate(_date),
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final categories = [
      ...expenseCategories,
      if (e?.isSettlement ?? false) settlementCategory,
    ];
    return EditScaffold(
      title: e == null ? 'Neue Ausgabe' : 'Ausgabe bearbeiten',
      onSave: _save,
      onDelete: e == null
          ? null
          : () async {
              if (!await confirmDelete(context, e.title) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('expenses', e.id);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: e == null,
          decoration: const InputDecoration(
            labelText: 'Wofür?',
            hintText: 'z. B. Wocheneinkauf',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _amount,
          decoration: const InputDecoration(
            labelText: 'Betrag',
            suffixText: '€',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        MemberPicker(
          householdId: widget.householdId,
          label: 'Wer hat bezahlt?',
          allowBoth: false,
          value: _paidBy,
          onChanged: (v) => setState(() => _paidBy = v),
        ),
        SegmentedButton<Split>(
          segments: [
            for (final s in Split.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {_split},
          onSelectionChanged: (s) => setState(() => _split = s.first),
        ),
        DropdownButtonFormField<String>(
          initialValue: categories.contains(_category)
              ? _category
              : 'Sonstiges',
          decoration: const InputDecoration(labelText: 'Kategorie'),
          items: [
            for (final c in categories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        DateField(
          label: 'Datum',
          value: _date,
          allowClear: false,
          onChanged: (v) => setState(() => _date = v ?? _date),
        ),
      ],
    );
  }
}
