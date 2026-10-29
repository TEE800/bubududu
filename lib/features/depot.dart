import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/offline.dart';
import '../data/store.dart';
import '../services/stocks.dart';
import '../services/weather.dart' show httpClientProvider;
import '../util/dates.dart';
import '../util/trade_republic.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';

/// Mein Depot: Positionen aus dem Trade-Republic-Transaktionsexport.
/// Liegt privat in users/{uid}.depot = {positions: [...], importedAt}
/// und ist damit nur für die Person selbst sichtbar.
typedef Depot = ({List<DepotPosition> positions, DateTime? importedAt});

final depotProvider = StreamProvider<Depot>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid.isEmpty) {
    return Stream.value((positions: const <DepotPosition>[], importedAt: null));
  }
  return ref.watch(firestoreProvider).doc('users/$uid').snapshots().map((s) {
    final depot = s.data()?['depot'] as Map? ?? const {};
    return (
      positions: [
        for (final p in depot['positions'] as List? ?? const [])
          ?DepotPosition.fromMap(p),
      ],
      importedAt: readDate(depot['importedAt']),
    );
  });
});

Future<void> saveDepot(
  FirebaseFirestore db,
  String uid,
  List<DepotPosition> positions, {
  bool imported = false,
}) => writeInBackground(
  db.doc('users/$uid').set({
    'depot': {
      'positions': [for (final p in positions) p.toMap()],
      if (imported) 'importedAt': FieldValue.serverTimestamp(),
    },
  }, SetOptions(merge: true)),
);

/// Kurs in Euro (Fremdwährungen über den Yahoo-Wechselkurs umgerechnet).
typedef EuroQuote = ({double price, double changePercent});

final euroQuoteProvider = FutureProvider.family<EuroQuote, String>((
  ref,
  symbol,
) async {
  final q = await ref.watch(stockQuoteProvider(symbol).future);
  var price = q.price;
  var currency = q.currency;
  if (currency == 'GBp' || currency == 'GBX') {
    price /= 100;
    currency = 'GBP';
  }
  if (currency != 'EUR' && currency.isNotEmpty) {
    final fx = await ref.watch(stockQuoteProvider('EUR$currency=X').future);
    if (fx.price > 0) price /= fx.price;
  }
  return (price: price, changePercent: q.changePercent);
});

/// Sucht zur ISIN das Yahoo-Kürzel, am liebsten an einer deutschen Börse (Euro).
Future<String?> resolveSymbol(http.Client client, String isin) async {
  final results = await searchStocks(client, isin);
  if (results.isEmpty) return null;
  for (final suffix in ['.DE', '.F', '.SG', '.MU']) {
    final hit = results.where((r) => r.symbol.endsWith(suffix)).firstOrNull;
    if (hit != null) return hit.symbol;
  }
  return results.first.symbol;
}

/// Aktueller Wert einer Position und Tagesveränderung, falls bekannt.
typedef PositionValue = ({double value, double? dayChange, bool live});

PositionValue positionValue(DepotPosition p, AsyncValue<EuroQuote>? quote) {
  final q = quote?.value;
  if (q != null) {
    final value = p.shares * q.price;
    final prev = value / (1 + q.changePercent / 100);
    return (value: value, dayChange: value - prev, live: true);
  }
  return (value: p.shares * (p.lastPrice ?? 0), dayChange: null, live: false);
}

typedef DepotTotal = ({
  double value,
  double invested,
  double dayChange,
  bool loading,
});

final depotTotalProvider = Provider<DepotTotal>((ref) {
  final positions = ref.watch(depotProvider).value?.positions ?? const [];
  var value = 0.0, invested = 0.0, day = 0.0;
  var loading = false;
  for (final p in positions) {
    final quote = p.symbol == null
        ? null
        : ref.watch(euroQuoteProvider(p.symbol!));
    if (quote?.isLoading ?? false) loading = true;
    final v = positionValue(p, quote);
    value += v.value;
    invested += p.invested;
    day += v.dayChange ?? 0;
  }
  return (value: value, invested: invested, dayChange: day, loading: loading);
});

String formatEuro(double amount) {
  final cents = (amount * 100).round();
  final negative = cents < 0;
  final abs = cents.abs();
  final euros = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }
  return '${negative ? '-' : ''}$grouped,${(abs % 100).toString().padLeft(2, '0')} €';
}

