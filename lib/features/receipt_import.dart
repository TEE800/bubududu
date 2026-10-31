import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../util/pdf_text.dart';
import '../util/rewe_receipt.dart';
import '../widgets/common.dart';
import 'finance.dart';
import 'pantry.dart';

/// Lässt einen Rewe-eBon (PDF) wählen, liest ihn aus und zeigt, was
/// übernommen wird. Fehler erscheinen als Hinweis unten.
Future<void> importReweReceipt(BuildContext context, String householdId) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final file = await FilePicker.pickFile(
    dialogTitle: 'Rewe-eBon (PDF) wählen',
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (file == null) return;
  ReweReceipt receipt;
  try {
    receipt = parseReweReceipt(await pdfText(await file.readAsBytes()));
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Die PDF ließ sich nicht lesen.')),
    );
    return;
  }
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ReceiptImportScreen(householdId: householdId, receipt: receipt),
    ),
  );
}

/// Titel der Ausgabe, auch zum Erkennen, ob ein Bon schon eingetragen ist.
const reweExpenseTitle = 'Rewe-Einkauf';

class ReceiptImportScreen extends ConsumerStatefulWidget {
  const ReceiptImportScreen({
    super.key,
    required this.householdId,
    required this.receipt,
  });

  final String householdId;
  final ReweReceipt receipt;

  @override
  ConsumerState<ReceiptImportScreen> createState() =>
      _ReceiptImportScreenState();
}

class _ReceiptImportScreenState extends ConsumerState<ReceiptImportScreen> {
  /// Abgewählte Einträge (Einkaufsliste und Vorräte), nach ID.
  final _skip = <String>{};
  bool? _expense;

  List<ReceiptLine> get _products => widget.receipt.products;

  DateTime get _day => dateOnly(widget.receipt.date ?? DateTime.now());

  bool _alreadyBooked(List<Expense> expenses) => expenses.any(
    (e) =>
        e.title == reweExpenseTitle &&
        e.amountCents == widget.receipt.totalCents &&
        e.date == _day,
  );

  Future<void> _apply(
    List<(ShoppingItem, ReceiptLine)> shopping,
    List<(PantryItem, ReceiptLine)> pantry,
    bool expense,
  ) async {
    final repo = ref.read(householdRepositoryProvider);
    final store = ref.read(storeProvider(widget.householdId));
    final now = DateTime.now();
    var count = 0;
    for (final (item, _) in shopping) {
      if (_skip.contains(item.id)) continue;
      repo.setShoppingItemDone(widget.householdId, item.id, true);
      count++;
    }
    for (final (item, _) in pantry) {
      if (_skip.contains(item.id)) continue;
      store.update(
        'pantry',
        item.id,
        item.countsUses
            ? item.usesUpdate(item.uses!.toDouble(), now)
            : {'level': StockLevel.full.name},
      );
      count++;
    }
    if (expense) {
      store.add('expenses', {
        'title': reweExpenseTitle,
        'amountCents': widget.receipt.totalCents,
        'paidBy': ref.read(uidProvider),
        'split': Split.half.name,
        'category': 'Lebensmittel',
        'date': writeDate(_day),
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          [
            if (count > 0) '$count Einträge aktualisiert',
            if (expense) 'Ausgabe eingetragen',
          ].join(', ').ifEmpty('Nichts übernommen.'),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final shoppingItems = ref.watch(shoppingItemsProvider(widget.householdId));
    final pantryItems = ref.watch(pantryProvider(widget.householdId));
    final expenses = ref.watch(expensesProvider(widget.householdId));
    final theme = Theme.of(context);

    final shopping = [
      for (final i in shoppingItems.value ?? const <ShoppingItem>[])
        if (!i.done)
          if (matchingLine(i.text, _products) case final line?) (i, line),
    ];
    final pantry = [
      for (final i in pantryItems.value ?? const <PantryItem>[])
        if (matchingLine(i.name, _products) case final line?) (i, line),
    ];
    final booked = _alreadyBooked(expenses.value ?? const []);
    final expense = _expense ?? !booked;
    final loading =
        shoppingItems.isLoading || pantryItems.isLoading || expenses.isLoading;

    String lineText(ReceiptLine l) =>
        'Bon: ${l.displayName}${l.quantity > 1 ? ' (${l.quantity}×)' : ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('Kassenbon einlesen')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    'Rewe · ${formatCents(r.totalCents)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    [
                      if (r.date != null) formatDate(r.date!),
                      '${_products.length} Produkte',
                    ].join(' · '),
                  ),
                ),
                if (r.bonusEarnedCents != null || r.bonusBalanceCents != null)
                  ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: Text(
                      r.bonusEarnedCents == null
                          ? 'Rewe Bonus'
                          : '${formatCents(r.bonusEarnedCents!)} Bonus gesammelt',
                    ),
                    subtitle: r.bonusBalanceCents == null
                        ? null
                        : Text(
                            'Guthaben jetzt ${formatCents(r.bonusBalanceCents!)}',
                          ),
                  ),
                const SectionHeader('Ausgabe'),
                SwitchListTile(
                  value: expense,
                  onChanged: (v) => setState(() => _expense = v),
                  title: Text(
                    '$reweExpenseTitle ${formatCents(r.totalCents)} eintragen',
                  ),
                  subtitle: Text(
                    booked
                        ? 'Steht schon in den Finanzen.'
                        : 'Lebensmittel · Halbe-halbe · von dir bezahlt',
                  ),
                ),
                const SectionHeader('Auf der Einkaufsliste abhaken'),
                if (shopping.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text('Nichts davon steht auf der Liste.'),
                  ),
                for (final (item, line) in shopping)
                  CheckboxListTile(
                    value: !_skip.contains(item.id),
                    onChanged: (v) => setState(
                      () => v! ? _skip.remove(item.id) : _skip.add(item.id),
                    ),
                    title: Text(item.text),
                    subtitle: Text(lineText(line)),
                  ),
                const SectionHeader('Vorräte auffüllen'),
                if (pantry.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text('Keine passenden Vorräte gefunden.'),
                  ),
                for (final (item, line) in pantry)
                  CheckboxListTile(
                    value: !_skip.contains(item.id),
                    onChanged: (v) => setState(
                      () => v! ? _skip.remove(item.id) : _skip.add(item.id),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${lineText(line)} → '
                      '${item.countsUses ? 'wieder ${item.uses} Nutzungen' : StockLevel.full.label}',
                    ),
                  ),
                ExpansionTile(
                  title: const Text('Alle Zeilen auf dem Bon'),
                  children: [
                    for (final l in r.lines)
                      ListTile(
                        dense: true,
                        title: Text(l.displayName),
                        trailing: Text(formatCents(l.cents)),
                      ),
                  ],
                ),
              ],
            ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _apply(shopping, pantry, expense),
              icon: const Icon(Icons.check),
              label: const Text('Übernehmen'),
            ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
