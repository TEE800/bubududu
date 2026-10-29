import 'package:bubududu/util/recipe_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rezept mit Überschriften und Schrittnummern', () {
    final d = parseRecipeText('''
Pfannkuchen
Zutaten für 4 Personen
• 250 g Mehl
• 500 ml Milch
• 3 Eier
Zubereitung
1. Mehl, Milch und Eier zu einem glatten
Teig verrühren.
2. In der Pfanne gold-
braun backen.''');
    expect(d.title, 'Pfannkuchen');
    expect(d.ingredients, ['250 g Mehl', '500 ml Milch', '3 Eier']);
    expect(
      d.instructions,
      'Mehl, Milch und Eier zu einem glatten Teig verrühren.\n\n'
      'In der Pfanne goldbraun backen.',
    );
  });

  test('Mengen und Zutaten in getrennten Spalten', () {
    final d = parseRecipeText('''
Kartoffelsuppe
Zutaten
800 g
1
2 EL
Kartoffeln
Stange Lauch
Butter
Zubereitung
Kartoffeln schälen.''');
    expect(d.ingredients, [
      '800 g Kartoffeln',
      '1 Stange Lauch',
      '2 EL Butter',
    ]);
    expect(d.instructions, 'Kartoffeln schälen.');
  });

  test('Ohne Überschriften: kurze Zeilen sind Zutaten, Sätze Zubereitung', () {
    final d = parseRecipeText('''
Schneller Salat
2 Tomaten
1 Gurke
Olivenöl
Tomaten und Gurke klein schneiden und mit Öl vermengen.''');
    expect(d.title, 'Schneller Salat');
    expect(d.ingredients, ['2 Tomaten', '1 Gurke', 'Olivenöl']);
    expect(
      d.instructions,
      'Tomaten und Gurke klein schneiden und mit Öl vermengen.',
    );
  });

  test('Leerer Text', () {
    final d = parseRecipeText('  \n ');
    expect(d.title, isEmpty);
    expect(d.ingredients, isEmpty);
  });
}
