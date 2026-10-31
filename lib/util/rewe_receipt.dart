/// Liest einen Rewe-eBon (Text aus dem PDF) aus.
///
/// Rewe bietet keine Schnittstelle an. Den digitalen Kassenbon kann man aber
/// in der Rewe-App als PDF teilen; sein Text sieht aus wie ein normaler Bon:
///
///     SCHINKENWUERFEL                  4,98 B
///                  2 Stk x    2,49
///     JA! MARKENBUTTER                 1,19 B
///      SUMME                   EUR     30,40
///       29.10.2026          15:06         Bon-Nr.:7983
///       Mit diesem Einkauf hast du 1,61 EUR
///     Aktuelles Bonus-Guthaben: 164,96 EUR
library;

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.cents,
    this.quantity = 1,
  });

  /// So wie auf dem Bon, z. B. "JA! MARKENBUTTER".
  final String name;

  /// Preis der ganzen Zeile (bei "2 Stk x 2,49" also 4,98); negativ bei
  /// Rabatt oder Leergut.
  final int cents;
  final int quantity;

  /// Pfand, Leergut, Rabatte: keine Produkte für Vorräte oder Liste.
  bool get isProduct =>
      cents > 0 &&
      !RegExp(r'PFAND|LEERGUT|RABATT', caseSensitive: false).hasMatch(name);

  /// Lesbarer Name: "Ja! Markenbutter".
  String get displayName => prettyName(name);
}

class ReweReceipt {
  const ReweReceipt({
    required this.lines,
    required this.totalCents,
    this.date,
    this.bonusEarnedCents,
    this.bonusBalanceCents,
  });

  final List<ReceiptLine> lines;
  final int totalCents;
  final DateTime? date;

  /// Mit diesem Einkauf gesammeltes Rewe-Bonus-Guthaben.
  final int? bonusEarnedCents;

  /// Bonus-Guthaben nach diesem Einkauf.
  final int? bonusBalanceCents;

  List<ReceiptLine> get products => [
    for (final l in lines)
      if (l.isProduct) l,
  ];
}

/// "4,98" → 498, "-0,25" → -25.
int? parseEuroCents(String text) {
  final m = RegExp(r'^(-)?(\d+),(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final cents = int.parse(m[2]!) * 100 + int.parse(m[3]!);
  return m[1] == null ? cents : -cents;
}

final _item = RegExp(r'^\s*(\S.*?)\s+(-?\d+,\d{2})\s+[A-Z]\s*\*?\s*$');
final _qty = RegExp(r'^\s*(\d+)\s*Stk\s*x', caseSensitive: false);
final _sum = RegExp(r'SUMME\s+EUR\s+(-?\d+,\d{2})');
final _date = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})');
final _earned = RegExp(r'hast du\s+(\d+,\d{2})\s*EUR', caseSensitive: false);
final _balance = RegExp(
  r'Bonus-Guthaben:\s*(\d+,\d{2})\s*EUR',
  caseSensitive: false,
);

/// Wirft [FormatException], wenn der Text nicht nach einem Rewe-Bon aussieht.
ReweReceipt parseReweReceipt(String text) {
  final lines = <ReceiptLine>[];
  int? total;
  for (final raw in text.split(RegExp(r'\r\n|\r|\n'))) {
    if (total == null) {
      final sum = _sum.firstMatch(raw);
      if (sum != null) {
        total = parseEuroCents(sum[1]!);
        continue;
      }
      final qty = _qty.firstMatch(raw);
      if (qty != null && lines.isNotEmpty) {
        final last = lines.removeLast();
        lines.add(
          ReceiptLine(
            name: last.name,
            cents: last.cents,
            quantity: int.parse(qty[1]!),
          ),
        );
        continue;
      }
      final item = _item.firstMatch(raw);
      if (item != null) {
        lines.add(
          ReceiptLine(name: item[1]!.trim(), cents: parseEuroCents(item[2]!)!),
        );
      }
    }
  }
  if (total == null || lines.isEmpty) {
    throw const FormatException('Das sieht nicht nach einem Rewe-eBon aus.');
  }

  final d = _date.firstMatch(text);
  return ReweReceipt(
    lines: lines,
    totalCents: total,
    date: d == null
        ? null
        : DateTime(
            int.parse(d[3]!),
            int.parse(d[2]!),
            int.parse(d[1]!),
            int.parse(d[4]!),
            int.parse(d[5]!),
          ),
    bonusEarnedCents: _cents(_earned.firstMatch(text)),
    bonusBalanceCents: _cents(_balance.firstMatch(text)),
  );
}

int? _cents(RegExpMatch? m) => m == null ? null : parseEuroCents(m[1]!);

/// "JA! MARKENBUTTER" → "Ja! Markenbutter", "H-MILCH GVO-FREI" →
/// "H-Milch Gvo-Frei". Umschreibungen wie "UE" bleiben, weil "QUELLE" sonst
/// zu "Qülle" würde.
String prettyName(String name) => name
    .toLowerCase()
    .replaceAllMapped(
      RegExp(r'(^|[\s\-./!])([a-zäöü])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    )
    .trim();

/// Kleinbuchstaben ohne Umlaute und Satzzeichen: "Brötchen" → "broetchen".
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

/// Ob ein Eintrag wie "Butter" oder "Brötchen" zu einer Bon-Zeile wie
/// "JA! MARKENBUTTER" oder "WEIZENBROETCH." passt. Bon-Namen sind oft
/// abgekürzt, deshalb reicht ein gemeinsames Stück von 6 Buchstaben (bei
/// kürzeren Wörtern das ganze Wort).
bool receiptMatches(String entry, String receiptName) {
  final bon = _norm(receiptName).replaceAll(' ', '');
  for (final word in _norm(entry).split(' ')) {
    if (word.length < 3) continue;
    if (bon.contains(word)) return true;
    if (word.length > 6) {
      for (var i = 0; i + 6 <= word.length; i++) {
        if (bon.contains(word.substring(i, i + 6))) return true;
      }
    }
  }
  return false;
}

/// Die erste Bon-Zeile, die zu [entry] passt, oder null.
ReceiptLine? matchingLine(String entry, List<ReceiptLine> products) =>
    products.where((l) => receiptMatches(entry, l.name)).firstOrNull;
