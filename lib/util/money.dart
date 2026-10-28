/// Beträge werden in Cent als ganze Zahl gespeichert.
String formatCents(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final euros = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }
  final rest = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$grouped,$rest €';
}

/// "12,50", "12.5", "12" oder "1.234,56" → Cent. null bei ungültiger Eingabe.
int? parseCents(String input) {
  var s = input.replaceAll('€', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  final value = double.tryParse(s);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}
