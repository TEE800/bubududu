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

/// "2.2431330000" (Original) oder "2,243133" / "1.200,50" (nach Excel auf
/// Deutsch). Mehrere Punkte ohne Komma sind nicht eindeutig und zählen nicht.
double? _number(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s);
}

/// Zeilen, die Stücke aus dem Depot nehmen (Verkauf, Ausbuchung, Fälligkeit,
/// Übertrag weg). Nur nötig, wenn "shares" dort ohne Minus steht.
bool _isOutgoing(String type) => const [
  'SELL',
  'WRITE_OFF',
  'OUTBOUND',
  'OUTGOING',
  'REMOVAL',
  'MATURITY',
  'REDEMPTION',
  'EXPIR',
  'DELIST',
].any(type.contains);

/// In CASH-Zeilen (z. B. Dividenden) steht in "shares" nur der Bestand zur Info.
bool _changesShares(String category) => category != 'CASH';

/// Rechnet aus dem Transaktionsexport die aktuellen Positionen aus.
/// Wirft [FormatException], wenn die Datei kein Trade-Republic-Export ist.
List<DepotPosition> parseTradeRepublicCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final delimiter = [',', ';', '\t'].reduce(
    (a, b) =>
        b.allMatches(firstLine).length > a.allMatches(firstLine).length ? b : a,
  );
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
  // Bei gleicher Zeit zuerst Ausbuchungen, damit ein Umtausch (alte ISIN
  // raus, neue rein) den Einstandswert weitergeben kann.
  bool isOut(List<String> r) => at(r, iShares).startsWith('-');
  if (iDate >= 0) {
    data.sort((a, b) {
      final byDate = at(a, iDate).compareTo(at(b, iDate));
      if (byDate != 0) return byDate;
      return (isOut(a) ? 0 : 1) - (isOut(b) ? 0 : 1);
    });
  }
  final iDay = col('date') >= 0 ? col('date') : iDate;

  final shares = <String, double>{};
  final invested = <String, double>{};
  final names = <String, String>{};
  final classes = <String, String>{};
  final prices = <String, double>{};
  // Kapitalmaßnahmen ohne Geldfluss (Umtausch, Split): was die alten Stücke
  // gekostet haben und wert waren, geht an die neuen Stücke desselben Tages.
  // Die alten Stücke behalten ihren Einstand, bis sie ganz weg sind; so geht
  // auch ein späterer Storno der Ausbuchung nicht verloren.
  final released = <String, ({String isin, double invested, double value})>{};

  for (final r in data) {
    final category = at(r, iCategory).toUpperCase();
    if (!_changesShares(category)) continue;
    final isin = at(r, iSymbol);
    final qty = _number(at(r, iShares));
    if (isin.isEmpty || qty == null || qty == 0) continue;

    var type = at(r, iType).toUpperCase();
    final cancelled = type.endsWith('_CANCELLED');
    if (cancelled) {
      type = type.substring(0, type.length - '_CANCELLED'.length);
    }
    final outgoing = _isOutgoing(type);
    // Ein Minus in "shares" gilt immer (Stücke gehen raus). Ohne Minus
    // entscheidet die Art der Buchung; ein Storno dreht sie um.
    final double delta;
    if (qty < 0) {
      delta = qty;
    } else {
      delta = (outgoing != cancelled) ? -qty : qty;
    }
    final amount = _number(at(r, iAmount)) ?? 0;
    final cost = amount.abs() + (_number(at(r, iFee)) ?? 0).abs();

    final held = shares[isin] ?? 0;
    final paid = invested[isin] ?? 0;
    final moneyless =
        category != 'TRADING' && amount == 0 && cost == 0 && !cancelled;
    final group = '${at(r, iDay)}|$type';
    if (moneyless && delta < 0 && held > 0) {
      // Alte Stücke gehen raus: Einstand und Wert für die neuen merken.
      final part = (-delta / held).clamp(0.0, 1.0);
      released[group] = (
        isin: isin,
        invested: paid * part,
        value: -delta * (prices[isin] ?? 0),
      );
    } else if (moneyless &&
        delta > 0 &&
        released[group] != null &&
        released[group]!.isin != isin) {
      final from = released.remove(group)!;
      final source = invested[from.isin] ?? 0;
      invested[from.isin] = source - from.invested;
      invested[isin] = paid + from.invested;
      if (from.value > 0) {
        prices[isin] =
            (from.value + held * (prices[isin] ?? 0)) / (held + delta);
      }
    } else if (delta > 0) {
      invested[isin] = paid + cost;
    } else if (cancelled && !outgoing) {
      // Storno eines Kaufs: Kaufbetrag wieder abziehen.
      invested[isin] = paid - cost;
    } else if (held > 0 && !cancelled) {
      invested[isin] = paid * ((held + delta) / held).clamp(0, 1);
    }
    // Gratisaktien ändern nur die Stückzahl, nicht den Einstandswert.
    shares[isin] = held + delta;

    final name = at(r, iName);
    if (name.isNotEmpty) names[isin] = name;
    final assetClass = at(r, iClass);
    if (assetClass.isNotEmpty) classes[isin] = assetClass;
    final price = _number(at(r, iPrice));
    if (category == 'TRADING' && price != null && price > 0) {
      prices[isin] = price;
    }
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
