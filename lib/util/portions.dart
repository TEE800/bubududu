/// Rechnet Zutatenmengen auf eine andere Anzahl Portionen um.
///
/// Zutaten sind freier Text wie "500 g Hackfleisch" oder "1 ½ TL Salz".
/// Umgerechnet wird nur die Menge am Zeilenanfang; Zeilen ohne Zahl
/// ("etwas Salz", "Prise Pfeffer") bleiben, wie sie sind.
library;

const _fractionChars = {
  '½': 0.5,
  '¼': 0.25,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '⅛': 0.125,
};

const _num =
    r'(?:\d+\s+\d+/\d+|\d+/\d+|\d+\s*[½¼¾⅓⅔⅛]|[½¼¾⅓⅔⅛]|\d+(?:[.,]\d+)?)';

/// Optional "ca.", dann eine Menge oder ein Bereich ("2-3", "2 bis 3").
final _leading = RegExp(
  '^((?:ca\\.?|etwa|circa)\\s*)?($_num)'
  '(\\s*(?:-|–|bis)\\s*($_num))?',
  caseSensitive: false,
);

double? _parse(String s) {
  s = s.trim();
  final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
  if (mixed != null) {
    final d = int.parse(mixed[3]!);
    if (d == 0) return null;
    return int.parse(mixed[1]!) + int.parse(mixed[2]!) / d;
  }
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
  if (frac != null) {
    final d = int.parse(frac[2]!);
    if (d == 0) return null;
    return int.parse(frac[1]!) / d;
  }
  final last = s.isEmpty ? '' : s[s.length - 1];
  if (_fractionChars.containsKey(last)) {
    final whole = s.substring(0, s.length - 1).trim();
    return (whole.isEmpty ? 0 : int.parse(whole)) + _fractionChars[last]!;
  }
  return double.tryParse(s.replaceAll(',', '.'));
}

/// Schreibt eine Menge so, wie man sie im Rezept lesen würde: kleine Mengen
/// als Bruch (½, ¼, ¾, ⅓, ⅔), sonst höchstens eine Nachkommastelle.
String formatAmount(double v) {
  if (v <= 0) return '0';
  if (v < 10) {
    final whole = v.floor();
    final rest = v - whole;
    const nice = [
      (0.0, ''),
      (0.25, '¼'),
      (1 / 3, '⅓'),
      (0.5, '½'),
      (2 / 3, '⅔'),
      (0.75, '¾'),
      (1.0, ''),
    ];
    for (final (value, sym) in nice) {
      if ((rest - value).abs() < 0.02) {
        final w = value == 1.0 ? whole + 1 : whole;
        if (sym.isEmpty) return '$w';
        return w == 0 ? sym : '$w $sym';
      }
    }
    final r = (v * 10).round() / 10;
    return _decimal(r);
  }
  // Größere Mengen (Gramm, Milliliter) auf glatte Werte runden.
  if (v < 100) return '${v.round()}';
  if (v < 1000) return '${(v / 5).round() * 5}';
  return '${(v / 10).round() * 10}';
}

String _decimal(double v) {
  if (v == v.roundToDouble()) return '${v.round()}';
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Rechnet eine Zutatenzeile mit dem Faktor [factor] um
/// (z. B. 2.0 für doppelte Menge).
String scaleIngredient(String line, double factor) {
  if (factor == 1) return line;
  final m = _leading.firstMatch(line);
  if (m == null) return line;
  final a = _parse(m[2]!);
  if (a == null) return line;
  final prefix = m[1] ?? '';
  var out = '$prefix${formatAmount(a * factor)}';
  if (m[4] != null) {
    final b = _parse(m[4]!);
    if (b == null) return line;
    out += '–${formatAmount(b * factor)}';
  }
  return out + line.substring(m.end);
}

/// "1 Portion", "2 Portionen".
String portionsLabel(int n) => n == 1 ? '1 Portion' : '$n Portionen';
