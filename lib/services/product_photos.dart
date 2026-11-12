import 'product_image.dart';

/// Handverlesene, frei lizenzierte Fotos aus Wikimedia Commons für häufige
/// Einkäufe. Die automatische Wikipedia-Suche findet bei Obst, Gemüse und
/// Grundnahrungsmitteln oft Pflanzenzeichnungen oder ganz andere Dinge
/// („Quark“ → Physik), deshalb gibt es für diese feste Bilder.
///
/// Je Zeile: Stichworte und die Bilddatei auf Commons. Das erste passende
/// gewinnt, deshalb stehen zusammengesetzte Wörter (Hafermilch, Apfelsaft)
/// vor ihren Teilen. Ein Stichwort muss am Anfang oder Ende eines Worts
/// stehen („Vollmilch“, „Milchreis“), aber nicht mittendrin („Reis“ nicht in
/// „Preiselbeeren“). Kurze Stichworte (bis 3 Buchstaben) müssen ein ganzes
/// Wort sein, damit „Ei“ nicht in „Eimer“ und „Eis“ nicht in „Eisberg“ passt.
const _photos = <(List<String>, String)>[
  (
    ['hafermilch', 'haferdrink', 'sojamilch', 'mandelmilch', 'pflanzenmilch'],
    'Oat milk glass and bottles.jpg',
  ),
  (['kokosmilch'], 'Cononut milk.JPG'),
  (['buttermilch'], 'Buttermilk-(right)-and-Milk-(left).jpg'),
  (
    ['erdnussbutter'],
    '2020-03-24 20 57 22 An open jar of Skippy Creamy Peanut Butter in the Dulles section of Sterling, Loudoun County, Virginia.jpg',
  ),
  (['apfelsaft', 'apfelschorle'], 'Apfelsaft im Glas.jpg'),
  (['orangensaft', 'o-saft', 'saft', 'smoothie'], 'Orangejuice.jpg'),
  (['zitrone'], 'Lemon.jpg'),
  (['eistee'], 'Iced Tea from flickr.jpg'),
  (['salzstangen', 'salzbrezel'], 'Saltsticks.JPG'),
  (['salz'], 'Salt shaker on white background.jpg'),
  (['fischstäbchen'], 'Fishfinger classic fried 2.jpg'),
  (
    ['gummibärchen', 'gummibären', 'fruchtgummi', 'haribo'],
    'Oursons gélatine marché Rouffignac.jpg',
  ),
  (['tomatenmark'], 'Tomato paste on spoon.jpg'),
  (
    [
      'passata',
      'passierte tomaten',
      'tomatensoße',
      'tomatensauce',
      'stückige tomaten',
    ],
    'Tomato passata.jpg',
  ),
  (['tomate'], 'Bright red tomato and cross section.jpg'),
  (['ketchup'], 'Tomato Casual.jpg'),
  (['frischkäse'], 'Philly cream cheese.jpg'),
  (
    ['frühlingszwiebel', 'lauchzwiebel'],
    '2010-06-19-supermarkt-by-RalfR-32.jpg',
  ),
  (['zwiebel', 'schalotte'], 'Zwiebeln auf Marktstand.jpg'),
  (['olivenöl'], 'Oliven V1.jpg'),
  (['sonnenblumenöl', 'rapsöl', 'speiseöl', 'öl'], 'Sunflowerseed oil.jpg'),
  (['pommes'], 'Pommes VI (20006982466).jpg'),
  (['chips'], 'Potato-Chips.jpg'),
  (['kartoffel'], 'Potatoes 2.jpg'),
  (['kichererbsen', 'hummus'], 'Choleindia.jpg'),
  (['milch'], 'Milk 001.JPG'),
  (
    ['schlagsahne', 'sahne', 'schmand', 'saure sahne', 'crème fraîche'],
    'Crème Chantilly.jpg',
  ),
  (['gouda'], 'Smoked gouda cheese.jpg'),
  (['mozzarella'], 'Bocconcini gobeirne.jpg'),
  (['parmesan', 'grana padano'], 'Parmesan Cheese Parmigiano-Reggiano.jpg'),
  (['feta', 'schafskäse', 'hirtenkäse'], 'Feta Cheese.jpg'),
  (['camembert', 'brie'], 'Camembert de Normandie (AOP) 11.jpg'),
  (['emmentaler', 'bergkäse'], 'Emmentaler Premier Cru.jpg'),
  (['käse', 'reibekäse'], 'Hartkaese HardCheeses.jpg'),
  (['butter'], 'Švédský koláč naruby 904 (cropped).JPG'),
  (['margarine'], 'Margarine.jpg'),
  (['skyr'], '17-08-05-Supermarkt-Bonus-Keflavik-RalfR-DSC 2367.jpg'),
  (['quark'], 'Skimmed milk quark on spoon.jpg'),
  (['joghurt', 'jogurt'], 'Obstjoghurt01.jpg'),
  (['pudding'], 'Chocolate pudding.jpg'),
  (['eier', 'ei'], '6-Pack-Chicken-Eggs.jpg'),
  (['croissant'], 'Croissant-Petr Kratochvil.jpg'),
  (['baguette'], 'Baguettes - stonesoup.jpg'),
  (['brezel', 'brezn'], 'Viipurinrinkeli22.jpg'),
  (['toast'], 'Toast-1.jpg'),
  (['brötchen', 'semmel', 'schrippe'], 'Pan Francés.jpg'),
  (['brot'], 'Sour dough loaves03.jpg'),
  (['müsli', 'granola'], 'Muesli.jpg'),
  (['haferflocken'], 'Rolled oats.jpg'),
  (['cornflakes'], 'Photo cornflakes.jpg'),
  (['spaghetti'], 'Spaghetti2.jpg'),
  (['penne'], 'Barilla penne 4.jpg'),
  (['lasagne'], 'Lasagne - stonesoup.jpg'),
  (['tortellini'], 'Tortellini Bolognesi.jpg'),
  (['spätzle'], 'Spätzle.jpg'),
  (
    ['nudeln', 'pasta', 'fusilli', 'farfalle', 'makkaroni'],
    'Rotini Yellow Red Green.jpg',
  ),
  (['reis'], 'White, Brown, Red & Wild rice.jpg'),
  (['mehl'], 'Soy powder.jpg'),
  (['zucker'], 'Sucre blanc cassonade complet rapadura.jpg'),
  (['hefe'], 'Compressed fresh yeast - 1.jpg'),
  (['backpulver'], 'Backpulver RZ.jpg'),
  (['pfeffer'], 'Dried Peppercorns.jpg'),
  (['zimt'], 'Baton de cannelle.jpg'),
  (['oregano'], 'Oregano (অরেগানো).JPG'),
  (['essig', 'balsamico'], 'Balsamico-1.jpg'),
  (['honig'], 'Runny hunny.jpg'),
  (['nutella', 'nuss-nougat'], 'Nutella for breakfast - Flickr - love.jsc.jpg'),
  (['marmelade', 'konfitüre'], 'Homemade marmalade, England.jpg'),
  (['senf'], 'Mustard.JPG'),
  (['mayo'], '2016 0529 Kewpie mayonnaise NL.jpg'),
  (['pesto'], 'BasilPesto.JPG'),
  (['mais'], 'Sweet Corns.jpg'),
  (['kidneybohnen', 'bohnen'], 'Red Rajma BNC.jpg'),
  (['linsen'], 'Split Red Lentil.jpg'),
  (['kaffee', 'espresso'], 'Roasted coffee beans.jpg'),
  (['tee'], 'Tea bags.jpg'),
  (['wasser', 'sprudel'], 'Water Bottle (51308317077).jpg'),
  (['bier', 'radler'], 'Von Trapp beer glass with beer 2021 001.jpg'),
  (['cola'], 'Glass of Cola.jpg'),
  (['wein'], 'Red and white wine in glass.jpg'),
  (['sekt', 'prosecco', 'champagner'], 'Italian prosecco.jpg'),
  (['schokolade', 'schoko'], 'Three Bars (1).jpg'),
  (['kekse', 'keks', 'plätzchen'], 'Různé druhy cukroví (2).jpg'),
  (['kuchen', 'torte'], 'Pound layer cake.jpg'),
  (
    ['eis', 'speiseeis', 'eiscreme'],
    'Vanilla Ice Cream Cone at Camp Manitoulin.jpg',
  ),
  (
    ['pizza'],
    'Pizza quattro formaggi at restaurant, Chalk Farm Road, London.jpg',
  ),
  (
    ['hähnchen', 'hühnchen', 'huhn', 'chicken', 'pute'],
    'Raw chicken slices.jpg',
  ),
  (['hack'], 'Фарш.jpg'),
  (
    ['schnitzel'],
    'The pork schnitzel at the Figlmuller restaurant in Vienna, Austria.jpg',
  ),
  (['steak', 'rind'], 'Reindeer steak.jpg'),
  (['salami'], 'Salami aka.jpg'),
  (['schinken'], 'Schinken-gekocht.jpg'),
  (['speck', 'bacon'], 'Schweinebauch-1.jpg'),
  (['würstchen', 'wiener'], 'Wiener Wuerstchen (fcm).jpg'),
  (['wurst', 'bratwurst'], 'Salsiccia Italian pork sausage.jpg'),
  (['lachs'], 'Salmon-Ruibe.jpg'),
  (['thunfisch'], 'Russian Cod liver in an opened can.jpg'),
  (['garnelen', 'shrimps', 'krabben'], 'Split raw shrimp.jpg'),
  (['tofu'], 'Soft tofu 2.jpg'),
  (['limette'], 'Citrus hystrix dsc07772.jpg'),
  (['apfel', 'äpfel'], 'Rome Apples, Newark Delaware Farmer\'s Market.jpg'),
  (['birne'], 'Pyrus pyrifolia.jpg'),
  (['banane'], 'Bananas.jpg'),
  (['orange', 'apfelsine'], 'Mandarins - whole and halved.jpg'),
  (['mandarine', 'clementine'], 'Mandarins - whole and halved.jpg'),
  (['erdbeere'], 'PerfectStrawberry.jpg'),
  (['heidelbeere', 'blaubeere'], 'Dish of blueberries.jpg'),
  (['himbeere'], 'Raspberries (Rubus idaeus).jpg'),
  (
    ['traube', 'trauben', 'weintrauben'],
    'Seedless grapes of Kallidaikurichi.jpg',
  ),
  (['melone'], 'Watermelon cross BNC.jpg'),
  (['kiwi'], 'Hardy-Kiwi-Comparison-3.jpg'),
  (['avocado'], 'Avocado Hass - single and halved.jpg'),
  (['ananas'], 'Pineapple and cross section.jpg'),
  (['mango'], 'Mangoes-left.jpg'),
  (['pfirsich', 'nektarine'], 'Prunus persica - Peach Hungary.jpg'),
  (['kirsche'], 'Cherry season (48216568227).jpg'),
  (['karotte', 'möhre', 'möhren'], 'Carrots at Ljubljana Central Market.JPG'),
  (['gurke'], 'PicklingCucumbers.jpg'),
  (['zucchini'], 'Zucchini-Whole.jpg'),
  (['paprika'], 'Green-Yellow-Red-Pepper-2009.jpg'),
  (['chili', 'peperoni'], 'Madame Jeanette and other chillies.jpg'),
  (['lauch', 'porree'], 'Leek.jpg'),
  (['knoblauch'], 'Opened garlic bulb with garlic clove.jpg'),
  (['brokkoli'], 'Broccoli and cross section edit.jpg'),
  (['blumenkohl'], 'Chou-fleur 02.jpg'),
  (['rucola', 'rauke'], 'Rocket Salad.jpg'),
  (['spinat'], 'Fresh Spinach leaves.jpg'),
  (['salat', 'eisberg'], 'Romaine lettuce.jpg'),
  (['kohl', 'weißkohl', 'rotkohl'], 'Cabbage and cross section on white.jpg'),
  (['petersilie'], 'ParsleyStem.jpg'),
  (['basilikum'], 'Ocimum basilicum 8zz.jpg'),
  (['champignon', 'pilz'], 'Agaricus bisporus Zuchtchampignon2.jpg'),
  (['aubergine'], 'Segmented aubergine Thailand.jpg'),
  (['ingwer'], 'Ingwer 2 (fcm).jpg'),
  (['erdnüsse', 'erdnuss'], 'Roasted Peanuts with shell.jpg'),
  (['mandeln', 'mandel'], 'Mandorle sgusciate.jpg'),
  (['nüsse', 'walnüsse', 'walnuss', 'nuss'], '4 walnut kernels.jpg'),
  (['klopapier', 'toilettenpapier'], 'Toiletpapier (Gobran111).jpg'),
  (['küchenrolle', 'küchenpapier', 'zewa'], 'Paper towel.jpg'),
  (['taschentücher', 'tempo'], 'Box of Scotties tissues.jpg'),
  (['spültabs', 'spülmaschinentabs', 'tabs'], 'Detergent tablet.jpg'),
  (['spülmittel', 'spüli'], 'Afwasmiddel Una Aldi.JPG'),
  (['waschmittel'], 'Pralni prašek.JPG'),
  (
    ['müllbeutel', 'müllsack', 'mülltüten'],
    'A typical black bin bag from the UK 20060811.jpg',
  ),
  (['schwamm'], 'Éponge type 3 (1).jpg'),
  (['alufolie'], 'Aluminio.jpg'),
  (['backpapier'], 'Leivinarkki.jpg'),
  (['frischhaltefolie'], 'Pvc-Film.jpg'),
  (['seife'], 'Handmade soap cropped and simplified.jpg'),
  (['duschgel'], 'Care lime shower gel (2019) 01.jpg'),
  (['shampoo'], 'Green shampoo bottle.jpg'),
  (['deo'], 'L+S deo.jpg'),
  (['zahnpasta', 'zahncreme'], 'Toothpaste.jpg'),
  (['zahnbürste'], 'Toothbrush 20050716 004.jpg'),
  (['sonnencreme'], 'LRP sunscreen bottle.jpg'),
  (['batterie', 'akku'], 'Eneloop 6420.jpg'),
  (['glühbirne', 'leuchtmittel'], 'Squirrel Cage filament lamp.jpg'),
  (['katzenfutter'], 'Katzenfutter.JPG'),
  (['katzenstreu'], 'Japanese litter box.jpg'),
  (['hundefutter'], 'Dog food in a bowl.jpg'),
  (['blumenerde'], 'Potting soil.jpg'),
  (['windel'], 'Disposablediaper.JPG'),
  (['pflaster'], 'Sparadrap 2.jpg'),
];

/// Das handverlesene Foto zum Artikel [name], sonst null.
ProductImage? curatedProductPhoto(String name) {
  final text = name.toLowerCase();
  final words = text.split(RegExp(r'[^a-zäöüß]+'));
  bool fits(String k) {
    if (k.contains(RegExp('[ -]'))) return text.contains(k);
    if (k.length <= 3) return words.contains(k);
    return words.any((w) => w.startsWith(k) || w.endsWith(k));
  }

  for (final (keys, file) in _photos) {
    if (keys.any(fits)) return commonsPhoto(file);
  }
  return null;
}

/// Bild [file] aus Wikimedia Commons, etwa 500 px breit.
ProductImage commonsPhoto(String file) {
  final name = file.replaceAll(' ', '_');
  final encoded = Uri.encodeComponent(name);
  return ProductImage(
    url:
        'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=500',
    page: 'https://commons.wikimedia.org/wiki/File:$encoded',
  );
}
