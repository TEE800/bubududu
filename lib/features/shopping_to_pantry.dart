import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'pantry.dart';

/// Abgehakte Einkäufe landen in den Vorräten: neu angelegt oder, wenn es das
/// Produkt schon gibt, mit erhöhter Anzahl.
///
/// Am Einkaufseintrag steht unter 'pantryUndo', was geändert wurde, damit
/// "Wieder offen" alles zurücknimmt.

/// Vergleichsschlüssel für Produktnamen: klein, Umlaute ausgeschrieben, ohne
/// Satzzeichen und doppelte Leerzeichen ("Haferflocken " == "haferflocken").
String productKey(String name) {
  var s = name.toLowerCase().trim();
  const umlauts = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};
  umlauts.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return s;
}

/// Grober Wortstamm, damit "Tomate" und "Tomaten" oder "Ei" und "Eier"
/// zusammenpassen.
String _stem(String key) {
  for (final end in const ['er', 'en', 'n', 'e', 's']) {
    if (key.length > end.length + 1 && key.endsWith(end)) {
      return key.substring(0, key.length - end.length);
    }
  }
  return key;
}

// Mengenangaben, die "so viele Stück" bedeuten: "3 Eier", "2x Milch",
// "2 Packungen Nudeln".
final _countPrefix = RegExp(
  r'^(\d{1,3})\s*(?:x|×|stk\.?|stück|st\.?|packungen|packung|pck\.?|'
  r'pkg\.?|flaschen|flasche|dosen|dose|gläser|glas|becher|tüten|tüte|'
  r'beutel|rollen|rolle|kisten|kiste|tafeln|tafel)?\s+(.+)$',
  caseSensitive: false,
);

// Gewichte und Rezeptmengen zählen als eine Packung: "500 g Mehl".
final _measurePrefix = RegExp(
  r'^\d+(?:[.,]\d+)?\s*(?:g|gr|kg|mg|ml|cl|dl|l|liter|el|tl|prisen?|bund|'
  r'zehen?|scheiben?|msp)\.?\s+(.+)$',
  caseSensitive: false,
);

// Mengen hinten dran: "Milch x2", "Milch (2)", "Milch 2x".
final _countSuffix = RegExp(
  r'^(.+?)\s+(?:x\s*(\d{1,3})|\((\d{1,3})\)|(\d{1,3})\s*x)$',
  caseSensitive: false,
);

/// Zerlegt einen Eintrag der Einkaufsliste in Produktname und Anzahl.
({String name, int amount}) parsePurchase(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final measure = _measurePrefix.firstMatch(t);
  if (measure != null) return (name: measure.group(1)!.trim(), amount: 1);
  final count = _countPrefix.firstMatch(t);
  if (count != null) {
    final n = int.parse(count.group(1)!);
    if (n > 0) return (name: count.group(2)!.trim(), amount: n);
  }
  final suffix = _countSuffix.firstMatch(t);
  if (suffix != null) {
    final n = int.parse(suffix.group(2) ?? suffix.group(3) ?? suffix.group(4)!);
    if (n > 0) return (name: suffix.group(1)!.trim(), amount: n);
  }
  return (name: t, amount: 1);
}

/// Wie viele Stück eine eigene Mengenangabe bedeutet: "2" und "2 Packungen"
/// sind 2, Gewichte wie "500 g" zählen als eine Packung.
int amountCount(String amount) {
  final a = amount.trim();
  if (a.isEmpty) return 1;
  final m = RegExp(r'^(\d{1,3})(?:\s*[.,]\d+)?').firstMatch(a);
  if (m == null) return 1;
  // Gewicht oder Rezeptmenge? Dann eine Packung.
  if (_measurePrefix.hasMatch('$a x')) return 1;
  if (_countPrefix.hasMatch('$a x')) {
    final n = int.parse(m.group(1)!);
    return n > 0 ? n : 1;
  }
  return 1;
}

/// Zerlegt Eintrag und eigene Mengenangabe. Steht eine Menge im eigenen Feld,
/// gilt sie statt einer Zahl im Namen.
({String name, int amount}) parseShoppingItem(String text, String amount) {
  final parsed = parsePurchase(text);
  if (amount.trim().isEmpty) return parsed;
  return (name: parsed.name, amount: amountCount(amount));
}