String formatSigned(double amount) =>
    '${amount >= 0 ? '+' : ''}${formatEuro(amount)}';

String formatShares(double shares) {
  var s = shares.toStringAsFixed(6);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

Color gainColor(BuildContext context, double amount) =>
    amount >= 0 ? Colors.green.shade700 : Theme.of(context).colorScheme.error;

class DepotScreen extends ConsumerStatefulWidget {
  const DepotScreen({super.key});

  @override
  ConsumerState<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends ConsumerState<DepotScreen> {
  bool _busy = false;

  Future<void> _import() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Transaktionsexport von Trade Republic wählen',
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final parsed = parseTradeRepublicCsv(text);
      if (parsed.isEmpty) {
        throw const FormatException('In der Datei sind keine Wertpapiere.');
      }
      // Bekannte Kürzel behalten, neue über die ISIN suchen.
      final old = {
        for (final p in ref.read(depotProvider).value?.positions ?? const [])
          p.isin: p,
      };
      final client = ref.read(httpClientProvider);
      final positions = await Future.wait([
        for (final p in parsed)
          if (old[p.isin]?.symbol != null)
            Future.value(p.copyWith(symbol: old[p.isin]!.symbol))
          else
            resolveSymbol(
              client,
              p.isin,
            ).catchError((_) => null).then((s) => p.copyWith(symbol: s)),
      ]);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Depot übernehmen?'),
          content: Text(
            '${positions.length} Positionen gefunden. '
            'Dein bisheriges Depot in der App wird damit ersetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await saveDepot(
        ref.read(firestoreProvider),
        ref.read(uidProvider),
        positions,
        imported: true,
      );
    } on FormatException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, 'Die Datei konnte nicht gelesen werden.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(DepotPosition? p) async {
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(builder: (_) => _PositionEditScreen(position: p)),
    );
    if (result == null) return;
    final positions = [...?ref.read(depotProvider).value?.positions]
      ..removeWhere((x) => x.isin == (p?.isin ?? result.position?.isin));
    if (result.position != null) positions.add(result.position!);
    positions.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    await saveDepot(
      ref.read(firestoreProvider),
      ref.read(uidProvider),
      positions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final depot = ref.watch(depotProvider);
    final positions = depot.value?.positions ?? const <DepotPosition>[];
    final total = ref.watch(depotTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Depot'),
        actions: [
          IconButton(
            tooltip: 'Trade-Republic-Export importieren',
            icon: const Icon(Icons.upload_file),
            onPressed: _busy ? null : _import,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Position hinzufügen',
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stockQuoteProvider);
          ref.invalidate(euroQuoteProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (positions.isEmpty && !depot.isLoading) ...[
              const EmptyHint(
                icon: Icons.account_balance_wallet_outlined,
                mood: MascotMood.money,
                text:
                    'Hol dir in der Trade-Republic-App unter Profil → '
                    'Abrechnungen den Transaktionsexport (CSV) und importiere '
                    'ihn hier. Du kannst Positionen auch von Hand eintragen.',
              ),
              Center(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export importieren'),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _TotalSummary(total: total),
                ),
              ),
              for (final p in positions)
                _PositionTile(position: p, onTap: () => _edit(p)),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                [
                  'Nur du siehst dein Depot, Bubu nicht.',
                  if (depot.value?.importedAt != null)
                    'Zuletzt importiert am ${formatShortDate(depot.value!.importedAt!)}.',
                  'Kurse kommen von Yahoo Finance und können verzögert sein. '
                      'Ohne Live-Kurs zählt der letzte Kaufkurs.',
                ].join(' '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalSummary extends StatelessWidget {
  const _TotalSummary({required this.total});

  final DepotTotal total;

  @override
  Widget build(BuildContext context) {
    final gain = total.value - total.invested;
    final gainPercent = total.invested == 0 ? 0.0 : gain / total.invested * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gesamtwert', style: Theme.of(context).textTheme.labelLarge),
        Text(
          formatEuro(total.value),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (total.loading) const LinearProgressIndicator(),
        const SizedBox(height: 4),
        Text(
          'Heute ${formatSigned(total.dayChange)}',
          style: TextStyle(color: gainColor(context, total.dayChange)),
        ),
        if (total.invested > 0)
          Text(
            'Seit Kauf ${formatSigned(gain)} '
            '(${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(1).replaceAll('.', ',')} %)',
            style: TextStyle(color: gainColor(context, gain)),
          ),
      ],
    );
  }
}

class _PositionTile extends ConsumerWidget {
  const _PositionTile({required this.position, required this.onTap});

  final DepotPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    final quote = p.symbol == null
        ? null
        : ref.watch(euroQuoteProvider(p.symbol!));
    final v = positionValue(p, quote);
    final change = quote?.value?.changePercent;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(p.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatShares(p.shares)} Stück'
          '${v.live ? '' : ' · kein Live-Kurs'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatEuro(v.value)),
            if (change != null)
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2).replaceAll('.', ',')} %',
                style: TextStyle(color: gainColor(context, change)),
              ),
          ],
        ),
      ),
    );
  }
}

