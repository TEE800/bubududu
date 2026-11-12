import 'package:bubududu/util/portions.dart';
import 'package:bubududu/util/recipe_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaleIngredient', () {
    test('rechnet Mengen am Zeilenanfang um', () {
      expect(scaleIngredient('500 g Hackfleisch', 0.25), '125 g Hackfleisch');
      expect(scaleIngredient('500g Mehl', 2), '1000g Mehl');
      expect(scaleIngredient('1 Zwiebel', 0.5), '½ Zwiebel');
      expect(scaleIngredient('2 Eier', 1.5), '3 Eier');
      expect(scaleIngredient('1 ½ TL Salz', 2), '3 TL Salz');
      expect(scaleIngredient('1/2 Bund Petersilie', 3), '1 ½ Bund Petersilie');
      expect(scaleIngredient('0,5 l Milch', 3), '1 ½ l Milch');
      expect(scaleIngredient('2-3 Knoblauchzehen', 2), '4–6 Knoblauchzehen');
      expect(scaleIngredient('ca. 200 ml Sahne', 0.5), 'ca. 100 ml Sahne');
      expect(scaleIngredient('3 EL Öl', 0.25), '¾ EL Öl');
      expect(scaleIngredient('1 Dose Tomaten', 1 / 3), '⅓ Dose Tomaten');
    });

    test('lässt Zeilen ohne Menge in Ruhe', () {
      expect(scaleIngredient('etwas Salz', 4), 'etwas Salz');
      expect(scaleIngredient('Pfeffer', 2), 'Pfeffer');
      expect(scaleIngredient('500 g Mehl', 1), '500 g Mehl');
    });

    test('rundet krumme Mengen sinnvoll', () {
      expect(scaleIngredient('250 g Mehl', 1 / 3), '83 g Mehl');
      expect(scaleIngredient('400 g Nudeln', 0.75 * 1.1), '330 g Nudeln');
      expect(scaleIngredient('1 Ei', 0.4), '0,4 Ei');
    });
  });

  test('Portionen-Text', () {
    expect(portionsLabel(1), '1 Portion');
    expect(portionsLabel(3), '3 Portionen');
  });

  test('Portionen aus gescanntem Rezept', () {
    final draft = parseRecipeText(
      'Lasagne\nZutaten für 4 Portionen\n500 g Hackfleisch\n'
      'Zubereitung\nAlles schichten.',
    );
    expect(draft.servings, 4);
    expect(parseRecipeText('Toast\n2 Scheiben Brot').servings, isNull);
  });
}
