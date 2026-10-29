/// Liest den Transaktionsexport von Trade Republic (CSV) und rechnet daraus
/// die aktuellen Depot-Positionen aus.
///
/// Den Export gibt es in der Trade-Republic-App unter
/// Profil → Abrechnungen/Dokumente → Transaktionsexport. Kopfzeile:
/// "datetime","date","account_type","category","type","asset_class","name",
/// "symbol","shares","price","amount","fee","tax","currency",...
/// "symbol" ist die ISIN. Relevant sind nur Zeilen mit Stückzahl aus den
/// Kategorien außer CASH (TRADING, DELIVERY, CORPORATE_ACTION, ...); bei CASH-Zeilen
/// (z. B. Dividenden) steht in "shares" nur der Bestand zur Info.
library;

class DepotPosition {
  const DepotPosition({
    required this.isin,
    required this.name,
    required this.shares,
    required this.invested,
    this.lastPrice,
    this.symbol,
    this.assetClass = '',
  });

  final String isin;
  final String name;
  final double shares;

  /// Einstandswert in Euro (Kaufbeträge inkl. Gebühren, bei Verkäufen anteilig).
  final double invested;

  /// Kurs aus der letzten Transaktion, falls kein Live-Kurs verfügbar ist.
  final double? lastPrice;

  /// Kürzel bei Yahoo Finance (z. B. "SAP.DE") für Live-Kurse.
  final String? symbol;
  final String assetClass;

  DepotPosition copyWith({
    String? name,
    double? shares,
    double? invested,
    double? lastPrice,
    String? symbol,
  }) => DepotPosition(
    isin: isin,
    name: name ?? this.name,
    shares: shares ?? this.shares,
    invested: invested ?? this.invested,
    lastPrice: lastPrice ?? this.lastPrice,
    symbol: symbol ?? this.symbol,
    assetClass: assetClass,
  );

  Map<String, dynamic> toMap() => {
    'isin': isin,
    'name': name,
    'shares': shares,
    'invested': invested,
    'lastPrice': ?lastPrice,
    'symbol': ?symbol,
    'assetClass': assetClass,
  };

  static DepotPosition? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final isin = raw['isin'];
    if (isin is! String || isin.isEmpty) return null;
    return DepotPosition(
      isin: isin,
      name: raw['name'] as String? ?? isin,
      shares: (raw['shares'] as num?)?.toDouble() ?? 0,
      invested: (raw['invested'] as num?)?.toDouble() ?? 0,
      lastPrice: (raw['lastPrice'] as num?)?.toDouble(),
      symbol: raw['symbol'] as String?,
      assetClass: raw['assetClass'] as String? ?? '',
    );
  }
}

/// Zerlegt eine CSV-Datei in Zeilen und Felder (mit "…"-Anführungszeichen).
List<List<String>> parseCsv(String text, {String delimiter = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString());
  if (row.any((f) => f.isNotEmpty)) rows.add(row);
  return rows;
}

/// "2.2431330000" (Original) oder "2,243133" (nach Excel auf Deutsch).
double? _number(String raw, {required bool german}) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (german) s = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s);
}

/// Zeilen, die Stücke aus dem Depot nehmen (Verkauf, Ausbuchung, Übertrag weg).
bool _isOutgoing(String type) =>
    type.contains('SELL') ||
    type.contains('WRITE_OFF') ||
    type.contains('OUTBOUND') ||
    type.contains('OUTGOING') ||
    type.contains('REMOVAL');

/// In CASH-Zeilen (z. B. Dividenden) steht in "shares" nur der Bestand zur Info.
bool _changesShares(String category) => category != 'CASH';

/// Rechnet aus dem Transaktionsexport die aktuellen Positionen aus.
/// Wirft [FormatException], wenn die Datei kein Trade-Republic-Export ist.
List<DepotPosition> parseTradeRepublicCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final delimiter =
      ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
      ? ';'
      : ',';
  final german = delimiter == ';';
  final rows = parseCsv(text, delimiter: delimiter);
  if (rows.isEmpty) {
    throw const FormatException('Die Datei ist leer.');
  }
  final header = [for (final h in rows.first) h.trim().toLowerCase()];
  int col(String name) => header.indexOf(name);
  final iSymbol = col('symbol');
  final iShares = col('shares');
  final iType = col('type');
  final iCategory = col('category');
  if (iSymbol < 0 || iShares < 0 || iType < 0 || iCategory < 0) {
    throw const FormatException(
      'Das ist kein Transaktionsexport von Trade Republic.',
    );
  }
  final iName = col('name');
  final iDate = col('datetime') >= 0 ? col('datetime') : col('date');
  final iPrice = col('price');
  final iAmount = col('amount');
  final iFee = col('fee');
  final iClass = col('asset_class');

  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';

  final data = rows.skip(1).toList();
  // Der Export ist meist neueste zuerst; wir rechnen von alt nach neu.
  if (iDate >= 0) {
    data.sort((a, b) => at(a, iDate).compareTo(at(b, iDate)));
  }

  final shares = <String, double>{};
  final invested = <String, double>{};
  final names = <String, String>{};
  final classes = <String, String>{};
  final prices = <String, double>{};

  for (final r in data) {
    final category = at(r, iCategory).toUpperCase();
    if (!_changesShares(category)) continue;
    final isin = at(r, iSymbol);
    final qty = _number(at(r, iShares), german: german);
    if (isin.isEmpty || qty == null || qty == 0) continue;

    var type = at(r, iType).toUpperCase();
    var sign = 1.0;
    if (type.endsWith('_CANCELLED')) {
      sign = -1;
      type = type.substring(0, type.length - '_CANCELLED'.length);
    }
    final direction = qty < 0 || _isOutgoing(type) ? -1.0 : 1.0;
    final delta = qty.abs() * direction * sign;
    final cost =
        (_number(at(r, iAmount), german: german) ?? 0).abs() +
        (_number(at(r, iFee), german: german) ?? 0).abs();

    final held = shares[isin] ?? 0;
    final paid = invested[isin] ?? 0;
    if (delta > 0) {
      invested[isin] = paid + cost;
    } else if (direction > 0) {
      // Storno eines Kaufs: Kaufbetrag wieder abziehen.
      invested[isin] = paid - cost;
    } else if (held > 0) {
      invested[isin] = paid * ((held + delta) / held).clamp(0, 1);
    }
    shares[isin] = held + delta;

    final name = at(r, iName);
    if (name.isNotEmpty) names[isin] = name;
    final assetClass = at(r, iClass);
    if (assetClass.isNotEmpty) classes[isin] = assetClass;
    final price = _number(at(r, iPrice), german: german);
    if (price != null && price > 0) prices[isin] = price;
  }

  final result = [
    for (final e in shares.entries)
      if (e.value > 1e-6)
        DepotPosition(
          isin: e.key,
          name: names[e.key] ?? e.key,
          shares: e.value,
          invested: (invested[e.key] ?? 0).clamp(0, double.infinity),
          lastPrice: prices[e.key],
          assetClass: classes[e.key] ?? '',
        ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}