/// position == null heißt löschen.
typedef _EditResult = ({DepotPosition? position});

class _PositionEditScreen extends ConsumerStatefulWidget {
  const _PositionEditScreen({this.position});

  final DepotPosition? position;

  @override
  ConsumerState<_PositionEditScreen> createState() =>
      _PositionEditScreenState();
}

class _PositionEditScreenState extends ConsumerState<_PositionEditScreen> {
  late final _name = TextEditingController(text: widget.position?.name);
  late final _shares = TextEditingController(
    text: widget.position == null ? '' : formatShares(widget.position!.shares),
  );
  late final _invested = TextEditingController(
    text: widget.position == null || widget.position!.invested == 0
        ? ''
        : widget.position!.invested.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _symbol = TextEditingController(text: widget.position?.symbol);
  late final _isin = TextEditingController(text: widget.position?.isin);
  List<StockSearchResult> _results = const [];

  @override
  void dispose() {
    for (final c in [_name, _shares, _invested, _symbol, _isin]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) =>
      double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.'));

  Future<void> _search() async {
    final q = _isin.text.trim().isNotEmpty ? _isin.text : _name.text;
    if (q.trim().isEmpty) return;
    final r = await searchStocks(
      ref.read(httpClientProvider),
      q.trim(),
    ).catchError((_) => <StockSearchResult>[]);
    if (!mounted) return;
    setState(() => _results = r);
    if (r.isEmpty) showError(context, 'Nichts gefunden.');
  }

  void _save() {
    final shares = _num(_shares.text);
    final name = _name.text.trim();
    final symbol = _symbol.text.trim();
    if (name.isEmpty || shares == null || shares <= 0) {
      showError(context, 'Bitte Name und Stückzahl angeben.');
      return;
    }
    final isin = _isin.text.trim().isNotEmpty
        ? _isin.text.trim().toUpperCase()
        : widget.position?.isin ?? (symbol.isNotEmpty ? symbol : name);
    Navigator.pop<_EditResult>(context, (
      position: DepotPosition(
        isin: isin,
        name: name,
        shares: shares,
        invested: _num(_invested.text) ?? 0,
        lastPrice: widget.position?.lastPrice,
        symbol: symbol.isEmpty ? null : symbol,
        assetClass: widget.position?.assetClass ?? '',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return EditScaffold(
      title: widget.position == null ? 'Neue Position' : 'Position',
      onSave: _save,
      onDelete: widget.position == null
          ? null
          : () async {
              if (await confirmDelete(context, widget.position!.name) &&
                  context.mounted) {
                Navigator.pop<_EditResult>(context, (position: null));
              }
            },
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _shares,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Stückzahl'),
        ),
        TextField(
          controller: _invested,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Gezahlt insgesamt (€, freiwillig)',
          ),
        ),
        TextField(
          controller: _isin,
          decoration: const InputDecoration(labelText: 'ISIN (freiwillig)'),
        ),
        TextField(
          controller: _symbol,
          decoration: InputDecoration(
            labelText: 'Kürzel für Live-Kurs',
            hintText: 'z. B. SAP.DE',
            suffixIcon: IconButton(
              tooltip: 'Kürzel suchen',
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
        ),
        for (final r in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r.name),
            subtitle: Text('${r.symbol} · ${r.exchange}'),
            onTap: () => setState(() {
              _symbol.text = r.symbol;
              if (_name.text.trim().isEmpty) _name.text = r.name;
              _results = const [];
            }),
          ),
      ],
    );
  }
}