/// Der passende Vorrat zu [name], erst genau, dann über den Wortstamm.
PantryItem? findPantryMatch(List<PantryItem> pantry, String name) {
  final key = productKey(name);
  if (key.isEmpty) return null;
  for (final p in pantry) {
    if (productKey(p.name) == key) return p;
  }
  final stem = _stem(key);
  for (final p in pantry) {
    if (_stem(productKey(p.name)) == stem) return p;
  }
  return null;
}

/// Was ein abgehakter Einkauf in den Vorräten ändert.
class PantryPurchase {
  const PantryPurchase({
    required this.pantryId,
    required this.created,
    required this.name,
    required this.count,
    required this.fields,
    required this.before,
  });

  /// null: neu anlegen.
  final String? pantryId;
  final bool created;
  final String name;

  /// Anzahl danach.
  final int count;

  /// Felder zum Speichern (neu oder Änderung).
  final Map<String, dynamic> fields;

  /// Vorheriger Stand zum Zurücknehmen (bei [created] leer).
  final Map<String, dynamic> before;
}

/// Plant, was mit einem abgehakten Eintrag [text] passiert.
/// [pantryId] verknüpft automatisch auf die Liste gesetzte Vorräte direkt.
PantryPurchase planPurchase(
  List<PantryItem> pantry,
  String text,
  DateTime now, {
  String? pantryId,
  String amount = '',
}) {
  final parsed = parseShoppingItem(text, amount);
  final match =
      (pantryId == null
          ? null
          : pantry.where((p) => p.id == pantryId).firstOrNull) ??
      findPantryMatch(pantry, parsed.name);
  if (match == null) {
    final name = parsed.name.isEmpty
        ? parsed.name
        : parsed.name[0].toUpperCase() + parsed.name.substring(1);
    return PantryPurchase(
      pantryId: null,
      created: true,
      name: name,
      count: parsed.amount,
      fields: {
        'name': name,
        'place': '',
        'level': StockLevel.full.name,
        'count': parsed.amount,
      },
      before: const {},
    );
  }
  // Ohne bisherige Anzahl: leer zählt als 0, sonst als 1.
  final had = match.count ?? (match.levelAt(now) == StockLevel.empty ? 0 : 1);
  final count = had + parsed.amount;
  return PantryPurchase(
    pantryId: match.id,
    created: false,
    name: match.name,
    count: count,
    fields: {
      'count': count,
      if (match.countsUses)
        ...match.usesUpdate(match.uses!.toDouble(), now)
      else
        'level': StockLevel.full.name,
    },
    before: {
      'count': match.count,
      'level': match.level.name,
      if (match.countsUses) ...{
        'usesLeft': match.usesLeft,
        'usesAt': match.usesAt == null
            ? null
            : Timestamp.fromDate(match.usesAt!),
      },
    },
  );
}

/// Automatisch auf die Liste gesetzte Vorräte haben die ID `auto-<Vorrat>`.
String? _linkedPantryId(String shoppingId) =>
    shoppingId.startsWith('auto-') ? shoppingId.substring(5) : null;

/// Bucht einen abgehakten Eintrag in die Vorräte und merkt sich am Eintrag,
/// wie es rückgängig geht.
PantryPurchase checkOffIntoPantry(
  HouseholdStore store,
  List<PantryItem> pantry,
  ShoppingItem item,
) {
  final plan = planPurchase(
    pantry,
    item.text,
    DateTime.now(),
    pantryId: _linkedPantryId(item.id),
    amount: item.amount,
  );
  final id = plan.pantryId ?? store.newId('pantry');
  if (plan.created) {
    store.add('pantry', plan.fields, id: id);
  } else {
    store.update('pantry', id, plan.fields);
  }
  store.update('shoppingItems', item.id, {
    'done': true,
    'pantryUndo': {'id': id, 'created': plan.created, 'before': plan.before},
  });
  return plan;
}

/// "Wieder offen": nimmt die Änderung an den Vorräten zurück.
void reopenFromPantry(HouseholdStore store, ShoppingItem item) {
  final undo = item.pantryUndo;
  if (undo != null) {
    final id = undo['id'] as String?;
    if (id != null) {
      if (undo['created'] == true) {
        store.delete('pantry', id);
      } else {
        final before = undo['before'];
        if (before is Map && before.isNotEmpty) {
          store.update('pantry', id, Map<String, dynamic>.from(before));
        }
      }
    }
  }
  store.update('shoppingItems', item.id, {
    'done': false,
    'pantryUndo': FieldValue.delete(),
  });
}
