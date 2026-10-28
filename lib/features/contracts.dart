import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/common.dart';

enum BillingInterval {
  monthly('monatlich', 1),
  quarterly('vierteljährlich', 3),
  yearly('jährlich', 12);

  const BillingInterval(this.label, this.months);
  final String label;
  final int months;

  static BillingInterval parse(String? name) =>
      BillingInterval.values.where((i) => i.name == name).firstOrNull ??
      BillingInterval.monthly;
}

/// households/{id}/contracts: Verträge, Abos und Fixkosten.
class Contract {
  const Contract({
    required this.id,
    required this.name,
    required this.provider,
    required this.costCents,
    required this.interval,
    required this.cancelBy,
    required this.note,
  });

  final String id;
  final String name;
  final String provider;
  final int costCents;
  final BillingInterval interval;

  /// Spätester Tag zum Kündigen, falls bekannt.
  final DateTime? cancelBy;
  final String note;

  int get monthlyCents => (costCents / interval.months).round();

  factory Contract.fromDoc(Doc d) => Contract(
    id: d.id,
    name: d.data['name'] as String? ?? '',
    provider: d.data['provider'] as String? ?? '',
    costCents: (d.data['costCents'] as num?)?.toInt() ?? 0,
    interval: BillingInterval.parse(d.data['interval'] as String?),
    cancelBy: readDate(d.data['cancelBy']),
    note: d.data['note'] as String? ?? '',
  );
}

final contractsProvider = Provider.family<AsyncValue<List<Contract>>, String>(
  (ref, householdId) => ref
      .watch(
        collectionProvider((householdId: householdId, collection: 'contracts')),
      )
      .whenData((docs) {
        final list = docs.map(Contract.fromDoc).toList();
        list.sort((a, b) {
          final ad = a.cancelBy, bd = b.cancelBy;
          if (ad != null && bd != null) return ad.compareTo(bd);
          if (ad != null) return -1;
          if (bd != null) return 1;
          return a.name.compareTo(b.name);
        });
        return list;
      }),
);

/// Kündigungsfristen in den nächsten [days] Tagen (noch nicht abgelaufen).
List<Contract> upcomingDeadlines(
  List<Contract> list, {
  int days = 30,
  DateTime? now,
}) {
  final t = dateOnly(now ?? DateTime.now());
  return [
    for (final c in list)
      if (c.cancelBy != null &&
          !c.cancelBy!.isBefore(t) &&
          daysBetween(t, c.cancelBy!) <= days)
        c,
  ];
}

class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contracts = ref.watch(contractsProvider(householdId));
    return Scaffold(
      appBar: AppBar(title: const Text('Verträge & Abos')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Vertrag'),
        onPressed: () => _open(context, null),
      ),
      body: asyncBody(contracts, (list) {
        if (list.isEmpty) {
          return const EmptyHint(
            icon: Icons.description_outlined,
            text:
                'Tragt hier Miete, Strom, Handy, Versicherungen und Abos ein. '
                'Die App erinnert euch an Kündigungsfristen.',
          );
        }
        final total = list.fold<int>(0, (s, c) => s + c.monthlyCents);
        final now = DateTime.now();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                title: const Text('Fixkosten pro Monat'),
                trailing: Text(
                  formatCents(total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final c in list)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.description_outlined),
                ),
                title: Text(c.name),
                subtitle: Text(
                  [
                    if (c.provider.isNotEmpty) c.provider,
                    '${formatCents(c.costCents)} ${c.interval.label}',
                    if (c.cancelBy != null)
                      c.cancelBy!.isBefore(dateOnly(now))
                          ? 'Frist vorbei (${formatShortDate(c.cancelBy!)})'
                          : 'kündigen bis ${formatShortDate(c.cancelBy!)}',
                  ].join(' · '),
                ),
                trailing:
                    c.cancelBy != null &&
                        upcomingDeadlines([c], now: now).isNotEmpty
                    ? Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onTap: () => _open(context, c),
              ),
          ],
        );
      }),
    );
  }

  void _open(BuildContext context, Contract? c) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ContractEditScreen(householdId: householdId, contract: c),
    ),
  );
}

class ContractEditScreen extends ConsumerStatefulWidget {
  const ContractEditScreen({
    super.key,
    required this.householdId,
    this.contract,
  });

  final String householdId;
  final Contract? contract;

  @override
  ConsumerState<ContractEditScreen> createState() => _ContractEditScreenState();
}

class _ContractEditScreenState extends ConsumerState<ContractEditScreen> {
  late final _name = TextEditingController(text: widget.contract?.name);
  late final _provider = TextEditingController(text: widget.contract?.provider);
  late final _cost = TextEditingController(
    text: widget.contract == null
        ? ''
        : formatCents(widget.contract!.costCents).replaceAll(' €', ''),
  );
  late final _note = TextEditingController(text: widget.contract?.note);
  late BillingInterval _interval =
      widget.contract?.interval ?? BillingInterval.monthly;
  late DateTime? _cancelBy = widget.contract?.cancelBy;

  @override
  void dispose() {
    for (final c in [_name, _provider, _cost, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final cost = parseCents(_cost.text);
    if (name.isEmpty) return showError(context, 'Bitte gib einen Namen ein.');
    if (cost == null) {
      return showError(context, 'Bitte gib einen Betrag ein, z. B. 12,99.');
    }
    await ref.read(storeProvider(widget.householdId)).save(
      'contracts',
      widget.contract?.id,
      {
        'name': name,
        'provider': _provider.text.trim(),
        'costCents': cost,
        'interval': _interval.name,
        'cancelBy': writeDate(_cancelBy),
        'note': _note.text.trim(),
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contract;
    return EditScaffold(
      title: c == null ? 'Neuer Vertrag' : 'Vertrag bearbeiten',
      onSave: _save,
      onDelete: c == null
          ? null
          : () async {
              if (!await confirmDelete(context, c.name) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await ref
                  .read(storeProvider(widget.householdId))
                  .delete('contracts', c.id);
            },
      children: [
        TextField(
          controller: _name,
          autofocus: c == null,
          decoration: const InputDecoration(
            labelText: 'Was?',
            hintText: 'z. B. Strom, Netflix, Haftpflicht',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        TextField(
          controller: _provider,
          decoration: const InputDecoration(labelText: 'Anbieter (optional)'),
          textCapitalization: TextCapitalization.words,
        ),
        TextField(
          controller: _cost,
          decoration: const InputDecoration(
            labelText: 'Betrag',
            suffixText: '€',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        DropdownButtonFormField<BillingInterval>(
          initialValue: _interval,
          decoration: const InputDecoration(labelText: 'Zahlung'),
          items: [
            for (final i in BillingInterval.values)
              DropdownMenuItem(value: i, child: Text(i.label)),
          ],
          onChanged: (v) => setState(() => _interval = v ?? _interval),
        ),
        DateField(
          label: 'Kündigen bis (optional)',
          value: _cancelBy,
          onChanged: (v) => setState(() => _cancelBy = v),
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Notiz (optional)',
            hintText: 'z. B. Kundennummer, Vertragsnummer',
          ),
          maxLines: null,
        ),
      ],
    );
  }
}
