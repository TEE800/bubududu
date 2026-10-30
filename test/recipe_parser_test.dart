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

  test('Screenshot: Statusleiste, Bedienelemente und Lesefehler', () {
    final d = parseRecipeText('''
08:45
T
All Posts
dem Ofen
REZEPT für 4 Portionen
HAUPTZUTATEN
1Spitzkohl
400 g Frühkartoffeln
20 g Butter
MARINADE
60 ml Olivenöl
S1TL Paprikapulver
%TL Currypulver
R%TL Pfeffer
Salz nach Geschmack
CREMIGE SAHNESOSSE
Etwas Butter zum Anbraten
150 g Schinkenwürfel
1TL Senf
F 30 g Mehl (ca. 2 gestrichene EL)
50 g Parmesan (mehr ist mehr!)
1.234 Likes
#spitzkohl''');
    expect(d.title, 'dem Ofen');
    expect(d.ingredients, [
      '1 Spitzkohl',
      '400 g Frühkartoffeln',
      '20 g Butter',
      '60 ml Olivenöl',
      '1 TL Paprikapulver',
      '½ TL Currypulver',
      '½ TL Pfeffer',
      'Salz nach Geschmack',
      'Etwas Butter zum Anbraten',
      '150 g Schinkenwürfel',
      '1 TL Senf',
      '30 g Mehl (ca. 2 gestrichene EL)',
      '50 g Parmesan (mehr ist mehr!)',
    ]);
    expect(d.instructions, isEmpty);
  });

  test('Name ist die Zeile mit der größten Schrift', () {
    final d = parseRecipeLines(const [
      OcrLine('08:45', height: 30),
      OcrLine('All Posts', height: 30),
      OcrLine('Spitzkohl aus', height: 90),
      OcrLine('dem Ofen', height: 88),
      OcrLine('Ein schnelles Gericht für jeden Tag', height: 35),
      OcrLine('Zutaten', height: 50),
      OcrLine('1 Spitzkohl', height: 35),
      OcrLine('Zubereitung', height: 50),
      OcrLine('Kohl in Spalten schneiden.', height: 35),
    ]);
    expect(d.title, 'Spitzkohl aus dem Ofen');
    expect(d.ingredients, ['1 Spitzkohl']);
    expect(d.instructions, 'Kohl in Spalten schneiden.');
  });

  test('Zwischenüberschriften mit Doppelpunkt und "Für die ..."', () {
    final d = parseRecipeText('''
Bowl
Zutaten
Für die Soße:
2 EL Sojasoße
Für den Reis
200g Reis
Zubereitung
Reis kochen.''');
    expect(d.ingredients, ['2 EL Sojasoße', '200 g Reis']);
  });

  test('Rezept komplett in Großbuchstaben behält seine Zutaten', () {
    final d = parseRecipeText('''
NUDELN
ZUTATEN
500 G NUDELN
SALZ
PARMESAN''');
    expect(d.title, 'NUDELN');
    expect(d.ingredients, ['500 G NUDELN', 'SALZ', 'PARMESAN']);
  });

  test('Nur Zubereitungs-Überschrift: Zutaten davor bleiben erhalten', () {
    final d = parseRecipeText('''
Salat
2 Tomaten
1 Gurke
Zubereitung
Alles schneiden.''');
    expect(d.title, 'Salat');
    expect(d.ingredients, ['2 Tomaten', '1 Gurke']);
    expect(d.instructions, 'Alles schneiden.');
  });

  test('Nur Störtext ergibt einen leeren Entwurf', () {
    expect(parseRecipeText('08:45\nT\n87%\nAll Posts').isEmpty, isTrue);
  });
}
